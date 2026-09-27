.include "m328Pdef.inc"

.dseg
.org 0x0100

screen_buffer:
    .byte 1024 

.cseg
.org 0x0000

reset:
	; инициализация стека
    ldi  r16, low(RAMEND)
    out  SPL, r16
    ldi  r16, high(RAMEND)
    out  SPH, r16

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

main:
	rcall init_zero
	rcall flush
	rcall init_one
	rcall flush
	
    rjmp main

; --- инициализация screen_buffer нулями
init_zero:
	ldi r16, 0b00000000
	
	ldi ZL, low(screen_buffer)
	ldi ZH, high(screen_buffer)
	
	ldi r17, high(1024)
	ldi r18, low(1024)

init_zero_loop:
	st Z+, r16
	
	subi r18, 1
	sbci r17, 0
	
	brne init_zero_loop
	ret

; --- инициализация screen_buffer единицами
init_one:
	ldi r16, 0b11111111
	
	ldi ZL, low(screen_buffer)
	ldi ZH, high(screen_buffer)
	
	ldi r17, high(1024)
	ldi r18, low(1024)

init_one_loop:
	st Z+, r16
	
	subi r18, 1
	sbci r17, 0
	
	brne init_one_loop
	ret

; отправить байт из r16 по SPI
;inputs: r16 = byte to send
;clobbers: r17
spi_send:
    out  SPDR, r16
spi_wait:
    in   r17, SPSR
    sbrs r17, 7             ; бит 7 = SPIF, передача закончена? sbrs = Skip if Bit in Register is Set (пропустить следующую команду, если указанный бит регистра равен 1)
    rjmp spi_wait
    ret

; пауза около 0.2 с на 1 МГц
delay:
    ldi r16, 255
delay_outer:
    ldi r17, 255
delay_inner:
    dec r17
    brne delay_inner
    dec r16
    brne delay_outer
    ret

;inputs: none (reads screen_buffer from RAM)
;clobbers: r16, r17, r18, r19, Z (ZL/ZH)
flush:
	sbi PORTB, 1			; DC = 1, дальше идут данные
	cbi PORTB, 2
	ldi ZL, low(screen_buffer)
	ldi ZH, high(screen_buffer)
	
	ldi r18, high(1024)
	ldi r19, low(1024)
	
flush_loop:
	ld r16, Z+
	rcall spi_send
	subi r19, 1				; вычесть 1 из младшего байта счётчика (как разбирали)
    sbci r18, 0				; перенести заём в старший байт, если он был
    brne flush_loop			; повторять, пока 16-битный счётчик не дойдёт до 0

    sbi PORTB, 2
	ret