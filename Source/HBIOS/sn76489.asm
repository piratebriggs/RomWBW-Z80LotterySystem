;======================================================================
;	SN76489 sound driver
;
;	WRITTEN BY: DEAN NETHERTON
;======================================================================
;
; TODO:
;
;======================================================================
; CONSTANTS
;======================================================================
;

SN76489_PORT_LEFT	.EQU	$FC	; PORTS FOR ACCESSING THE SN76489 CHIP (LEFT)
SN76489_PORT_RIGHT	.EQU	$F8	; PORTS FOR ACCESSING THE SN76489 CHIP (RIGHT)
SN7_IDAT		.EQU	0
SN7_TONECNT		.EQU	3	; COUNT NUMBER OF TONE CHANNELS
SN7_NOISECNT		.EQU	1	; COUNT NUMBER OF NOISE CHANNELS
SN7_CHCNT		.EQU	SN7_TONECNT + SN7_NOISECNT
CHANNEL_0_SILENT	.EQU	$9F
CHANNEL_1_SILENT	.EQU	$BF
CHANNEL_2_SILENT	.EQU	$DF
CHANNEL_3_SILENT	.EQU	$FF

SN7CLKDIVIDER	.EQU	4
SN7CLK		.EQU	CPUOSC / SN7CLKDIVIDER
SN7RATIO	.EQU	SN7CLK * 100 / 32

#INCLUDE "audio.inc"

SN76489_INIT:
	LD	IY, SN7_IDAT		; POINTER TO INSTANCE DATA

	LD	DE,STR_MESSAGELT
	CALL	WRITESTR
	LD	A, SN76489_PORT_LEFT
	CALL	PRTHEXBYTE

	LD	DE,STR_MESSAGERT
	CALL	WRITESTR
	LD	A, SN76489_PORT_RIGHT
	CALL	PRTHEXBYTE
;
SN7_INIT1:
	LD	BC, SN7_FNTBL		; BC := FUNCTION TABLE ADDRESS
	LD	DE, SN7_IDAT		; DE := SN7 INSTANCE DATA PTR
	CALL	SND_ADDENT		; ADD ENTRY, A := UNIT ASSIGNED

	CALL	SN7_VOLUME_OFF
	XOR	A			; SIGNAL SUCCESS
	RET

;======================================================================
; SN76489 DRIVER - SOUND ADAPTER (SND) FUNCTIONS
;======================================================================
;

SN7_RESET:
	AUDTRACE(SNT_INIT)
	CALL	SN7_VOLUME_OFF
	XOR	A			; SIGNAL SUCCESS
	RET

SN7_VOLUME_OFF:
	AUDTRACE(SNT_VOLOFF)

	LD	A, CHANNEL_0_SILENT
	OUT	(SN76489_PORT_LEFT), A
	OUT	(SN76489_PORT_RIGHT), A

	LD	A, CHANNEL_1_SILENT
	OUT	(SN76489_PORT_LEFT), A
	OUT	(SN76489_PORT_RIGHT), A

	LD	A, CHANNEL_2_SILENT
	OUT	(SN76489_PORT_LEFT), A
	OUT	(SN76489_PORT_RIGHT), A

	LD	A, CHANNEL_3_SILENT
	OUT	(SN76489_PORT_LEFT), A
	OUT	(SN76489_PORT_RIGHT), A

	RET

; BIT MAPPING
; SET TONE:
; 1 CC 0 PPPP (LOW)
; 0 0 PPPPPP (HIGH)

; 1 CC 1 VVVV

SN7_VOLUME:
	AUDTRACE(SNT_VOL)
	AUDTRACE_L
	AUDTRACE_CR
	LD	A, L
	LD	(SN7_PENDING_VOLUME), A

	XOR	A			; SIGNAL SUCCESS
	RET

SN7_NOTE:
	AUDTRACE(SNT_NOTE)
	AUDTRACE_HL
	AUDTRACE_CR

	LD	B, H
	LD	C, L
	LD	DE, 48

	CALL	_DIV16
					; BC IS OCTAVE COUNT
					; HL is NOTE WITIN ACTAVE
	ADD	HL, HL
	LD	DE, SN7NOTETBL
	ADD	HL, DE

	LD	A, (HL)			; RETRIEVE PERIOD COUNT FROM SN7NOTETBL
	INC	HL
	LD	H, (HL)
	LD	L, A

	INC	C
SN7_NOTE1:
	DEC	C
	JR	Z, SN7_NOTE2
	SRL	H
  	RR	L
	JR	SN7_NOTE1

SN7_NOTE2:
	LD	A, L
	OR	H
	JR	NZ, SN7_PERIOD

	LD	H, $FF
	LD	L, $FF
	JR	SN7_PERIOD

; Divide 16-bit values (with 16-bit result)
; In: Divide BC by divider DE
; Out: BC = result, HL = rest
;
_DIV16:
	LD	HL, 0
	LD	A, B
	LD	B, 8
DIV16_LOOP1:
	RLA
	ADC	HL, HL
	SBC	HL, DE
	JR	NC, DIV16_NOADD1
	ADD	HL, DE
DIV16_NOADD1:
	DJNZ	DIV16_LOOP1
	RLA
	CPL
	LD	B, A
	LD	A, C
	LD	C, B
	LD	B, 8
DIV16_LOOP2:
	RLA
	ADC	HL, HL
	SBC	HL, DE
	JR	NC, DIV16_NOADD2
	ADD	HL, DE
DIV16_NOADD2:
	DJNZ	DIV16_LOOP2
	RLA
	CPL
	LD	B, C
	LD	C, A
	RET

SN7_PERIOD:
	AUDTRACE(SNT_PERIOD)
	AUDTRACE_HL
	AUDTRACE_CR

	; LD	A, H			; IF ZERO - ERROR
	; OR	L
	; JR	Z, SN7_QUERY_PERIOD1

	LD	(SN7_PENDING_PERIOD), HL ;ASSUME SUCCESS

	OR	A			; IF >= 401 ERROR
	LD	DE, $401
	SBC	HL, DE
	JR	NC, SN7_QUERY_PERIOD1

	XOR	A			; SIGNAL SUCCESS
	RET

SN7_QUERY_PERIOD1:			; REQUESTED PERIOD IS LARGER THAN THE SN76489 CAN SUPPORT
	LD	L, $FF
	LD	H, $FF
	LD	(SN7_PENDING_PERIOD), HL

	OR	$FF			; SIGNAL FAILURE
	RET

SN7_PLAY:
	AUDTRACE(SNT_PLAY)
	AUDTRACE_D
	AUDTRACE_CR

	LD	A, (SN7_PENDING_PERIOD + 1)
	CP	$FF
	JR	Z, SN7_PLAY1		; PERIOD IS TOO LARGE, UNABLE TO PLAY
	CALL	SN7_APPLY_VOL
	CALL	SN7_APPLY_PRD

	XOR	A			; SIGNAL SUCCESS
	RET

SN7_PLAY1:				; TURN CHANNEL VOL TO OFF AND STOP PLAYING
	LD	A, (SN7_PENDING_VOLUME)
	PUSH	AF
	LD	A, 0
	LD	(SN7_PENDING_VOLUME), A
	CALL	SN7_APPLY_VOL
	POP	AF
	LD	(SN7_PENDING_VOLUME), A

	OR	$FF			; SIGNAL FAILURE
	RET

SN7_QUERY:
	LD	A, E
	CP	BF_SNDQ_CHCNT
	JR	Z, SN7_QUERY_CHCNT

	CP	BF_SNDQ_PERIOD
	JR	Z, SN7_QUERY_PERIOD

	CP	BF_SNDQ_VOLUME
	JR	Z, SN7_QUERY_VOLUME

	CP	BF_SNDQ_DEV
	JR	Z, SN7_QUERY_DEV

	OR	$FF			; SIGNAL FAILURE
	RET

SN7_QUERY_CHCNT:
	LD	B, SN7_TONECNT
	LD	C, SN7_NOISECNT
	XOR	A
	RET

SN7_QUERY_PERIOD:
	LD	HL, (SN7_PENDING_PERIOD)
	XOR	A
	RET

SN7_QUERY_VOLUME:
	LD	A, (SN7_PENDING_VOLUME)
	LD	L, A
	LD	H, 0

	XOR	A
	RET

SN7_QUERY_DEV:

	LD	B, BF_SND_SN76489
	LD	DE, SN76489_PORT_LEFT 	; E WITH LEFT PORT
	LD	HL, SN76489_PORT_RIGHT	; L WITH RIGHT PORT

	XOR	A
	RET
;
;	UTIL FUNCTIONS
;

SN7_APPLY_VOL:				; APPLY VOLUME TO BOTH LEFT AND RIGHT CHANNELS
	PUSH	BC			; D CONTAINS THE CHANNEL NUMBER
	PUSH	AF
	LD	A, D
	AND	$3
	RLCA
	RLCA
	RLCA
	RLCA
	RLCA
	OR	$90
	LD	B, A

	LD	A, (SN7_PENDING_VOLUME)
	RRCA
	RRCA
	RRCA
	RRCA

	AND	$0F
	LD	C, A
	LD	A, $0F
	SUB	C
	AND	$0F
	OR	B			; A CONTAINS COMMAND TO SET VOLUME FOR CHANNEL

	AUDTRACE(SNT_REGWR)
	AUDTRACE_A
	AUDTRACE_CR

	OUT	(SN76489_PORT_LEFT), A
	OUT	(SN76489_PORT_RIGHT), A

	POP	AF
	POP	BC
	RET

SN7_APPLY_PRD:
	PUSH	DE
	PUSH	BC
	PUSH	AF
	LD	HL, (SN7_PENDING_PERIOD)

	LD	A, D
	AND	$3
	RLCA
	RLCA
	RLCA
	RLCA
	RLCA
	OR	$80
	LD	B, A			; PERIOD COMMAND 1 - CONTAINS CHANNEL ONLY

	LD	A, L			; GET LOWER 4 BITS FOR COMMAND 1
	AND	$F
	OR	B			; A NOW CONATINS FIRST PERIOD COMMAND

	AUDTRACE(SNT_REGWR)
	AUDTRACE_A
	AUDTRACE_CR

	OUT	(SN76489_PORT_LEFT), A
	OUT	(SN76489_PORT_RIGHT), A

	LD	A, L			; RIGHT SHIFT OUT THE LOWER 4 BITS
	RRCA
	RRCA
	RRCA
	RRCA
	AND	$F
	LD	B, A

	LD	A, H
	AND	$3
	RLCA
	RLCA
	RLCA
	RLCA				; AND PLACE IN BITS 5 AND 6
	OR	B			; OR THE TWO SETS OF BITS TO MAKE 2ND PERIOD COMMAND

	AUDTRACE(SNT_REGWR)
	AUDTRACE_A
	AUDTRACE_CR

	OUT	(SN76489_PORT_LEFT), A
	OUT	(SN76489_PORT_RIGHT), A

	POP	AF
	POP	BC
	POP	DE
	RET


SN7_FNTBL:
	.DW	SN7_RESET
	.DW	SN7_VOLUME
	.DW	SN7_PERIOD
	.DW	SN7_NOTE
	.DW	SN7_PLAY
	.DW	SN7_QUERY

#IF (($ - SN7_FNTBL) != (SND_FNCNT * 2))
	.ECHO	"*** INVALID SND FUNCTION TABLE ***\n"
	!!!!!
#ENDIF

SN7_PENDING_PERIOD
	.DW	0		; PENDING PERIOD (10 BITS)
SN7_PENDING_VOLUME
	.DB	0		; PENDING VOL (8 BITS -> DOWNCONVERTED TO 4 BITS AND INVERTED)

STR_MESSAGELT	.DB	"\r\nSN76489: LEFT IO=0x$"
STR_MESSAGERT	.DB	", RIGHT IO=0x$"

#IF AUDIOTRACE
SNT_INIT		.DB	"\r\nSN7_INIT\r\n$"
SNT_VOLOFF		.DB	"\r\nSN7_VOLUME OFF\r\n$"
SNT_VOL			.DB	"\r\nSN7_VOLUME: $"
SNT_NOTE		.DB	"\r\nSN7_NOTE: $"
SNT_PERIOD		.DB	"\r\nSN7_PERIOD: $"
SNT_PLAY		.DB	"\r\nSN7_PLAY CH: $"
SNT_REGWR		.DB	"\r\nOUT SN76489, $"
#ENDIF

; THE FREQUENCY BY QUARTER TONE STARTING AT A0#
; OCATVE 0 - not suported by this driver
; FIRST PLAYABLE NOTE WILL BE $2E - 2 quater tones below a1#
; A1# is $30

SN7NOTETBL:
	.DW	SN7RATIO / 2913
	.DW	SN7RATIO / 2956
	.DW	SN7RATIO / 2999
	.DW	SN7RATIO / 3042
	.DW	SN7RATIO / 3086
	.DW	SN7RATIO / 3131
	.DW	SN7RATIO / 3177
	.DW	SN7RATIO / 3223
	.DW	SN7RATIO / 3270
	.DW	SN7RATIO / 3318
	.DW	SN7RATIO / 3366
	.DW	SN7RATIO / 3415
	.DW	SN7RATIO / 3464
	.DW	SN7RATIO / 3515
	.DW	SN7RATIO / 3566
	.DW	SN7RATIO / 3618
	.DW	SN7RATIO / 3670
	.DW	SN7RATIO / 3724
	.DW	SN7RATIO / 3778
	.DW	SN7RATIO / 3833
	.DW	SN7RATIO / 3889
	.DW	SN7RATIO / 3945
	.DW	SN7RATIO / 4003
	.DW	SN7RATIO / 4061
	.DW	SN7RATIO / 4120
	.DW	SN7RATIO / 4180
	.DW	SN7RATIO / 4241
	.DW	SN7RATIO / 4302
	.DW	SN7RATIO / 4365
	.DW	SN7RATIO / 4428
	.DW	SN7RATIO / 4493
	.DW	SN7RATIO / 4558
	.DW	SN7RATIO / 4624
	.DW	SN7RATIO / 4692
	.DW	SN7RATIO / 4760
	.DW	SN7RATIO / 4829
	.DW	SN7RATIO / 4899
	.DW	SN7RATIO / 4971
	.DW	SN7RATIO / 5043
	.DW	SN7RATIO / 5116
	.DW	SN7RATIO / 5191
	.DW	SN7RATIO / 5266
	.DW	SN7RATIO / 5343
	.DW	SN7RATIO / 5421
	.DW	SN7RATIO / 5499
	.DW	SN7RATIO / 5579
	.DW	SN7RATIO / 5661
	.DW	SN7RATIO / 5743

SIZ_SN7NOTETBL	.EQU	$ - SN7NOTETBL
		.ECHO	"SN76489 approx "
		.ECHO	SIZ_SN7NOTETBL / 2 / 4 /12
		.ECHO	" Octaves.  Last note index supported: "

		.ECHO SIZ_SN7NOTETBL / 2
		.ECHO "\n"
