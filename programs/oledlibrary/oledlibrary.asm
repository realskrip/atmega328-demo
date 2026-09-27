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

    ; --- инициализация screen_buffer нулями через plot ---
    ldi  r24, 0       		; y = 0

y_loop0:
    ldi  r23, 0        		; x = 0

x_loop0:
    mov  r16, r23        	; x → r16
    mov  r17, r24        	; y → r17
    ldi  r18, 0          	; цвет = 0 (гасить)
    rcall plot

    inc  r23
    cpi  r23, 128
    brne x_loop0

    inc  r24
    cpi  r24, 64
    brne y_loop0
	
	rcall flush
	
    ; --- инициализация screen_buffer единицами через plot ---
    ldi  r24, 0            	; y = 0

y_loop1:
    ldi  r23, 0        		; x = 0

x_loop1:
    mov  r16, r23    		; x → r16
    mov  r17, r24     		; y → r17
    ldi  r18, 1        		; цвет = 1
    rcall plot

    inc  r23
    cpi  r23, 128
    brne x_loop1

    inc  r24
    cpi  r24, 64
    brne y_loop1
	
	rcall flush
	
main:
    rjmp main

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

;inputs:
;  r16 = x (0–127)
;  r17 = y (0–63)
;  r18 = color (0 = clear, 1 = set)
;
;clobbers: r17, r19, r20, r21, r22, Z (ZL/ZH)	
plot:
; вычисление номера страницы. номер страницы = y / 8
    mov  r19, r17
    lsr  r19				; r19 = y / 2
    lsr  r19				; r19 = y / 4
    lsr  r19				; r19 = y / 8  r19 = номер страницы

    andi r17, 0b00000111    ; остаток от делений y / 8. = номер строки внутри страницы

    mov  r20, r19
    lsr  r20

    andi r19, 0b00000001
    lsl  r19
    lsl  r19
    lsl  r19
    lsl  r19
    lsl  r19
    lsl  r19
    lsl  r19

    add  r19, r16

    ldi  ZL, low(screen_buffer)
    ldi  ZH, high(screen_buffer)
    add  ZL, r19
    adc  ZH, r20

    ld   r21, Z

    ldi  r22, 1
    tst  r17
    breq mask_ready
mask_loop:
    lsl  r22
    dec  r17
    brne mask_loop
mask_ready:

    tst  r18
    breq clear_bit

    or   r21, r22
    rjmp store_byte

clear_bit:
    com  r22
    and  r21, r22

store_byte:
    st   Z, r21
    ret