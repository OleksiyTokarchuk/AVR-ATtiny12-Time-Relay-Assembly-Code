;Author: Oleksiy Tokarchuk 
;mail.oleksiy@gmail.com

.def data        = r16 			      ;Software shift register
.def i           = r17				    ;Register that stores cycle iterator
.def p           = r18				    ;Pointer to data in table for 7-segment indicators 
.def dataout     = r19		        ;Register that outputs data from shift into IO space 
.def tableaddr   = r20	          ;Register that stores first byte point in table 
.def temp        = r21
.def time        = r22
.def setpoint    = r23
.def buttonstate = r24

.equ clock = 0					      ;clock pin
.equ cs    = 2					      ;chip selsct pin
.equ mosi  = 1					      ;sdout pin
.equ mask  = 0b00000010 			      ;mask where 1 corresponds mosi pin position in PORTx register

.equ plus  = 3
.equ minus = 4
.equ relay = 5

.eseg
	.db 0x01 ;EEPROM location for last used setpoint to store it
                 ;will be implemented in future
.cseg

.org 0x00 rjmp RESET

; the best place to access table by single relative address LOW register 
table:    		    .db 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, \
			        0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, \
			        0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, \
			        0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, \
			        0x40, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, \
			        0x50, 0x51, 0x52, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, \
			        0x60, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, \
			        0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, \
			        0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89, \
			        0x90, 0x91, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99

RESET:
	ldi tableaddr, LOW(table * 2) 
	sbi DDRB, mosi			                ;data
	sbi DDRB, clock			                ;clock
	sbi DDRB, cs			                ;latch
	ldi temp, (1 << plus)|(1 << minus)
	out PORTB, temp                                 ;pull-up for buttons
	clr temp
	ldi time, 0
loop:
	in buttonstate, PINB
	andi buttonstate, 0b00011000
	cpi buttonstate, (0 << plus)|(1 << minus)
	breq increment
	cpi buttonstate, (1 << plus)|(0 << minus)
	breq decrement
	cpi buttonstate, 0x00
	breq start
	rjmp loop

start:
	cpi setpoint, 0
	breq error              ;setpoint can't be zero
	mov time, setpoint
	sbi DDRB, relay
softtimer:
	rcall delay1s
	dec time
	mov p, time
	rcall print
	cpi time, 0
	brne softtimer
	cbi DDRB, relay
	mov p, setpoint
	rcall print
	rjmp loop
error:
	rjmp loop

increment:
	rcall delay
	sbrc buttonstate, plus
	rjmp loop
	inc setpoint
	cpi setpoint, 99
	brsh setpoint_maximum
maximum:
	mov p, setpoint
	rcall print
	rcall delay
	rjmp loop
setpoint_maximum:
	ldi setpoint, 99
	rjmp maximum

decrement: 
	rcall delay
	sbrc buttonstate, minus
	rjmp loop
	dec setpoint
	cpi setpoint, 1
	brlo setpoint_minimum
minimum:
	mov p, setpoint
	rcall print
	rcall delay
	rjmp loop
setpoint_minimum:
	ldi setpoint, 1
	rjmp minimum

send: 					;Software defined shift register
	in temp, PORTB
	andi temp, 0b00011000
	clr i
	cbi PORTB, cs
byte:
	cbi PORTB, clock
	bst data, 7
	bld dataout, mosi
	andi dataout, mask
	or dataout, temp
	out PORTB, dataout
	sbi PORTB, clock
	lsl data
	inc i
	cpi i, 8
	brne byte
	sbi PORTB, cs
	ret

print:					;subroutine that prints data on 7-segmet indicators 
	add tableaddr, p
	mov ZL, tableaddr
	lpm
	mov data, R0
	rcall send
        sub tableaddr, p
	ret

delay:
  	ldi r27, 2
  	ldi r28, 4
  	ldi r29, 187
Level1: 
  	dec r29
  	brne Level1
  	dec r28
  	brne Level1
	dec r27
	brne Level1
	nop
	ret

delay1s:
  	ldi r27, 6
  	ldi r28, 19
  	ldi r29, 174
Level2: 
	dec r29
  	brne Level2
  	dec  r28
  	brne Level2
  	dec  r27
  	brne Level2
  	rjmp PC+1
	ret
