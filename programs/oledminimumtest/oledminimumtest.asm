.include "m328Pdef.inc"

.cseg
.org 0x0000

reset:
    ; --- ноги ---
	;           76543210
    ldi  r16, 0b00000100    ; PB2 (CS) = 1, остальные = 0, дисплей НЕ слушает
    out  PORTB, r16
	;           76543210
	ldi  r16, 0b00101111    ; PB0, PB1, PB2, PB3, PB5 = выходы
    out  DDRB, r16

    ; --- включить SPI ---
    ;           76543210
	ldi  r16, 0b01010000    ; SPE = 1, MSTR = 1
    out  SPCR, r16

    ; --- сброс дисплея (PB0 сейчас = 0) ---
    rcall delay
    sbi  PORTB, 0           ; RES = 1
    rcall delay

    ; --- 5 команд ---
    cbi  PORTB, 2           ; CS = 0, дисплей слушает
    cbi  PORTB, 1           ; DC = 0, дальше идут команды (пока что ненужная команда, т.к. этот бит и так был 0)

    ldi  r16, 0x8D          ; настройка charge pump
    rcall spi_send
    ldi  r16, 0x14          ; ...включить его
    rcall spi_send
    ldi  r16, 0x20          ; режим адресации памяти
    rcall spi_send
    ldi  r16, 0x00          ; ...горизонтальный
    rcall spi_send
    ldi  r16, 0xAF          ; включить дисплей
    rcall spi_send

    ; --- данные: очистить экран (1024 нулевых байта) ---
    sbi  PORTB, 1           ; DC = 1, дальше идут данные
    ldi  r16, 0x00          ; байт для отправки = 0
    ldi  r18, 8             ; 8 страниц
page_loop:
    ldi  r19, 128           ; 128 колонок
column_loop:
    rcall spi_send
    dec  r19
    brne column_loop
    dec  r18
    brne page_loop

    ; --- один пиксель ---
    ;           76543210
	;ldi  r16, 0b00000001    ; нижний бит = верхний пиксель колонки
    ;rcall spi_send
	
	; --- данные: заливка дисплея (1024 байта 0b11111111) ---
    sbi  PORTB, 1           ; DC = 1, дальше идут данные
    ldi  r16, 0b11111111    ; байт для отправки = 1
    ldi  r18, 8             ; 8 страниц
page_loop1:
    ldi  r19, 128           ; 128 колонок
column_loop1:
    rcall spi_send
    dec  r19
    brne column_loop1
    dec  r18
    brne page_loop1

    sbi  PORTB, 2           ; CS = 1

main:
    rjmp main

; отправить байт из r16 по SPI
spi_send:
    out  SPDR, r16
spi_wait:
    in   r17, SPSR
    sbrs r17, 7             ; бит 7 = SPIF, передача закончена? sbrs = Skip if Bit in Register is Set (пропустить следующую команду, если указанный бит регистра равен 1)
    rjmp spi_wait
    ret

; пауза около 0.2 с на 1 МГц
delay:
    ldi  r20, 255
delay_outer:
    ldi  r21, 255
delay_inner:
    dec  r21
    brne delay_inner
    dec  r20
    brne delay_outer
    ret