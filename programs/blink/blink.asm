.include "m328Pdef.inc"

.cseg
.org 0x0000

reset:
    ldi  r16, 0b00100000
    out  DDRB, r16
	
main:
	in r17, PORTB
	eor r17, r16
	out PORTB, r17
	rcall delay
	rjmp main
	
delay:
	ldi r18, 5
outer:
	ldi r19, 255
middle:
	ldi r20, 255
inner:
	dec r20
	brne inner
	dec r19
	brne middle
	dec r18
	brne outer
	ret