;
; Project_Cellular_automaton.asm
; Project for Sensors and Micro-electronics
; Date : 2026
; Author : Laurent


;==================================
; Include ATmega328P definitions
;==================================
.INCLUDE "m328pdef.inc"

;======================================================
; Register definitions(.DEF) and Constants (.EQU)
;======================================================
;----ISR Exclusive registers----------------
.DEF Column_index  = R2     ; timer0, active physical row currently scanned
.DEF display_tempo = R3     ; timer0 temp holding for SRAM fetch
.DEF beat_counter  = R6     ; timer2 software beat counter
.DEF debounce_tick = R7     ; timer2 edit-cursor blink divider

;-------------Main state registers------------
.DEF playhead    = R4     ; current step (0-31) being played
.DEF cursor      = R5     ; edit cursor register 
.DEF seed_low    = R8     ; low byte of the LFSR seed
.DEF seed_high   = R9     ; high byte of the LFSR seed
.DEF rule_number = R10    ; selected cellular automaton rule
.DEF scale_index = R11    ; selected musical scale
.DEF Octave      = R12    ; current octave shift

;-------------General-purpose working registers------------
.DEF temp     = R16       ; temporary register
.DEF px_x     = R20       ; pixel X coordinate for drawing
.DEF px_y     = R21       ; pixel Y coordinate for drawing
.DEF px_state = R22       ; pixel state (0 = off, 1 = on)
;----------------Constant definition ----------------
.EQU NUM_COLS = 40
.EQU NUM_ROWS = 14
.EQU CA_WIDTH = 32 ;Width of the waterfall
.EQU HISTORY_ROWS = 14
.EQU HISTORY_BYTES = 56 ; 14 Generations of 32bits=4byte 14*4=56 bytes of memory
.EQU NUM_RULES = 3 ; RULE 30(chaotic and random), 90(sierpinski triangle),
; rule 110(turing complete complex patterns)
.EQU NUM_SCALES = 3 ; MAJOR, MINOR, PENTATONIC
.EQU NUM_KEYS = 16
.EQU MODE_RUN_BIT = 0 ; bit 0= RUN/EDIT
.EQU MODE_PLAY_BIT = 1 ; bit 1 = PLAY/PAUSE
.EQU MODE_BLINK_BIT = 2 ; bit 2= CURSOR BLINK
.EQU MODE_MUTE_BIT  = 3    ; Bit 3 = GLOBAL MUTE
.EQU TIMER0_PRESCALE = (1<<CS02) ; T0 Prescaler /256 ( CS02=1 CS01=0 CS00=0 cf datasheet)
.EQU TIMER1_PRESCALE = (1<<CS11) ; T1 Prescaler /8 (CS12=0 CS11=1 CS10=1 cf datasheet)
.EQU DEFAULT_BPM = 120
.EQU MIN_BPM = 60
.EQU MAX_BPM = 300
.EQU FRAME_BYTES = 80                 ; 8 physical row holding 80pixels( 40 top +40 bottom )=10bytes 8*10= 80
.EQU BYTES_PER_PHYSICAL_ROW = 10
.EQU PHYSICAL_ROWS = 8
.EQU VISIBLE_PHYSICAL_ROWS = 7
.EQU TIMER0_OCR_VALUE = 99            ; /256 gives about 625 row scans/s
.EQU INPUT_TICK_DIV = 10              ; Timer2 overflow about 1 ms, input about 10 ms
.EQU BEAT_TICKS = 122                 ; about 125 ms, close to 120 BPM sixteenth notes
.EQU DEFAULT_RULE = 30
.EQU DEFAULT_LFSR_LOW = 0xE1          ; arbitrary cannot start at 0 and LFSR is 16 bit
.EQU DEFAULT_LFSR_HIGH = 0xAC
.EQU NB_NOTES = 48                    ;Octave 1 : 12 notes Octave 2 : 12 notes Octave 3 : 12 notes Octave 4 : 12 notes
.EQU ADC_LOW_TH = 64                  ;ADC Thresholds, 8bit mode
.EQU ADC_HIGH_TH = 192

; Pins
.EQU SW_PIN = 0
.EQU BUZZER_PIN = 1
.EQU JS_BTN_PIN = 2
.EQU DISP_DATA = 3
.EQU DISP_LATCH = 4
.EQU DISP_CLOCK = 5
.EQU LED_LOW_PIN = 2
.EQU LED_HIGH_PIN = 3
.EQU KP_COL4 = 0
.EQU KP_COL3 = 1
.EQU KP_COL2 = 2
.EQU KP_COL1 = 3

; Joystick direction codes
; Stored in prev_js_dir so actions occur only once per movement.
.EQU DIR_LEFT  = 1
.EQU DIR_RIGHT = 2
.EQU DIR_UP    = 4
.EQU DIR_DOWN  = 8

;=====================================
; SRAM VARIABLES(.DSEG)
;=====================================
.DSEG
.ORG SRAM_START

history_buffer    : .byte 56 ; 14 generation*32bit= 14*4
frame_buffer      : .byte 80 ; 8 rows and 80 led per rows= 8*10 byte
current_gen       : .byte 4  ; one CA generation = 32bit= 4 byte
next_gen          : .byte 4  ;same
playhead_pos      : .byte 1
Cursor_pos        : .byte 1 ;from 0 to 31 position
bpm_value         : .byte 2 ;60 to 300 so 2 bytes
lfsr_seed         : .byte 2 ;LFSR= 16 bit 
rule_number_store : .byte 1
scale_index_store : .byte 1
octave_shift      : .byte 1
mode_flags        : .byte 1
input_tick_flag   : .byte 1   ; Set by Timer2(~10 ms). Main loop clears after reading keypad and joystick.
step_flag         : .byte 1   ; Set by Timer2 to advance one sequencer/CA step.
timer2_divider    : .byte 1   ; Software counter used to divide fast Timer2 OV into slow.
beat_tick_limit   : .byte 1   ; Number of Timer2 overflows needed before generating one sequencer step. Depends on BPM.
key_last          : .byte 1   ; Stores the last detected keypad value to ignore held keys and detect new presses only.
prev_js_dir       : .byte 1   ; Stores the previous joystick direction for edge detection
prev_js_click     : .byte 1   ; Stores the previous joystick button state to detect a new click only.
;========================================
; Interrupt adress Vectors(.CSEG)
;========================================
.CSEG
.ORG 0x0000
RJMP Initialisation ; jump to start

.ORG 0x001C ; timer 0 CTC use OCR0A cf datasheet
RJMP Timer0_ISR

.ORG 0x0016 ;Timer 1 CTC use OCR1A cf datasheet
RJMP Timer1_ISR

.ORG 0x0012 ; Timer 2 OV cf datasheet 
RJMP Timer2_ISR

;==========================================
; MAIN PROGRAM
;=========================================
.ORG 0x0034 ; end of interrupt vector table 

;------------INITIALISATION----------------
Initialisation:
; --- Initialize Stack Pointer ---
LDI R16, LOW(RAMEND)
OUT SPL, R16
LDI R16, HIGH(RAMEND)
OUT SPH, R16

CLR R1
CLI

; --- Setup of pins ---
; joystick button
CBI DDRB,2
SBI PORTB,2

; joystick analog axes: PC0 = X, PC1 = Y
CBI DDRC,0
CBI DDRC,1

; switch
CBI DDRB,0
SBI PORTB,0

; LED 1 and LED 2, active low
SBI DDRC,3
SBI PORTC,3
SBI DDRC,2
SBI PORTC,2

; buzzer
SBI DDRB,1
CBI PORTB,1

; keyboard setup: rows PD7-PD4 outputs, columns PD3-PD0 inputs with pullups
LDI R16, 0b11110000 ; = 1 for output =0 for input 
OUT DDRD, R16
LDI R16, 0b11111111 ; set with pulls up high.
OUT PORTD, R16

; shift register setup( PB3/PB4/PB5)
SBI DDRB,3
SBI DDRB,4
SBI DDRB,5
CBI PORTB,3
CBI PORTB,4
CBI PORTB,5

; ADC setup: AVCC reference, left adjusted, ADC0 default, prescaler /128
LDI R16, (1<<REFS0) | (1<<ADLAR) ; AVCC ref+Left adjusted
STS ADMUX, R16 ; ADC register
CLR R16
STS ADCSRB, R16
LDI R16, (1<<ADC0D) | (1<<ADC1D) ; 
STS DIDR0, R16
LDI R16, (1<<ADEN)|(1<<ADPS2)|(1<<ADPS1)|(1<<ADPS0) ; ADEN enable ADC, ADPS2 111 = prescale 128 
STS ADCSRA, R16 ; adc clock = 16MHz/128 = 125kHz good adc working frequency 

; Timer0 setup - CTC mode, refreshes the display from frame_buffer
LDI R16, (1<<WGM01)
OUT TCCR0A, R16 ; CTC mode
LDI R16, TIMER0_OCR_VALUE
OUT OCR0A, R16 ; comparator register 
LDI R16, TIMER0_PRESCALE
OUT TCCR0B, R16 ; starting timer with prescaler 
LDI R16, (1<<OCIE0A)
STS TIMSK0, R16 ;enable timer 0 

; Timer1 setup - CTC mode for buzzer pitch.
; TIMSK1 stays disabled until a note is played.
LDI R16, 0x00
STS TCCR1A, R16 ; CTC mode
LDI R16, (1<<WGM12) | TIMER1_PRESCALE
STS TCCR1B, R16 ; timer with prescaler 
LDI R16, 0x00
STS TIMSK1, R16 ; enable timer 1

; Timer2 setup - Normal mode, overflow interrupt for input tick and beat tick
LDI R16, 0x00
STS TCCR2A, R16 ; OV mode 
LDI R16, (1<<CS22) ; prescaler /64
STS TCCR2B, R16
LDI R16, (1<<TOIE2)
STS TIMSK2, R16 ; enabling timer 2 

RCALL Reset_All_State

SEI ; all interrupt flag enable 

;-----------Main loop ------------
main:

RCALL Poll_Switch_Mode          ; Read the RUN/EDIT switch and update mode

; ---------- Handle user inputs ----------
LDS R16, input_tick_flag        ; Has Timer2 requested an input scan
TST R16
BREQ Main_Check_Step_Flag       ; No = skip input handling

CLR R16
STS input_tick_flag, R16        ; Clear the input request flag

RCALL Read_Keyboard             ; Read keypad
RCALL Handle_Joystick           ; Read joystick

; Only redraw continuously while in EDIT mode
LDS R16, mode_flags
SBRC R16, MODE_RUN_BIT          ; If RUN mode skip the edit refresh
RJMP Main_Check_Step_Flag       
MOV R16, debounce_tick
TST R16
BRNE Main_Check_Step_Flag       ; Blink only every half-second
RCALL Render_From_History       ; Refresh display 
; ---------- Handle sequencer ----------
Main_Check_Step_Flag:
LDS R16, step_flag              ; Has Timer2 requested a new step
TST R16
BREQ main                       ; No = return to beginning
CLR R16
STS step_flag, R16              ; Clear the step request
LDS R16, mode_flags
SBRS R16, MODE_RUN_BIT          ; Only step in RUN mode
RJMP main
SBRS R16, MODE_PLAY_BIT         ; Ignore if playback is paused
RJMP main
RCALL Advance_Playhead_And_Sound ; Advance playhead and play note
RJMP main                       

;====================================
;INTERRUPT HANDLERS
;====================================

;===========================================
; TIMER0 ISR - CTC Compare Match A
; Displays one physical row of frame_buffer.
; frame_buffer uses 8 physical rows * 10 bytes per row = 80 bytes.
;===========================================
Timer0_ISR:
PUSH R16
IN R16, SREG
PUSH R16
PUSH R17
PUSH R18
PUSH R19
PUSH R20
PUSH R30
PUSH R31
PUSH R0
PUSH R1

; Z = frame_buffer + Column_index * 10
LDI R18, BYTES_PER_PHYSICAL_ROW
MUL Column_index, R18
MOV ZL, R0
MOV ZH, R1
CLR R1
LDI R16, LOW(frame_buffer)
LDI R17, HIGH(frame_buffer)
ADD ZL, R16
ADC ZH, R17

; Send the 10 column bytes for this physical row.
LDI R18, BYTES_PER_PHYSICAL_ROW
Timer0_Send_Cols:
LD display_tempo, Z+
MOV R16, display_tempo
RCALL SendByte
DEC R18
BRNE Timer0_Send_Cols

; Send row select byte: row 0 = 0x01, row 1 = 0x02, ...
LDI R16, 0x01
MOV R18, Column_index
TST R18
BREQ Timer0_RowMask_Ready
Timer0_RowMask_Loop:
LSL R16
DEC R18
BRNE Timer0_RowMask_Loop

Timer0_RowMask_Ready:
RCALL SendByte
RCALL LatchAndShow

; Next physical row, modulo 8
INC Column_index
MOV R16, Column_index
CPI R16, PHYSICAL_ROWS
BRLO Timer0_End
CLR Column_index

Timer0_End:
POP R1
POP R0
POP R31
POP R30
POP R20
POP R19
POP R18
POP R17
POP R16
OUT SREG, R16
POP R16
RETI

;===========================================
; TIMER1 ISR - CTC Compare Match A
; Sound interrupt. OCR1A controls frequency, ISR toggles PB1.
;===========================================
Timer1_ISR:
PUSH R16
IN R16, SREG
PUSH R16
SBI PINB,1
POP R16
OUT SREG,R16
POP R16
RETI

;===========================================
; TIMER2 ISR - Overflow
; Creates a slow input tick and a sequencer beat tick
;===========================================
Timer2_ISR:
PUSH R16
IN R16, SREG
PUSH R16
PUSH R17

; input divider: about 10 ms
LDS R16, timer2_divider
INC R16
CPI R16, INPUT_TICK_DIV
BRLO Timer2_Save_Input_Divider
CLR R16
STS input_tick_flag, R16
LDI R16, 1
STS input_tick_flag, R16

; Blink divider: 25 input ticks = about 250 ms, so the cursor
; completes one visible on/off cycle in about half a second.
INC debounce_tick
MOV R16, debounce_tick
CPI R16, 25
BRLO Timer2_Blink_Done
CLR debounce_tick
LDS R16, mode_flags
LDI R17, (1<<MODE_BLINK_BIT)
EOR R16, R17 ; toggles bits( with a XOR)
STS mode_flags, R16

Timer2_Blink_Done:
CLR R16

Timer2_Save_Input_Divider:
STS timer2_divider, R16

; beat divider: about 125 ms
INC beat_counter
MOV R16, beat_counter
LDS R17, beat_tick_limit
CP R16, R17
BRLO Timer2_End
CLR beat_counter
LDI R16, 1
STS step_flag, R16

Timer2_End:
POP R17
POP R16
OUT SREG, R16
POP R16
RETI

;===================================
; FUNCTIONS
;===================================

;--------------------------------------------------
; Reset all project state to a clean default.
;--------------------------------------------------
Reset_All_State:
CLR Column_index
CLR display_tempo
CLR beat_counter
CLR debounce_tick
CLR playhead
CLR cursor
CLR seed_low
CLR seed_high
CLR rule_number
CLR scale_index
CLR Octave

CLR R16
STS input_tick_flag, R16
STS step_flag, R16
STS timer2_divider, R16
STS beat_tick_limit, R16
STS prev_js_dir, R16
STS prev_js_click, R16
STS Cursor_pos, R16
STS scale_index_store, R16
STS octave_shift, R16

LDI R16, 0xFF
STS key_last, R16

LDI R16, DEFAULT_LFSR_LOW
STS lfsr_seed, R16
MOV seed_low, R16
LDI R16, DEFAULT_LFSR_HIGH
STS lfsr_seed+1, R16
MOV seed_high, R16

LDI R16, DEFAULT_RULE
STS rule_number_store, R16
MOV rule_number, R16

LDI R16, (1<<MODE_RUN_BIT) | (1<<MODE_PLAY_BIT)
STS mode_flags, R16

LDI R16, LOW(DEFAULT_BPM)
STS bpm_value, R16
LDI R16, HIGH(DEFAULT_BPM)
STS bpm_value+1, R16
RCALL Update_Beat_Tick_From_BPM

RCALL Mute_Buzzer
RCALL Clear_Grid_Data
RCALL Reseed_Current_Gen
RCALL Render_From_History
RET

;--------------------------------------------------
; Update the Timer2 software beat limit from bpm_value.
; bpm_value changes in steps of 10 BPM from 60 to 300.
; The table values are Timer2 overflow counts, about 1.024 ms each
; convert BPM value into index to the BPM table.
;--------------------------------------------------
Update_Beat_Tick_From_BPM:
PUSH R16
PUSH R17
PUSH R18
PUSH R30
PUSH R31

LDS R16, bpm_value ;bpm value is 16 bits so R16 high byte R17 low byte 
LDS R17, bpm_value+1

; Clamp BPM 

TST R17 ; check if highbyte is 0(if no good, minimum 60 BPM) checking upper limit 
BRNE BPM_Check_High
CPI R16, MIN_BPM
BRSH BPM_Not_Too_Low
LDI R16, MIN_BPM ; = 0x003C = 60
CLR R17
STS bpm_value, R16 ; Clamping BPM min to 60
STS bpm_value+1, R17

BPM_Not_Too_Low:
RJMP BPM_Make_Index

BPM_Check_High:
; Clamp above 300 BPM. 300 decimal is 0x012C high byte=1(256) low byte = (44)
CPI R17, 1
BRLO BPM_Make_Index
BRNE BPM_Set_300 ;clamping BPM max to 300
CPI R16, 44
BRLO BPM_Make_Index
BREQ BPM_Make_Index

BPM_Set_300:
LDI R16, 44
LDI R17, 1
STS bpm_value, R16
STS bpm_value+1, R17

BPM_Make_Index:
; index = (bpm - 60) / 10, INdex 0 60 BPM, index 24 300BPM
SUBI R16, LOW(MIN_BPM)
SBCI R17, HIGH(MIN_BPM)
CLR R18

BPM_Index_Loop:
TST R17
BRNE BPM_Index_Subtract
CPI R16, 10
BRLO BPM_Load_Table

BPM_Index_Subtract:
SUBI R16, 10
SBCI R17, 0
INC R18
RJMP BPM_Index_Loop

BPM_Load_Table:
LDI ZL, LOW(BPM_Tick_Table*2) ; x2 because word are 2 bytes in Flash 
LDI ZH, HIGH(BPM_Tick_Table*2)
ADD ZL, R18
CLR R17
ADC ZH, R17
LPM R16, Z
STS beat_tick_limit, R16

POP R31
POP R30
POP R18
POP R17
POP R16
RET

Increase_BPM:
PUSH R16
PUSH R17

LDS R16, bpm_value
LDS R17, bpm_value+1
; if bpm is already 300 (0x012C), stop
CPI R17, 1
BRNE Increase_BPM_Not_Max
CPI R16, 44
BRSH Increase_BPM_End

Increase_BPM_Not_Max:
SUBI R16, LOW(-10)
SBCI R17, HIGH(-10)
STS bpm_value, R16
STS bpm_value+1, R17
RCALL Update_Beat_Tick_From_BPM

Increase_BPM_End:
POP R17
POP R16
RET

Decrease_BPM:
PUSH R16
PUSH R17

LDS R16, bpm_value
LDS R17, bpm_value+1
; if bpm <= 60, stop
TST R17
BRNE Decrease_BPM_Do
CPI R16, MIN_BPM+1
BRLO Decrease_BPM_End

Decrease_BPM_Do:
SUBI R16, LOW(10)
SBCI R17, HIGH(10)
STS bpm_value, R16
STS bpm_value+1, R17
RCALL Update_Beat_Tick_From_BPM

Decrease_BPM_End:
POP R17
POP R16
RET

;--------------------------------------------------
; Switch PB0 selects RUN or EDIT 
; HIGH = RUN, LOW = EDIT
;--------------------------------------------------
Poll_Switch_Mode:
LDS R16, mode_flags
MOV R17, R16
SBIS PINB, SW_PIN ; skip next inst if bit is set (=1 skip we run),(=0,switch to edit)
RJMP Switch_Edit

Switch_Run:
ORI R16, (1<<MODE_RUN_BIT) ;set bit 0 so RUN bit become 1 
RJMP Switch_Save

Switch_Edit:
ANDI R16, 0b11111110 ; ANDI clear bit 0 run bit become 0

Switch_Save:
STS mode_flags, R16
EOR R17, R16 ; detect if mode has changed ( XOR)
SBRS R17, MODE_RUN_BIT ; if didn't change XOR result =0 so RET
RET
SBRC R16, MODE_RUN_BIT ; means RUN MODE(xor=1) SO we skip to rendering 
RJMP Switch_Render_Mode
ORI R16, (1<<MODE_BLINK_BIT) ; EDIT Mode, enable cursor blink ( MODE_BLINK_BIT)
STS mode_flags, R16
CLR debounce_tick
RCALL Mute_Buzzer

Switch_Render_Mode:
RCALL Render_From_History
RET

;--------------------------------------------------
; Keyboard scanner.
; Returns through action routines on a new key press only.
;PD7 PD6 PD5 PD4   --> Rows (outputs)

;PD3 PD2 PD1 PD0   --> Columns (inputs)
;--------------------------------------------------
Read_Keyboard:
RCALL Scan_Keypad_Raw
LDS R16, key_last
CP R17, R16
BREQ Read_Keyboard_End
STS key_last, R17
CPI R17, 0xFF
BREQ Read_Keyboard_End
RCALL Check_Buttons

Read_Keyboard_End:
RET

; Output: R17 = key value, or 0xFF if no key pressed.
; Key layout:
;   7 8 9 F
;   4 5 6 E
;   1 2 3 D
;   A 0 B C

Scan_Keypad_Raw:
LDI R17, 0xFF
LDI R16, 0b11111111 ; enable pull up resistors
OUT PORTD, R16
LDI R16, 0b11110000 ;row outputs(read),column input
OUT DDRD, R16

;---------------SCAN ROW 1 (7, 8, 9, F)--------------
LDI R16, 0b01111111 ; row 1 low(=0)
OUT PORTD, R16
NOP
NOP
IN R19, PIND
ANDI R19, 0b00001111 ; masking because only row output matters(PD3-PD0)
CPI R19, 0b00001111 ; if no key is pressed scan row 2 
BREQ Scan_Row_2
SBIS PIND, 3 ; skip if bit is set 
LDI R17, 7
SBIS PIND, 3
RJMP Scan_Keypad_Found
SBIS PIND, 2
LDI R17, 8
SBIS PIND, 2
RJMP Scan_Keypad_Found
SBIS PIND, 1
LDI R17, 9
SBIS PIND, 1
RJMP Scan_Keypad_Found
SBIS PIND, 0
LDI R17, 0x0F
SBIS PIND, 0
RJMP Scan_Keypad_Found

;---------------SCAN ROW 2 (4, 5, 6, E)--------------
Scan_Row_2:
LDI R16, 0b10111111 ; PD6 LOW row 2 
OUT PORTD, R16
NOP
NOP
IN R19, PIND
ANDI R19, 0b00001111
CPI R19, 0b00001111
BREQ Scan_Row_3
SBIS PIND, 3
LDI R17, 4
SBIS PIND, 3
RJMP Scan_Keypad_Found
SBIS PIND, 2
LDI R17, 5
SBIS PIND, 2
RJMP Scan_Keypad_Found
SBIS PIND, 1
LDI R17, 6
SBIS PIND, 1
RJMP Scan_Keypad_Found
SBIS PIND, 0
LDI R17, 0x0E
SBIS PIND, 0
RJMP Scan_Keypad_Found

;---------------SCAN ROW 3 (1, 2, 3, D)--------------
Scan_Row_3:
LDI R16, 0b11011111 ; PD5 LOW, ROW 3 
OUT PORTD, R16
NOP
NOP
IN R19, PIND
ANDI R19, 0b00001111
CPI R19, 0b00001111
BREQ Scan_Row_4
SBIS PIND, 3
LDI R17, 1
SBIS PIND, 3
RJMP Scan_Keypad_Found
SBIS PIND, 2
LDI R17, 2
SBIS PIND, 2
RJMP Scan_Keypad_Found
SBIS PIND, 1
LDI R17, 3
SBIS PIND, 1
RJMP Scan_Keypad_Found
SBIS PIND, 0
LDI R17, 0x0D
SBIS PIND, 0
RJMP Scan_Keypad_Found

;---------------SCAN ROW 4 (A, 0, B, C)--------------
Scan_Row_4:
LDI R16, 0b11101111 ; PD4 LOW, ROW 4
OUT PORTD, R16
NOP ; needed for signal stabilization
NOP
IN R19, PIND
ANDI R19, 0b00001111
CPI R19, 0b00001111
BREQ Scan_Keypad_Idle
SBIS PIND, 3
LDI R17, 0x0A
SBIS PIND, 3
RJMP Scan_Keypad_Found
SBIS PIND, 2
LDI R17, 0
SBIS PIND, 2
RJMP Scan_Keypad_Found
SBIS PIND, 1
LDI R17, 0x0B
SBIS PIND, 1
RJMP Scan_Keypad_Found
SBIS PIND, 0
LDI R17, 0x0C
SBIS PIND, 0
RJMP Scan_Keypad_Found

Scan_Keypad_Idle:
LDI R16, 0b11111111 ;restore everything high
OUT PORTD, R16
LDI R16, 0b11110000
OUT DDRD, R16
RET

Scan_Keypad_Found:
LDI R16, 0b11111111
OUT PORTD, R16
LDI R16, 0b11110000
OUT DDRD, R16
RET

Check_Buttons:

    CPI R17, 7 ; R17 act as the Action button register 
    BRNE Not7 ; can't use BREQ because action too far --> BRNE+RJMP
    RJMP Action_Button7
Not7:

    CPI R17, 8
    BRNE Not8
    RJMP Action_Button8
Not8:

    CPI R17, 9
    BRNE Not9
    RJMP Action_Button9
Not9:

    CPI R17, 4
    BRNE Not4
    RJMP Action_Button4
Not4:

    CPI R17, 5
    BRNE Not5
    RJMP Action_Button5
Not5:

    CPI R17, 6
    BRNE Not6
    RJMP Action_Button6
Not6:

    CPI R17, 1
    BRNE Not1
    RJMP Action_Button1
Not1:

    CPI R17, 2
    BRNE Not2
    RJMP Action_Button2
Not2:

    CPI R17, 0x0D
    BRNE NotD
    RJMP Action_ButtonD
NotD:

    CPI R17, 0x0A
    BRNE NotA
    RJMP Action_ButtonA
NotA:

    CPI R17, 0
    BRNE Not0
    RJMP Action_button0
Not0:

    CPI R17, 0x0B
    BRNE NotB
    RJMP Action_buttonB
NotB:

    CPI R17, 0x0C
    BRNE NotC
    RJMP Action_buttonC
NotC:

    CPI R17, 0x0E
    BRNE NotE
    RJMP Action_buttonE
NotE:

    CPI R17, 0x0F
    BRNE NotF
    RJMP Action_buttonF
NotF:

    RET

Action_Button7:
; Rule 30
LDI R16, 30
STS rule_number_store, R16
MOV rule_number, R16
RET

Action_Button8:
; Rule 90
LDI R16, 90
STS rule_number_store, R16
MOV rule_number, R16
RET

Action_Button9:
; Rule 110
LDI R16, 110
STS rule_number_store, R16
MOV rule_number, R16
RET

Action_Button4:
; Major scale
LDI R16, 0
STS scale_index_store, R16
MOV scale_index, R16
RET

Action_Button5:
; Minor scale
LDI R16, 1
STS scale_index_store, R16
MOV scale_index, R16
RET

Action_Button6:
; Pentatonic scale
LDI R16, 2
STS scale_index_store, R16
MOV scale_index, R16
RET

Action_Button1:
; Reseed current generation with the LFSR.
LDS R16, lfsr_seed
LDS R17, lfsr_seed+1 ; loading current 16 bit LFSR
IN R18, TCNT0 ; read value of timer 0 
EOR R16, R18 ; XOR the LFSR seed with the timing for randomness
LDI R18, 0x2A
EOR R17, R18 ; also modify the high byte ( 16 bit LFSR)
STS lfsr_seed, R16
STS lfsr_seed+1, R17 ; store new seed
MOV seed_low, R16
MOV seed_high, R17
RCALL Clear_Grid_Data ; erase everything 
RCALL Reseed_Current_Gen
RCALL Render_From_History
RET

Action_Button2:
; Clear grid
RCALL Mute_Buzzer
RCALL Clear_Grid_Data
RCALL Render_From_History
RET

Action_ButtonD:
; Reset
RCALL Reset_All_State
RET

Action_ButtonA:
; Octave down
LDS R16, octave_shift
TST R16
BREQ Action_ButtonA_End
DEC R16
STS octave_shift, R16
MOV Octave, R16
Action_ButtonA_End:
RET

Action_button0:
; Octave up. Limited to 1 so the 32-step scale stays inside Note_Table.
LDS R16, octave_shift
CPI R16, 1
BRSH Action_button0_End
INC R16
STS octave_shift, R16
MOV Octave, R16
Action_button0_End:
RET

Action_buttonB:
; Toggle play/pause.
LDS R16, mode_flags
LDI R18, (1<<MODE_PLAY_BIT)
EOR R16, R18
STS mode_flags, R16
SBRS R16, MODE_PLAY_BIT
RCALL Mute_Buzzer
RET

Action_buttonC:
    ; Toggle Global Mute (Bit 3) on/off
    LDS  R16, mode_flags
    LDI  R18, (1<<MODE_MUTE_BIT)
    EOR  R16, R18               ; Flip the mute bit
    STS  mode_flags, R16
    
    ; If we just turned mute ON (Bit 3 is now 1), kill the hanging sound immediately
    SBRC R16, MODE_MUTE_BIT     
    RCALL Mute_Buzzer
    RET

Action_buttonE:
RET

Action_buttonF:
RET

Action_All_OFF:
RET

;--------------------------------------------------
; Joystick handling.
; RUN mode:
;   left/right = BPM down/up
;   up/down    = octave up/down
;   click      = play/pause
; EDIT mode:
;   left/right = move cursor on row 0
;   click      = toggle current cell, so that bit plays later in RUN
;--------------------------------------------------
Handle_Joystick:
RCALL Handle_Joystick_Click

LDI R18, 0
RCALL Read_ADC
CPI R19, ADC_HIGH_TH ; high threshold of ADC
BRSH Joy_Right
CPI R19, ADC_LOW_TH ; LOW threshold of ADC 
BRLO Joy_Left

LDI R18, 1
RCALL Read_ADC
CPI R19, ADC_HIGH_TH
BRSH Joy_Down
CPI R19, ADC_LOW_TH
BRLO Joy_Up

Joy_Center:
CLR R16
STS prev_js_dir, R16
RET

Joy_Left:
LDI R16, DIR_LEFT
RCALL Joystick_Direction_Edge
TST R16
BREQ Handle_Joystick_End
LDS R18, mode_flags
SBRC R18, MODE_RUN_BIT
RJMP Joy_Left_Run
RCALL Cursor_Left
RCALL Render_From_History
RET

Joy_Left_Run:
RCALL Decrease_BPM
RCALL Render_From_History
RET

Joy_Right:
LDI R16, DIR_RIGHT
RCALL Joystick_Direction_Edge
TST R16
BREQ Handle_Joystick_End
LDS R18, mode_flags
SBRC R18, MODE_RUN_BIT
RJMP Joy_Right_Run
RCALL Cursor_Right
RCALL Render_From_History
RET

Joy_Right_Run:
RCALL Increase_BPM
RCALL Render_From_History
RET

Joy_Up:
LDI R16, DIR_UP
RCALL Joystick_Direction_Edge
TST R16
BREQ Handle_Joystick_End
LDS R18, mode_flags
SBRC R18, MODE_RUN_BIT
RJMP Joy_Up_Run
RET

Joy_Up_Run:
RCALL Action_button0
RET

Joy_Down:
LDI R16, DIR_DOWN
RCALL Joystick_Direction_Edge
TST R16
BREQ Handle_Joystick_End
LDS R18, mode_flags
SBRC R18, MODE_RUN_BIT
RJMP Joy_Down_Run
RET

Joy_Down_Run:
RCALL Action_ButtonA
RET

Handle_Joystick_End:
RET

Joystick_Direction_Edge:
; Input R16 = direction code. Output R16 = 1 if new direction, 0 if held.
PUSH R17
MOV R17, R16
LDS R16, prev_js_dir
CP R16, R17
BREQ Joy_Direction_Held
STS prev_js_dir, R17
LDI R16, 1
POP R17
RET

Joy_Direction_Held:
CLR R16
POP R17
RET

Handle_Joystick_Click:
; PB2 LOW means pressed.
CLR R17
SBIS PINB, JS_BTN_PIN
LDI R17, 1
LDS R16, prev_js_click
CP R17, R16
BREQ Handle_Joystick_Click_End
STS prev_js_click, R17
TST R17
BREQ Handle_Joystick_Click_End

LDS R16, mode_flags
SBRC R16, MODE_RUN_BIT
RJMP Handle_Joystick_Click_Run

RCALL Toggle_Cursor_Cell
RCALL Render_From_History
RJMP Handle_Joystick_Click_End

Handle_Joystick_Click_Run:
LDI R18, (1<<MODE_PLAY_BIT)
EOR R16, R18
STS mode_flags, R16
SBRS R16, MODE_PLAY_BIT
RCALL Mute_Buzzer

Handle_Joystick_Click_End:
RET

; ADC READER SUBROUTINE
;only lower 4 bit of ADMUX select chanel 
;we use left adjust because we only need 8 bit ( Joystick still 124, up 256 down 0)
; Input: R18 (Channel 0-15)
; Output: R19 (8-bit ADC result)
Read_ADC:
PUSH R16
PUSH R18
ANDI R18, 0x0F
ORI R18, (1<<REFS0) | (1<<ADLAR) ; AVVC Reference ( 5V) and left adjust for 8 bit instead of 10 bit
STS ADMUX, R18 ; Ouput in R18 
NOP ; small delay after channel change 
NOP

LDS R16, ADCSRA
ORI R16, (1<<ADSC) ; set ADSC for starting conversion( Analog to digital)
STS ADCSRA, R16

Wait_For_ADC:
LDS R16, ADCSRA ; read ADC status
SBRC R16, ADSC ; ADSC=1 while it's running then it turn to 0
RJMP Wait_For_ADC

LDS R19, ADCH ; read the 8 MSB of the conversion results 
POP R18
POP R16
RET

;--------------------------------------------------
; Cursor helpers.
; EDIT mode uses one 32-bit melody row. Cursor_pos stores x only.
; y is always 0, so toggled cells are immediately playable in RUN.
;--------------------------------------------------
;history buffer each row is 4 bytes

Get_Cursor_X:
LDS R20, Cursor_pos
RET

Set_Cursor_X:
STS Cursor_pos, R20
RET

Get_Cursor_Y:
CLR R21
RET

Set_Cursor_Y:
RET

Cursor_Left:
RCALL Get_Cursor_X
TST R20
BREQ Cursor_Left_End
DEC R20
RCALL Set_Cursor_X
Cursor_Left_End:
RET

Cursor_Right:
RCALL Get_Cursor_X
CPI R20, CA_WIDTH-1
BRSH Cursor_Right_End
INC R20
RCALL Set_Cursor_X
Cursor_Right_End:
RET

Cursor_Up:
RET

Cursor_Down:
RET

Toggle_Cursor_Cell:
PUSH R17
PUSH R18
PUSH R19
PUSH R20
PUSH R21
PUSH R30
PUSH R31

RCALL Get_Cursor_X
MOV R17, R20
RCALL Get_Cursor_Y
MOV R18, R21
RCALL Get_History_Address
LD R20, Z
EOR R20, R19
ST Z, R20

TST R18
BRNE Toggle_Cursor_Cell_End
RCALL Copy_History_Top_To_Current

Toggle_Cursor_Cell_End:
POP R31
POP R30
POP R21
POP R20
POP R19
POP R18
POP R17
RET

; Input: R17 = x 0..31, R18 = y 0..13 y= nb of row skipped ( each row has 4 bytes=32 columns) ex y=2 2*4=8 bytes skip)
; inside that row we divide by 8 example x=13/8 = Byte 1 total offset = y*4+x/8
;Byte0 = bits 0..7
;Byte1 = bits 8..15
;Byte2 = bits 16..23
;Byte3 = bits 24..31
; Output: Z = history_buffer + y*4 + x/8, R19 = bit mask 1<<(x&7)

Get_History_Address:
PUSH R16
PUSH R17
PUSH R18
PUSH R20

MOV R16, R18
LSL R16
LSL R16
MOV R20, R17
LSR R20
LSR R20
LSR R20
ADD R16, R20

LDI ZL, LOW(history_buffer)
LDI ZH, HIGH(history_buffer)
ADD ZL, R16
CLR R20
ADC ZH, R20

MOV R20, R17
ANDI R20, 0x07 ; only the lowest 3 bit remain ( 0x07=00000111) useful modulo 8.
LDI R19, 1
History_Mask_Loop:
TST R20
BREQ History_Mask_Done
LSL R19
DEC R20
RJMP History_Mask_Loop

History_Mask_Done:
POP R20
POP R18
POP R17
POP R16
RET

;--------------------------------------------------
; Sequencer step and sound.
; One active bit at the current playhead position plays a note.
; One inactive bit is silence.
; Pitch increases from low to high as playhead goes 0..31.
;--------------------------------------------------
Advance_Playhead_And_Sound:
RCALL Render_From_History
RCALL Play_Playhead_Note

LDS R16, playhead_pos
INC R16
CPI R16, CA_WIDTH
BRLO Advance_Save_Playhead

CLR R16
STS playhead_pos, R16
MOV playhead, R16
RCALL Apply_Rule
RCALL Shift_Waterfall
RCALL Render_From_History
RET

Advance_Save_Playhead:
STS playhead_pos, R16
MOV playhead, R16
RET

Play_Playhead_Note:
PUSH R17
PUSH R18
PUSH R19
PUSH R20
PUSH R30
PUSH R31

LDS R16, mode_flags
SBRS R16, MODE_PLAY_BIT
RJMP Play_Playhead_Mute

SBRC R16, MODE_MUTE_BIT    ; If MUTE bit is 1, skip playing the note!
RJMP Play_Playhead_Mute

LDS R18, playhead_pos
RCALL Get_Current_Bit
TST R19
BREQ Play_Playhead_Mute

; Select the scale table.
LDS R16, scale_index_store
CPI R16, 1
BREQ Play_Use_Minor
CPI R16, 2
BREQ Play_Use_Penta

Play_Use_Major:
LDI ZL, LOW(Major_Scale_32*2) ; (*2 because word are 16 bits)
LDI ZH, HIGH(Major_Scale_32*2)
RJMP Play_Get_Index

Play_Use_Minor:
LDI ZL, LOW(Minor_Scale_32*2)
LDI ZH, HIGH(Minor_Scale_32*2)
RJMP Play_Get_Index

Play_Use_Penta:
LDI ZL, LOW(Pentatonic_Scale_32*2)
LDI ZH, HIGH(Pentatonic_Scale_32*2)

Play_Get_Index:
LDS R17, playhead_pos
ADD ZL, R17
CLR R18
ADC ZH, R18
LPM R17, Z

; Add octave shift: 0 or 12 semitones.
LDS R18, octave_shift
LDI R19, 12
MUL R18, R19
ADD R17, R0
CLR R1

RCALL Play_Note_Index
RJMP Play_Playhead_End

Play_Playhead_Mute:
RCALL Mute_Buzzer

Play_Playhead_End:
POP R31
POP R30
POP R20
POP R19
POP R18
POP R17
RET

; Input: R17 = note index in Note_Table, or out of range for mute.
Play_Note_Index:
PUSH R16
PUSH R18
PUSH R19
PUSH R20
PUSH R30
PUSH R31

CPI R17, NB_NOTES ;R17 contain NOTE INDEX ( 0 first note 10 eleventh note)
BRSH Play_Note_Mute

MOV R18, R17 ; copy the note index
CLR R19
LSL R18
ROL R19 ; multiply note index by 2 because Note_table is 16 bit(2 bytes)( shift left with ROL)

LDI ZL, LOW(Note_Table*2)
LDI ZH, HIGH(Note_Table*2)
ADD ZL, R18
ADC ZH, R19

LPM R18, Z+
LPM R19, Z

; Write 16-bit OCR1A high byte first. OCR1A is 16 bit output compare register of T1
STS OCR1AH, R19
STS OCR1AL, R18

; Reset timer phase for cleaner attacks on each note.
CLR R16
STS TCNT1H, R16 ; configure timer 1 for notes 
STS TCNT1L, R16

LDI R16, (1<<OCIE1A)
STS TIMSK1, R16 ; enable timer interrupt again play everytime TCNT1==OCR1A
RJMP Play_Note_End

Play_Note_Mute:
RCALL Mute_Buzzer

Play_Note_End:
POP R31
POP R30
POP R20
POP R19
POP R18
POP R16
RET

Mute_Buzzer:
PUSH R16
CLR R16
STS TIMSK1, R16 ;disable timer 1 interrupt 
CBI PORTB, BUZZER_PIN ; force buzzer pin low 
POP R16
RET

;--------------------------------------------------
; Cellular automaton.
; current_gen and next_gen are 32 bits each.
; Rule number is read from rule_number_store.
;rule : For each cell (0..31):
   ; Read left neighbour
  ;  Read current cell
   ; Read right neighbour
   ; Form a 3-bit number
  ;  Look up the corresponding output bit in the rule number( R30, R90, R110)
  ;  Store the result in next_gen
;When finished:
 ;   Copy next_gen into current_gen

;--------------------------------------------------
Apply_Rule:
PUSH R18
PUSH R19
PUSH R20
PUSH R21
PUSH R22
PUSH R23

RCALL Clear_Next_Gen
CLR R20

Apply_Rule_Loop:
; read left neighbour
MOV R18, R20 ; R20 goes from 0 to 31
TST R18
BRNE Apply_Left_No_Wrap ; automaton is circular if x=0 we read left=31
LDI R18, CA_WIDTH-1
RJMP Apply_Left_Read

Apply_Left_No_Wrap:
DEC R18

Apply_Left_Read:
RCALL Get_Current_Bit ; reads current_gen(left) and return R19 =0 or 1
LSL R19
LSL R19 ; multiply by 4 because left neighbour is the MSB  of the 3 bit neighbour 
MOV R21, R19

; read the center bit 
MOV R18, R20
RCALL Get_Current_Bit
LSL R19
OR R21, R19

; read right neighbour bit 
MOV R18, R20
INC R18
CPI R18, CA_WIDTH
BRLO Apply_Right_Read
CLR R18

Apply_Right_Read:
RCALL Get_Current_Bit
OR R21, R19 ; example left=1 center=0 right=1 R21=101=5 ( base 2)

; output = (rule >> neighbourhood) & 1
LDS R22, rule_number_store ; rule 30, 90 or 110 
MOV R23, R21
Apply_Rule_Shift:
TST R23
BREQ Apply_Rule_Shift_Done
LSR R22
DEC R23
RJMP Apply_Rule_Shift

Apply_Rule_Shift_Done:
ANDI R22, 1 ; keeps only bit 0 after shifting the value of the next cells 
MOV R18, R20
MOV R19, R22
RCALL Set_Next_Bit

INC R20
CPI R20, CA_WIDTH
BRLO Apply_Rule_Loop

RCALL Copy_Next_To_Current

POP R23
POP R22
POP R21
POP R20
POP R19
POP R18
RET

; Input: R18 = bit index 0..31. Output: R19 = 0 or 1.
Get_Current_Bit:
PUSH R16
PUSH R18
PUSH R20
PUSH R21
PUSH R30
PUSH R31

MOV R20, R18
LSR R20
LSR R20
LSR R20

LDI ZL, LOW(current_gen)
LDI ZH, HIGH(current_gen)
ADD ZL, R20
CLR R16
ADC ZH, R16
LD R21, Z

MOV R20, R18
ANDI R20, 0x07
LDI R19, 1
Current_Mask_Loop:
TST R20
BREQ Current_Mask_Done
LSL R19
DEC R20
RJMP Current_Mask_Loop

Current_Mask_Done:
AND R21, R19
BREQ Current_Bit_Zero
LDI R19, 1
RJMP Current_Bit_End

Current_Bit_Zero:
CLR R19

Current_Bit_End:
POP R31
POP R30
POP R21
POP R20
POP R18
POP R16
RET

; Input: R18 = bit index 0..31, R19 = 0/1.
Set_Next_Bit:
TST R19
BREQ Set_Next_Bit_End

PUSH R16
PUSH R18
PUSH R20
PUSH R21
PUSH R30
PUSH R31

MOV R20, R18
LSR R20
LSR R20
LSR R20

LDI ZL, LOW(next_gen)
LDI ZH, HIGH(next_gen)
ADD ZL, R20
CLR R16
ADC ZH, R16

MOV R20, R18
ANDI R20, 0x07
LDI R21, 1
Next_Mask_Loop:
TST R20
BREQ Next_Mask_Done
LSL R21
DEC R20
RJMP Next_Mask_Loop

Next_Mask_Done:
LD R16, Z
OR R16, R21
ST Z, R16

POP R31
POP R30
POP R21
POP R20
POP R18
POP R16

Set_Next_Bit_End:
RET

Clear_Next_Gen:
PUSH R16
PUSH R18
PUSH R30
PUSH R31

LDI ZL, LOW(next_gen)
LDI ZH, HIGH(next_gen)
LDI R18, 4
CLR R16
Clear_Next_Loop:
ST Z+, R16
DEC R18
BRNE Clear_Next_Loop

POP R31
POP R30
POP R18
POP R16
RET

Copy_Next_To_Current:
PUSH R16
PUSH R18
PUSH R28
PUSH R29
PUSH R30
PUSH R31

LDI ZL, LOW(next_gen)
LDI ZH, HIGH(next_gen)
LDI YL, LOW(current_gen)
LDI YH, HIGH(current_gen)
LDI R18, 4
Copy_Next_Loop:
LD R16, Z+
ST Y+, R16
DEC R18
BRNE Copy_Next_Loop

POP R31
POP R30
POP R29
POP R28
POP R18
POP R16
RET

Copy_Current_To_History_Top:
PUSH R16
PUSH R18
PUSH R28
PUSH R29
PUSH R30
PUSH R31

LDI ZL, LOW(current_gen)
LDI ZH, HIGH(current_gen)
LDI YL, LOW(history_buffer)
LDI YH, HIGH(history_buffer)
LDI R18, 4
Copy_Current_Top_Loop:
LD R16, Z+
ST Y+, R16
DEC R18
BRNE Copy_Current_Top_Loop

POP R31
POP R30
POP R29
POP R28
POP R18
POP R16
RET

Copy_History_Top_To_Current:
PUSH R16
PUSH R18
PUSH R28
PUSH R29
PUSH R30
PUSH R31

LDI ZL, LOW(history_buffer)
LDI ZH, HIGH(history_buffer)
LDI YL, LOW(current_gen)
LDI YH, HIGH(current_gen)
LDI R18, 4
Copy_History_Top_Loop:
LD R16, Z+
ST Y+, R16
DEC R18
BRNE Copy_History_Top_Loop

POP R31
POP R30
POP R29
POP R28
POP R18
POP R16
RET

Shift_Waterfall:
PUSH R16
PUSH R18
PUSH R28
PUSH R29
PUSH R30
PUSH R31

LDI ZL, LOW(history_buffer + 51)
LDI ZH, HIGH(history_buffer + 51)
LDI YL, LOW(history_buffer + 55)
LDI YH, HIGH(history_buffer + 55)
LDI R18, 52

Shift_Waterfall_Loop:
LD R16, Z
ST Y, R16
SBIW ZL, 1
SBIW YL, 1
DEC R18
BRNE Shift_Waterfall_Loop

POP R31
POP R30
POP R29
POP R28
POP R18
POP R16

RCALL Copy_Current_To_History_Top
RET

Clear_Grid_Data:
PUSH R16
PUSH R28
PUSH R29
PUSH R30
PUSH R31

; clear history_buffer + current_gen + next_gen
LDI ZL, LOW(history_buffer)
LDI ZH, HIGH(history_buffer)
LDI YL, LOW(HISTORY_BYTES + 8)
LDI YH, HIGH(HISTORY_BYTES + 8)
CLR R16
Clear_CA_Loop:
ST Z+, R16
SBIW YL, 1
BRNE Clear_CA_Loop

; clear frame_buffer
LDI ZL, LOW(frame_buffer)
LDI ZH, HIGH(frame_buffer)
LDI YL, LOW(FRAME_BYTES)
LDI YH, HIGH(FRAME_BYTES)
Clear_Frame_Loop:
ST Z+, R16
SBIW YL, 1
BRNE Clear_Frame_Loop

POP R31
POP R30
POP R29
POP R28
POP R16
RET

Reseed_Current_Gen:
PUSH R18
PUSH R19
PUSH R30
PUSH R31

LDI ZL, LOW(current_gen)
LDI ZH, HIGH(current_gen)
RCALL LFSR16_Step
ST Z+, R18
ST Z+, R19
RCALL LFSR16_Step
ST Z+, R18
ST Z+, R19
RCALL Copy_Current_To_History_Top

POP R31
POP R30
POP R19
POP R18
RET

; 16-bit Galois LFSR, polynomial 0xB400.
; Output: R18 low byte, R19 high byte.
LFSR16_Step:
PUSH R16
PUSH R20
PUSH R21

LDS R18, lfsr_seed
LDS R19, lfsr_seed+1
MOV R20, R18
ANDI R20, 1

LSR R19
ROR R18

TST R20
BREQ LFSR_No_Xor
LDI R21, 0xB4
EOR R19, R21

LFSR_No_Xor:
STS lfsr_seed, R18
STS lfsr_seed+1, R19
MOV seed_low, R18
MOV seed_high, R19

POP R21
POP R20
POP R16
RET

;--------------------------------------------------
; Rendering.
; history_buffer is bit-packed: 14 rows * 4 bytes.
; frame_buffer is hardware-packed: 8 rows * 10 bytes.
;--------------------------------------------------
Render_From_History:
PUSH R16
PUSH R17
PUSH R18
PUSH R23
PUSH R24
PUSH R25
PUSH R28
PUSH R29

RCALL Clear_Frame_Buffer

LDI YL, LOW(history_buffer)
LDI YH, HIGH(history_buffer)
CLR px_y

Render_Row_Loop:
CLR px_x
LDI R24, 4

Render_Byte_Loop:
LD R23, Y+
LDI R25, 8

Render_Bit_Loop:
SBRS R23, 0
RJMP Render_Bit_Off
LDI px_state, 1
RCALL Set_Pixel

Render_Bit_Off:
LSR R23
INC px_x
DEC R25
BRNE Render_Bit_Loop

DEC R24
BRNE Render_Byte_Loop

INC px_y
CPI px_y, NUM_ROWS
BRLO Render_Row_Loop

RCALL Draw_Mode_Overlay

POP R29
POP R28
POP R25
POP R24
POP R23
POP R18
POP R17
POP R16
RET

Draw_Mode_Overlay:
LDS R16, mode_flags
SBRS R16, MODE_RUN_BIT
RJMP Draw_Edit_Cursor

Draw_Playhead:
LDS px_x, playhead_pos
CLR px_y
LDI px_state, 1
Draw_Playhead_Loop:
RCALL Set_Pixel
INC px_y
CPI px_y, NUM_ROWS
BRLO Draw_Playhead_Loop
RJMP Draw_Mode_Letter

Draw_Edit_Cursor:
RCALL Get_Cursor_X
RCALL Get_Cursor_Y
LDS R16, mode_flags
CLR px_state
SBRC R16, MODE_BLINK_BIT
LDI px_state, 1
RCALL Set_Pixel
RJMP Draw_Mode_Letter

Draw_Mode_Letter:
PUSH R16
PUSH R18
PUSH R23
PUSH R24
PUSH R25
PUSH R30
PUSH R31
PUSH R20
PUSH R21
PUSH R22

LDI ZL, LOW(CharTable*2)
LDI ZH, HIGH(CharTable*2)
LDS R16, mode_flags
SBRC R16, MODE_RUN_BIT
RJMP Draw_Mode_Letter_Address_Ready
ADIW ZL, 8

Draw_Mode_Letter_Address_Ready:
LDI R18, 7

Draw_Mode_Letter_Row:
LPM R23, Z+
MOV px_y, R18
DEC px_y
LDI px_x, 35
LDI R24, 5
LDI R25, 0b00010000

Draw_Mode_Letter_Bit:
CLR px_state
MOV R16, R23
AND R16, R25
BREQ Draw_Mode_Letter_Pixel
LDI px_state, 1

Draw_Mode_Letter_Pixel:
RCALL Set_Pixel
INC px_x
LSR R25
DEC R24
BRNE Draw_Mode_Letter_Bit

DEC R18
BRNE Draw_Mode_Letter_Row

POP R22
POP R21
POP R20
POP R31
POP R30
POP R25
POP R24
POP R23
POP R18
POP R16
RET


Clear_Frame_Buffer:
PUSH R16
PUSH R28
PUSH R29
PUSH R30
PUSH R31

LDI ZL, LOW(frame_buffer)
LDI ZH, HIGH(frame_buffer)
LDI YL, LOW(FRAME_BYTES)
LDI YH, HIGH(FRAME_BYTES)
CLR R16
Clear_Frame_Buffer_Loop:
ST Z+, R16
SBIW YL, 1
BRNE Clear_Frame_Buffer_Loop

POP R31
POP R30
POP R29
POP R28
POP R16
RET

; Set one logical pixel in a 40 x 14 coordinate system.
; Input: px_x=R20, px_y=R21, px_state=R22.
Set_Pixel:
PUSH R16
PUSH R17
PUSH R18
PUSH R19
PUSH R20
PUSH R21
PUSH R23
PUSH R24
PUSH R25
PUSH R30
PUSH R31
PUSH R0
PUSH R1

CPI px_x, NUM_COLS
BRSH Set_Pixel_End
CPI px_y, NUM_ROWS
BRSH Set_Pixel_End

; Convert logical coordinates to physical 80 x 7 mapping.
CPI px_y, 7
BRSH Set_Pixel_Bottom

Set_Pixel_Top:
LDI R23, 79
SUB R23, px_x
LDI R24, 6
SUB R24, px_y
RJMP Set_Pixel_Address

Set_Pixel_Bottom:
LDI R23, 39
SUB R23, px_x
LDI R24, 13
SUB R24, px_y

Set_Pixel_Address:
; byte offset = physical_row * 10 + physical_col / 8
LDI R18, BYTES_PER_PHYSICAL_ROW
MUL R24, R18
MOV ZL, R0
MOV ZH, R1
CLR R1

MOV R18, R23
LSR R18
LSR R18
LSR R18
ADD ZL, R18
CLR R18
ADC ZH, R18

LDI R16, LOW(frame_buffer)
LDI R17, HIGH(frame_buffer)
ADD ZL, R16
ADC ZH, R17

; bit mask = 0x80 >> (physical_col & 7), because SendByte is MSB-first.
MOV R18, R23
ANDI R18, 0x07
LDI R25, 0x80
Set_Pixel_Mask_Loop:
TST R18
BREQ Set_Pixel_Mask_Ready
LSR R25
DEC R18
RJMP Set_Pixel_Mask_Loop

Set_Pixel_Mask_Ready:
LD R16, Z
TST px_state
BREQ Set_Pixel_Clear
OR R16, R25
RJMP Set_Pixel_Store

Set_Pixel_Clear:
COM R25
AND R16, R25

Set_Pixel_Store:
ST Z, R16

Set_Pixel_End:
POP R1
POP R0
CLR R1
POP R31
POP R30
POP R25
POP R24
POP R23
POP R21
POP R20
POP R19
POP R18
POP R17
POP R16
RET

;Sends the 8 bits in R16 out MSB-First. Destroys R16 R17.
SendByte:
LDI R17, 8
CLC

SendByte_loop:
CBI PORTB,3
LSL R16
BRCC SendByte_skip
SBI PORTB,3

SendByte_skip:
CBI PORTB,5
SBI PORTB,5
DEC R17
BRNE SendByte_loop
RET

;Latches and show
LatchAndShow:
CBI PORTB,4
SBI PORTB,4
NOP
NOP
CBI PORTB,4
RET

;==============================================
; Flash data table
;==============================================

BPM_Table:
; BPM: 60, 70, 80, 90, 100, 110, 120, 130, 140, 150
.DW 62499, 53570, 46874, 41666, 37499, 34090, 31249, 28845, 26785, 24999
; BPM: 160, 170, 180, 190, 200, 210, 220, 230, 240, 250
.DW 23437, 22058, 20832, 19736, 18749, 17856, 17044, 16303, 15624, 14999
; BPM: 260, 270, 280, 290, 300
.DW 14422, 13888, 13392, 12930, 12499

; Timer2 overflow counts for BPM 60,70,...,300.
; Each Timer2 overflow is about 1.024 ms with prescaler /64.
BPM_Tick_Table:
.DB 244, 209, 183, 163, 146, 133, 122, 113, 105, 98
.DB 92, 86, 81, 77, 73, 70, 67, 64, 61, 59
.DB 56, 54, 52, 51, 49

; 5x7 mode indicator characters shown at the right of the screen.
; First 7 bytes = R, next 7 bytes = E.
CharTable:
.DB 0b11110, 0b10001, 0b10001, 0b11110, 0b10100, 0b10010, 0b10001
.DB 0b11111, 0b10000, 0b10000, 0b11110, 0b10000, 0b10000, 0b11111

; OCR1A values for Timer1 CTC sound, prescaler = 8.
; The Timer1 ISR toggles PB1, so f = 16 MHz / (2 * 8 * (OCR1A + 1)).
Note_Table:
; octave 1
.DW 30577, 28861, 27241, 25712, 24269, 22907, 21621, 20407
.DW 19262, 18181, 17160, 16197
; octave 2
.DW 15288, 14430, 13620, 12855, 12134, 11453, 10810, 10203
.DW 9630, 9090, 8579, 8098
; octave 3
.DW 7644, 7214, 6809, 6427, 6067, 5726, 5404, 5101
.DW 4815, 4544, 4289, 4049
; octave 4
.DW 3822, 3607, 3404, 3213, 3033, 2862, 2702, 2550
.DW 2407, 2271, 2144, 2024

; Each table has 32 note indices. Values increase from low to high.
; Octave button 0 adds +12 semitones; A subtracts it again.
Major_Scale_32:
.DB 0,0,2,2,4,5,7,7,9,11,12,12,14,16,17,19
.DB 19,21,23,24,24,26,28,29,31,31,33,35,35,35,35,35

Minor_Scale_32:
.DB 0,0,2,3,3,5,7,7,8,10,12,12,14,15,17,17
.DB 19,20,22,24,24,26,27,29,31,31,32,34,34,34,34,34

Pentatonic_Scale_32:
.DB 0,0,2,2,4,4,7,7,9,9,12,12,14,14,16,16
.DB 19,19,21,21,24,24,26,26,28,28,31,31,33,33,33,33

; End of file
