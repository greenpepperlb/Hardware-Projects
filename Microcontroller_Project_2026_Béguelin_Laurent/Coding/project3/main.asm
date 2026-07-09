;
; project3.asm
;
; Created: 27-02-26 15:25:19
; Author : laurent

; Include ATmega328P definitions
.include "m328pdef.inc" 
.ORG 0x0000
	rjmp initialisation  ; jump to start

; Interrupt adress Vectors
.ORG 0x0016 ;Timer 1 OV
	rjmp Timer1_ISR

.ORG 0x0020 ; timer 0 OV
	rjmp Timer0_ISR

;-----------------------END OF INTERRUPT VECTORS-------------------------
.ORG 0x0034
initialisation:
; --- Initialize Stack Pointer ---
    LDI R16, LOW(RAMEND)
    OUT SPL, R16
    LDI R16, HIGH(RAMEND)
    OUT SPH, R16

; --- Setup of pins ---
; joystick
CBI DDRB,2 ;pin PB2 as input
SBI PORTB,2 ; pin PB2 has pull up resistor
;LED 1
SBI DDRC,3 ; pin PC3 as output
SBI PORTC,3 ; pin PC3 is set high
;LED 2
SBI DDRC,2 ; pin PC2 as output
SBI PORTC,2 ; pin PC2 is set high

;Switch
CBI DDRB,0 ; set pin PB0 as input
SBI PORTB,0 ; enable pull up resistor
;Buzzer
SBI DDRB,1
;Keyboard setup
LDI R16, 0b11110000 ; Output PD7-PD4, input PD3 PD0 
OUT DDRD, R16 ; ROWS= Output Columns = input
LDI R16, 0b11111111 ; Setting up the pull up resistors 
OUT PORTD, R16
;Shift register setup
SBI DDRB,3 ;Set PB3 as output
SBI DDRB,4 ;Set PB4 as output
SBI DDRB,5 ;Set PB5 as output

CBI PORTB,3   ; DATA = 0
CBI PORTB,4   ; LATCH = 0
CBI PORTB,5   ; CLOCK = 0
;Timers 0 setup
LDI R16,0x00
OUT TCCR0A, R16 ; Normal mode 

LDI R16, 185
OUT TCNT0, R16 ; LOad value of the timer

LDI R16,(1<< CS02)
OUT TCCR0B, R16 ; prescaler 

;Timer 1 setup CTC Mode 
LDI R16, 0x00
STS TCCR1A, R16 ; Manual interrupt pin toggle

LDI R16, (1<<WGM12)|(1<<CS11) ; bit 3 and bit 1 of TCCR1B
STS TCCR1B, R16
LDI R16, 0x00
STS TIMSK1,R16 ; enable CTC interrupt 
;initial frequency 
;LDI R16, HIGH(2272)
;STS OCR1AH,R16
;LDI R16, LOW(2272)
;STS OCR1AL,R16

;Empty register
CLR R1

SEI ; enable global interrupt 

;-----loop----------
main :
	;RCALL Task1
	;RCALL Task2
	;RCALL Task3
	;RCALL Task4
	;RCALL Task5
	;RCALL Task6
	;RCALL Task7
	;RCALL Task8
	;RCALL Task9
	RCALL Task10
	RJMP main ; repeat

Task1: 
;led on when button is pressed
	in R0,PINB ; get value of pinB in R0
	BST R0,2 ; copy PB2 to the Tflag
	BRTC Joypressed

JoyNotPressed:
	SBI PORTC,3 ; turn off led2
	RET
JoyPressed :
	CBI PORTC,3 ; turn on led2
	RET ; infinite loop
RET 
Task2 :
;led on when switch is high
	IN R1,PINB
	BST R1,0
	BRTS SwitchHigh
SwitchLow:
SBI PORTC,3
RET
SwitchHigh:
CBI PORTC,3
RET
Task3:
;blink the led
    CBI PORTC,3   ; LED ON (active low)
    RCALL Delay
    SBI PORTC,3   ; LED OFF
    RCALL Delay
    RET 

; -------- DELAY ROUTINE ----------
Delay:
    LDI R20, 100     
; outermost loop
OuterLoop:
    LDI R18, 200     
; middle loop
MiddleLoop:
    LDI R19, 255     
; inner loop
InnerLoop:
    DEC R19
    BRNE InnerLoop
    DEC R18
    BRNE MiddleLoop
    DEC R20
    BRNE OuterLoop
    RET

Task4: 
	;Make the buzzer sound audibly.
	SBI PINB,1
	RCALL delay_audio
	RET
	delay_audio :
	LDI R21,24
	audio_outer :
	LDI R22,255
	audio_inner :
	DEC R22
	BRNE audio_inner
	DEC R21
	BRNE audio_outer
	RET

Task5:
	in R0,PINB ; get value of pinB in R0
	BST R0,2 ; copy PB2 to the Tflag
	BRTC ButtonPressed
	ButtonNotPressed:
		LDI R17, 0x00
		STS TIMSK0, R17
		CBI PORTB, 1
		RET
	ButtonPressed :
		LDI R17, (1<<TOIE0)
		STS TIMSK0, R17
		RET 
	; Make the buzzer sound at 440Hz when the button of the joystick is pressed. Use a timer and an interrupt to achieve this. 

Task6:
	;Make the buzzer sound at 440Hz and 880Hz based on the state of the switch. Use a timer and an interrupt to achieve this.

	IN R1,PINB
	BST R1,0
	BRTS SwitchHigh2
	SwitchLow2: ;440
		LDI R16, high(2272)
		STS OCR1AH, R16
		LDI R16,low(2272)
		STS OCR1AL, R16
		RET

	SwitchHigh2: ;880
		LDI R16, high(1135)
		STS OCR1AH, R16
		LDI R16,low(1135)
		STS OCR1AL, R16
		RET
	 
Task7: 

	;Implement one method to readout the keyboard, write code such that the buttons do the following: 
	;Button 7: Two leds on; Button 8: Bottom led on; Button 4: Top Led on; All other buttons: Buzzer on; 
	;No buttons pressed: Leds and buzzer off
	LDI R18, 0 ;Was a button pressed flag 

	;---------------SCAN  ROW 1 ( 7, 8, 9, F)--------------

	LDI R16, 0b01111111 ; set PD7 LOW so row1 active 
	OUT PORTD, R16
	NOP
	IN R17,PIND
	MOV R19, R17
	ANDI R19,0b00001111
	CPI R19, 0b00001111
	BREQ Scan_Row_2
	LDI R22, 1
	LDI R18, 1
	RJMP Check_Buttons

	;---------------SCAN  ROW 2 ( 4, 5, 6, E)--------------
	Scan_Row_2 :
	LDI R16, 0b10111111 ; set PD6 LOW so row2 active 
	OUT PORTD, R16
	NOP
	IN R17,PIND
	MOV R19, R17
	ANDI R19,0b00001111
	CPI R19, 0b00001111
	BREQ Scan_Row_3
	LDI R22, 2
	LDI R18, 1
	RJMP Check_Buttons

	;---------------SCAN  ROW 3 ( 1, 2, 3, D)--------------
	Scan_Row_3 :
	LDI R16, 0b11011111 ; set PD5 LOW so row3 active 
	OUT PORTD, R16
	NOP
	IN R17,PIND
	MOV R19, R17
	ANDI R19,0b00001111
	CPI R19, 0b00001111
	BREQ Scan_Row_4
	LDI R22, 3
	LDI R18, 1
	RJMP Check_Buttons

	;---------------SCAN  ROW 4 ( A, 0, B, C)--------------
	Scan_Row_4 :
	LDI R16, 0b11101111 ; set PD4 LOW so row4 active 
	OUT PORTD, R16
	NOP
	IN R17,PIND
	MOV R19, R17
	ANDI R19,0b00001111
	CPI R19, 0b00001111
	BREQ Final_Check
	LDI R22, 4
	LDI R18, 1
	RJMP Check_Buttons 
	;--------Final check-----------
	Final_Check :
	CPI R18, 0 
	BRNE Skip_All_OFF
	RJMP Action_All_OFF
	Skip_All_OFF :
	RET

Task8:
	;Get something on the screen. Shift out something into the shift registers of the screen
	; such that at least one LED is on. 
	
	LDI R16,0x02
	RCALL SendByte ;column byte 1
	LDI R16, 0x00
	RCALL SendByte ; column byte 2 
	LDI R16,0x00
	RCALL SendByte ;column byte 3
	LDI R16, 0x00
	RCALL SendByte ; column byte 4
	LDI R16,0x03
	RCALL SendByte ;column byte 5
	LDI R16, 0x00
	RCALL SendByte ; column byte 6
	LDI R16,0x00
	RCALL SendByte ;column byte 7
	LDI R16, 0x00
	RCALL SendByte ; column byte 8
	LDI R16,0x00
	RCALL SendByte ;column byte 9
	LDI R16, 0x00
	RCALL SendByte ; column byte 10
	LDI R16, 0x01
	RCALL SendByte ; Rows bytes
	RCALL LatchAndShow
	RET
	 
Task9: 
	;Make a checkerboard pattern on the screen. Alternating leds on-of-on-off.
	LDI R21, 0
	LDI R22, 0x01 ; bitmask used for rows select
Right_Pattern : 
	TST R21 ; testing the Zero flag for odd/even patter
	BRNE Use_odd
	LDI ZH, high(EvenPattern<<1)
	LDI ZL,low(EvenPattern<<1)
	RJMP SendCols
Use_odd :
	LDI ZH, high(OddPattern<<1)
	LDI ZL,low(OddPattern<<1)
SendCols : 
	LDI R18, 10 ; 10bytes = 80 columns
Col_Loop : 
	LPM R16, Z+
	RCALL SendByte
	DEC R18
	BRNE Col_Loop
	;------Sending the rows---------

	MOV R16,R22      ; copy current row mask
	RCALL SendByte   ; SendByte destroys R16, not R22

	RCALL LatchAndShow
	; Alternate checkerboard pattern
	COM R21
	ANDI R21,1

	; Advance to next row
	LSL R22
	BRNE Right_Pattern

	; Finished all rows, start again
	LDI R22,0x01
	RET	

Task10:
    ; Display character 'A'

    ; Z -> beginning of character A
    LDI ZH, HIGH(CharTable<<1)
    LDI ZL, LOW(CharTable<<1)

    ; First active row
    LDI R22, 0x01

    ; 8 rows
    LDI R18, 8

RowLoop:
	; turn off all rows
     LDI R16,0x00
     RCALL SendByte
    ;-------------------------------------------------
    ; Send the first 9 column bytes as blank
    ;-------------------------------------------------
    LDI R20,9

BlankLoop:
    LDI R16,0x00
    RCALL SendByte
    DEC R20
    BRNE BlankLoop

    ;-------------------------------------------------
    ; Send one row of the character
    ;-------------------------------------------------
    LPM R16,Z+
    RCALL SendByte

    ;-------------------------------------------------
    ; Send row select byte
    ;-------------------------------------------------
    MOV R16,R22
    RCALL SendByte
    RCALL LatchAndShow

	RCALL SmallDelay
    ; Next row
    LSL R22

    DEC R18
    BRNE RowLoop

    RET
;------------------------------------------------SUBROUTINES---------------------------
Timer0_ISR :
	;Prologue : save states
	PUSH R16
	IN R16, SREG
	PUSH R16
	LDI R16, 185
	OUT TCNT0, R16
	SBI PINB,1
	POP R16
	OUT SREG,R16
	POP R16
	RETI

Timer1_ISR :
	;Prologue : save states
	PUSH R16
	IN R16, SREG
	PUSH R16
	SBI PINB,1
	POP R16
	OUT SREG,R16
	POP R16
	RETI
;------------------------------FUNCTIONS-----------------------------------------------------------------
MyFunction1 :
	;function space
	RET
Check_Buttons :
	CPI R22, 1
	BREQ Check_Row1_Buttons
	CPI R22, 2
	BREQ Check_Row2_Buttons
	RJMP Action_buzzer


Check_Row1_Buttons :
	SBIS PIND, 3
	RJMP Action_button7
	SBIS PIND, 2
	RJMP Action_button8
	RJMP Action_buzzer
Check_Row2_Buttons :
	SBIS PIND, 3
	RJMP Action_button4
	RJMP Action_buzzer
	



Action_button7 :
	CBI PORTC,2 ; turn on Top LED
	CBI PORTC,3 ; turn on Bot LED
	LDI R17, 0x00
	STS TIMSK1, R17
	CBI PORTB, 1
	RET

Action_button8 :
	CBI PORTC, 3 ; turn on Bot LED
	LDI R17, 0x00
	STS TIMSK1, R17
	CBI PORTB, 1
	RET

Action_button4 :
	CBI PORTC, 2 ; turn on Top LED
	LDI R17, 0x00
	STS TIMSK1, R17
	CBI PORTB, 1
	RET

Action_buzzer : 
	SBI PORTC, 3 ;turn off Bot LED 
	SBI PORTC, 2 ;turn off Top LED 
	;Adjust pitch 
	LDI R16, high(2272)
	STS OCR1AH, R16
	LDI R16,low(2272)
	STS OCR1AL, R16
	;Turn the buzzer on 
	LDI R17, (1<<OCIE1A)
	STS TIMSK1, R17
	RET

Action_All_OFF :
	SBI PORTC, 3 ;turn off Bot LED 
	SBI PORTC, 2 ;turn off Top LED 
	LDI R17, 0x00
	STS TIMSK1, R17
	CBI PORTB, 1
	RET

;Sends the 8 bits in R16 out MSB-First.Destroy R16 R17
SendByte : 
	LDI R17, 8
	CLC
SendByte_loop : 
	CBI PORTB,3 ;clearing data-in
	LSL R16     ; MSB-->Carry
	BRCC SendByte_skip ; branch if carry is 0
	SBI PORTB,3 ; carry was 1
SendByte_skip : 
	CBI PORTB,5
	SBI PORTB,5 ; rising edge to load the shift register 
	DEC R17
	BRNE SendByte_loop
	RET
;Latches and show
LatchAndShow : 
	CBI PORTB, 4
	SBI PORTB, 4 ;rising edge 
	NOP
	NOP
	CBI PORTB, 4 ; output the data and show the row visible 
	RET

SmallDelay:
    LDI R20,20

DelayLoop:
    DEC R20
    BRNE DelayLoop
    RET
/*Delay2:
    LDI R20, 1     
; outermost loop
OuterLoop2:
    LDI R18, 10    
; middle loop
MiddleLoop2:
    LDI R19, 20    
; inner loop
InnerLoop2:
    DEC R19
    BRNE InnerLoop2
    DEC R18
    BRNE MiddleLoop2
    DEC R20
    BRNE OuterLoop2
    RET*/

;Clearing the buzzer 
	;LDI R23, 0x00
	;STS TIMSK1, R23  ; Disable Timer 1
	;STS TIMSK0, R23  ; Disable Timer 0
	;CBI PORTB, 1     ; Pull buzzer pin low

;---------------------Flash Data Tables-------------------------
EvenPattern : 
	.db 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA
OddPattern :
	.db 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55

	; Define the table in Flash memory

CharTable:
    .db 0b00011000,0b00100100,0b01000010,0b01111110,0b01000010,0b01000010,0b01000010,0b00000000
    .db 0b01111100,0b01000010,0b01000010,0b01111100,0b01000010,0b01000010,0b01111100,0b00000000