;==================================================================================================
; DS1216 Smart Watch RAM CLOCK DRIVER
;
;==================================================================================================
;
		.ECHO	"DS1216: ENABLED\n"
;
;-----------------------------------------------------------------------------
; DS1216 INITIALIZATION
;
; CHECKS IF OSCILLATOR IS RUNNING. IF IT ISN'T THE
; CLOCK IS RESTARTED WITH DEFAULT VALUES.
;
; DRIVER WILL NOT BE INSTALLED AS PART OF HBIOS IF
; THERE IS ALREADY AND EXISTING RTC INSTALLED.
;
; 12HR MODE IS CURRENTLY ASSUMED
;
DS1216RTC_INIT:
	CALL	NEWLINE			; Formatting
	PRTS("DS1216: $")		; ANNOUNCE DRIVER
;
	CALL	DS1216_RDC			; READ CLOCK DATA
	LD	HL,DS1216_BUF+4		; IF NOT RUNNING OR
	BIT	5,(HL)			; INVALID, RESTART
	JR	Z,DS1216_CSET		; AND RESET.
	CALL	DS1216_SETC
	CALL	DS1216_RDC			; READ AND DISPLAY
DS1216_CSET:
	CALL	DS1216_DISP		; DATE AND TIME
;
	LD	A,(RTC_DISPACT)		; CHECK RTC DISPATCHER STATUS.
	OR	A			; RETURN NOW IF WE ALREADY HAVE
	RET	NZ			; A PRIMARY RTC INSTALLED.
;
	LD	BC,DS1216_DISPATCH		; SETUP CLOCK HBIOS DISATCHER
	CALL	RTC_SETDISP
;
;	CALL	DS1216_GETTIM
;
	XOR	A			; SIGNAL SUCCESS
	RET
;
;-----------------------------------------------------------------------------
; DS1216 HBIOS DISPATCHER
;
;   A: RESULT (OUT), 0=OK, Z=OK, NZ=ERROR
;   B: FUNCTION (IN)
;
DS1216_DISPATCH:
	LD	A, B				; GET REQUESTED FUNCTION
	AND	$0F				; ISOLATE SUB-FUNCTION
	JP	Z, DS1216_GETTIM			; GET TIME
	DEC	A
	JP	Z, DS1216_SETTIM			; SET TIME 
	DEC	A
	JP	Z, DS1216_GETBYT			; GET NVRAM BYTE VALUE
	DEC	A
	JP	Z, DS1216_SETBYT			; SET NVRAM BYTE VALUE
	DEC	A
	JP	Z, DS1216_GETBLK			; GET NVRAM DATA BLOCK VALUE
	DEC	A
	JP	Z, DS1216_SETBLK			; SET NVRAM DATA BLOCK VALUE 
	DEC	A
	JP	Z, DS1216_GETALM			; GET ALARM
	DEC	A
	JP	Z, DS1216_SETALM			; SET ALARM
	DEC	A
	JP	Z, DS1216_DEVICE			; REPORT RTC DEVICE INFO
	SYSCHKERR(ERR_NOFUNC)
	RET
;
;-----------------------------------------------------------------------------
; DS1216 GET TIME
;
; HL POINTS TO A BUFFER TO STORE THE CURRENT TIME AND DATE IN.
; THE TIME AND DATE INFORMATION MUST BE TRANSLATED TO THE
; HBIOS FORMAT AND COPIED FROM THE HBIOS DRIVER BANK TO
; CALLER INVOKED BANK.
;
; HBIOS FORMAT  = YYMMDDHHMMSS
; DS1216 FORMAT = ..SSMMHH..DDMMYY
;
DS1216_GETTIM:
	PUSH	HL				; SAVE DESTINATION
;
	CALL	DS1216_RDC				; READ THE CLOCK INTO THE BUFFER
;
	; TODO format DS1216_BUF
	LD	HL,DS1216_BUF+2
	LD	DE,DS1216_BUF+4			; TRANSLATE
	LD	B,3				; FORMAT
DS1216_GT0:
	LD	A,(HL)
	LD	(DE),A	
	INC	DE
	LD	A,(DE)
	LD	(HL),A
	DEC	HL
	DJNZ	DS1216_GT0
;
	INC	HL				; POINT TO SECONDS
	POP	DE				; HL POINT TO SOURCE
;						; DE POINT TO DESTINATION
#IF (1)
	PUSH	HL
	PUSH	DE
	EX	DE,HL
	LD	A,6
	CALL	PRTHEXBUF
	POP	DE
	POP	HL
#ENDIF
;	
	LD	A,BID_BIOS			; COPY FROM BIOS BANK
	LD	(HB_SRCBNK),A			; SET IT 
	LD	A, (HB_INVBNK)			; COPY TO CURRENT USER BANK
	LD	(HB_DSTBNK),A			; SET IT
	LD	BC, 6				; LENGTH IS 6 BYTES
#IF (INTMODE == 1)
	DI
#ENDIF
	CALL	HB_BNKCPY			; COPY THE CLOCK DATA
#IF (INTMODE == 1)
	EI
#ENDIF
	XOR	A				; SIGNAL SUCCESS
	RET	
;
;-----------------------------------------------------------------------------
; DS1216 SET TIME
;
;   A: RESULT (OUT), 0=OK, Z=OK, NZ=ERROR
;   HL: DATE/TIME BUFFER (IN)
;
; HBIOS FORMAT  = YYMMDDHHMMSS
; DS1216 FORMAT = ..SSMMHH..DDMMYY
;
DS1216_SETTIM:
	LD	A, (HB_INVBNK)			; COPY FROM CURRENT USER BANK
	LD	(HB_SRCBNK), A			; SET IT
	LD	A, BID_BIOS			; COPY TO BIOS BANK
	LD	(HB_DSTBNK), A			; SET IT
	LD	DE, DS1216_BUF			; DESTINATION ADDRESS
	LD	BC,6				; LENGTH IS 6 BYTES
#IF (INTMODE == 1)
	DI
#ENDIF
	CALL	HB_BNKCPY			; Copy the clock data
#IF (INTMODE == 1)
	EI
#ENDIF
;
	; TODO format DS1216_BUF
	JP DS1216_WRC	
;
; HBIOS FORMAT  = YYMMDDHHMMSS
;                 991122083100
; DS1216 FORMAT = ..SSMMHH..DDMMYY
;                 ..003108..221199
;
;-----------------------------------------------------------------------------
; FUNCTIONS THAT ARE NOT AVAILABLE OR IMPLEMENTED
;
DS1216_GETBYT:
DS1216_SETBYT:
DS1216_GETBLK:
DS1216_SETBLK:
DS1216_SETALM:
DS1216_GETALM:
	SYSCHKERR(ERR_NOTIMPL)
	RET
;-----------------------------------------------------------------------------
; REPORT RTC DEVICE INFO
;
; ONLY ONE CLOCK CAN BE INSTALLED IN HBIOS SO DEVICE NUMBER IS ALWAYS 0.
;
DS1216_DEVICE:
	LD	D,RTCDEV_DS6		; D := DEVICE TYPE
	LD	E,0			; E := PHYSICAL DEVICE NUMBER
	LD	H,0			; H := 0, DRIVER HAS NO MODES
	LD	L,0			; L := BUS ADDRESS
	XOR	A			; SIGNAL SUCCESS
	RET
;
;-----------------------------------------------------------------------------
; DISPLAY CLOCK INFORMATION FROM DATA STORED IN BUFFER
;
DS1216_DISP:
	LD	HL,DS1216_CLKTBL
DS1216_CLP:
	LD	C,(HL)
	INC	HL
	LD	D,(HL)
	CALL	DS1216_BCD
	INC	HL
	LD	A,(HL)
	OR      A
	RET	Z
    CALL	COUT
	INC	HL
	JR	DS1216_CLP
	RET
;
DS1216_CLKTBL:
	.DB	05H, 00111111B, '/'
	.DB	06H, 00011111B, '/'
	.DB	07H, 11111111B, ' '
	.DB	03H, 00111111B, ':'
	.DB	02H, 01111111B, ':'
	.DB	01H, 01111111B, 00H
;
DS1216_BCD:
	PUSH	HL
	LD      HL,DS1216_BUF     	; READ VALUE FROM
	LD      B,0           	; BUFFER, INDEXED BY A 
	ADD     HL,BC
	LD      A,(HL)
	AND     D             	; MASK OFF UNNEEDED
	SRL     A
	SRL     A
	SRL     A
	SRL     A      
	ADD     A,30H
	CALL    COUT
	LD      A,(HL)    
	AND     00001111B
	ADD     A,30H
	CALL    COUT
	POP	HL
	RET
;
DS_LOCATION:	.EQU	$FFA0         	; START OF HBX_BUF (defined in hbios.asm)
DS1216_BUF:		.EQU	$FFA1			; BUFFER FOR TIME, DATE AND CONTROL

; HL = Location to write to
; DE = data to write
; B = length of data
DS1216_WriteData:            
DS1216_OuterWriteLoop:
            LD   A,(DE)         ; Read data value
DS1216_InnerWriteLoop:
            LD   (HL),A         ;Write value (only bit0 matters)
            RRA                 ;Rotate to bit 1
            LD   (HL),A         ;Write value (only bit0 matters)
            RRA                 ;Rotate to bit 2
            LD   (HL),A         ;Write value (only bit0 matters)
            RRA                 ;Rotate to bit 3
            LD   (HL),A         ;Write value (only bit0 matters)
            RRA                 ;Rotate to bit 4
            LD   (HL),A         ;Write value (only bit0 matters)
            RRA                 ;Rotate to bit 5
            LD   (HL),A         ;Write value (only bit0 matters)
            RRA                 ;Rotate to bit 6
            LD   (HL),A         ;Write value (only bit0 matters)
            RRA                 ;Rotate to bit 7
            LD   (HL),A         ;Write value (only bit0 matters)

            INC  DE             ;next byte in pattern
            DJNZ DS1216_OuterWriteLoop
            RET

; HL = Location to read from
; DE = read buffer
; B = length of buffer
DS1216_ReadData:
            LD   C,B            ;Move byte count to C
DS1216_OuterReadLoop:
            LD   A,0            ;clear accumulator
            LD   B,8            ;Read 8 bits
DS1216_InnerReadLoop:
            RRA                 ;Rotate bits right (only need to do this 7 times, not 8!)
            BIT 0, (HL)         ;Read value (only bit0 matters)
            JR  Z,DS1216_BZERO  ;Zero?
            SET 7,A             ;Set bit 7
DS1216_BZERO:
            DJNZ DS1216_InnerReadLoop

            LD  (DE), a         ;Save data byte
            INC DE              ;Next location in read buffer
            DEC C               
            JR NZ,DS1216_OuterReadLoop ;loop until c is zero
            RET

;-----------------------------------------------------------------------------
; RTC READ
;
;
DS1216_RDC:
	LD  HL,DS_LOCATION
	LD  A,(HL)                 ;Start with a RAM Read

	LD	DE,DS1216_PATTERNDATA
	LD  B,DS1216_PATTERNDATAEND-DS1216_PATTERNDATA 
	CALL DS1216_WriteData	; WRITE PATTERN

	LD	DE,DS1216_BUF
	LD  B,8
	CALL DS1216_ReadData	; READ 8 BYTES INTO BUFFER
;
#IF (1)
	LD	A,8
	LD	DE,DS1216_BUF	; DISPLAY DATA READ
	CALL	PRTHEXBUF	; 
	CALL   	NEWLINE
#ENDIF
;
        RET

;-----------------------------------------------------------------------------
; RTC WRITE
;
;
DS1216_WRC:
	LD  HL,DS_LOCATION
	LD  A,(HL)                 ;Start with a RAM Read

	LD	DE,DS1216_PATTERNDATA
	LD  B,DS1216_PATTERNDATAEND-DS1216_PATTERNDATA 
	CALL DS1216_WriteData	; WRITE PATTERN

	LD	DE,DS1216_BUF
	LD  B,8
	CALL DS1216_WriteData	; WRITE 8 BYTES FROM BUFFER
	RET
;
;-----------------------------------------------------------------------------
; SET CLOCK
;
; IF THE CLOCK IS HALTED AS IDENTIFIED BY BIT 5 REGISTER 4, THEN ASSUME THE
; CLOCK HAS NOT BEEN SET AND SO SET THE CLOCK UP WITH A DEFAULT SET OF
; VALUES AS DEFINED IN THE DS1216_CLKDATA TABLE.
;
DS1216_SETC:
	LD  HL,DS_LOCATION
	LD  A,(HL)                 ;Start with a RAM Read

	LD	DE,DS1216_PATTERNDATA
	LD  B,DS1216_PATTERNDATAEND-DS1216_PATTERNDATA 
	CALL DS1216_WriteData

	LD	DE,DS1216_CLKDATA
	LD  B,DS1216_CLKDATAEND-DS1216_CLKDATA 
	CALL DS1216_WriteData
	RET
;
; Start Oscillator and set all registers to inital values
DS1216_CLKDATA:
	.DB  $01   ; 0.1 sec      | 0.01 sec (00-99)
	.DB  $00   ; 10 sec       | seconds = (00-59)
	.DB  $00   ; 10 mins      | mins = (00-59)
	.DB  $00   ; bit 7 = 24 hour mode (0), bits 5,4 = 10 hours | hours (00-23) = 0 
	.DB  $11   ; OSC=0, RST=1 | Day = (1-7)
	.DB  $01   ; 10 date      | date = (01-31)
	.DB  $01   ; 10 month     | month = (01-12)
	.DB  $00   ; 10 year      | year = (00-99)
DS1216_CLKDATAEND:
;
;  SmartWatch Comparison Register Definition 
DS1216_PATTERNDATA:
            .DB  $C5
            .DB  $3A
            .DB  $A3
            .DB  $5C
            .DB  $C5
            .DB  $3A
            .DB  $A3
            .DB  $5C
DS1216_PATTERNDATAEND:
;
;

