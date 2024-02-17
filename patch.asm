; Build params: ------------------------------------------------------------------------------

CHEATS	set 0

; Constants: ---------------------------------------------------------------------------------
	MD_PLUS_OVERLAY_PORT:					equ $0003F7FA
	MD_PLUS_CMD_PORT:						equ $0003F7FE
	MD_PLUS_RESPONSE_PORT:					equ $0003F7FC

	OFFSET_RESET_VECTOR:					equ $4
	OFFSET_AUDIO_COMMAND_HANLDER:			equ $00000A76
	OFFSET_SND_TEST_MUSIC_MAX_COMPARISON:	equ $00000EE8
	OFFSET_SND_TEST_SFX_MIN_COMPARISON:		equ $00000F24
	OFFSET_PROJECTILE_HIT_DETECTION1:		equ	$0000956A
	OFFSET_PROJECTILE_HIT_DETECTION2:		equ	$0000B270

	RESET_VECTOR_ORIGINAL:					equ $00000202

	REGISTER_Z80_BUS_REQUEST:				equ $00A11100

	MUSIC_1:								equ $81	; 1 - LOOP    - Genesis ~Causing~ (Brave Men's Themes)
	MUSIC_2:								equ $82	; 2 - LOOP    - Europe in the Middle Ages ~Receiving~
	MUSIC_3:								equ $83	; 3 - LOOP    - China Before Revolution ~Turning Point~
	MUSIC_4:								equ $84	; 4 - LOOP    - Mega Drive Original Stage ~Present Age~
	MUSIC_5:								equ $85	; 5 - LOOP    - Robot in the Future ~The End~
	MUSIC_6:								equ $86	; 6 - NO LOOP - Le Repos du Guerrier
	MUSIC_7:								equ $87	; 7 - NO LOOP - Door of the Space-Time

	COMMAND_ALL_AUDIO_STOP1:				equ $E0
	COMMAND_ALL_AUDIO_STOP2:				equ $E1
	COMMAND_PAUSE:							equ	$01
	COMMAND_RESUME:							equ	$80
;
; Overrides: ---------------------------------------------------------------------------------

	org OFFSET_RESET_VECTOR
	dc.l DETOUR_RESET_VECTOR

	org OFFSET_SND_TEST_MUSIC_MAX_COMPARISON
	cmpi.w	#$8,$FFFFF002							; When increasing the track number in the sound test, no longer skip over track 7

	org OFFSET_SND_TEST_SFX_MIN_COMPARISON
	move.w	#$7,$FFFFF002							; When reducing the track number in the sound test, no longer skip over track 7

	org OFFSET_AUDIO_COMMAND_HANLDER
	jmp	DETOUR_AUDIO_COMMAND_HANDLER

	if CHEATS
		org OFFSET_PROJECTILE_HIT_DETECTION1
		nop											; Disable hit detection

		org OFFSET_PROJECTILE_HIT_DETECTION2
		nop											; Disable hit detection
	endif

; Detours: -----------------------------------------------------------------------------------

	org $0007F690

DETOUR_AUDIO_COMMAND_HANDLER
	cmpi.b	#COMMAND_ALL_AUDIO_STOP1,D0
	beq		CDDA_PAUSE_LOGIC
	cmpi.b	#COMMAND_ALL_AUDIO_STOP2,D0
	beq		CDDA_PAUSE_LOGIC
	cmpi.b	#COMMAND_PAUSE,D0
	beq		CDDA_PAUSE_LOGIC
	cmpi.b	#COMMAND_RESUME,D0
	beq		CDDA_RESUME_LOGIC
	cmpi.b	#MUSIC_7,D0
	bhi		.is_sfx
	cmpi.b	#MUSIC_1,D0
	bhs		CDDA_PLAY_LOGIC
.is_sfx
	move.b	D0,(A0)									; If none of these branches have been taken, the command plays SFX so push the command to the original audio driver
DETOUR_AUDIO_COMMAND_HANDLER_END
	move.w	#$0,REGISTER_Z80_BUS_REQUEST
	movem.l	(SP)+,D0/A0
	rts

CDDA_PAUSE_LOGIC
	move.b	D0,(A0)									; Push stop command to original audio driver. Necessary to stop SFX
	move.w	#$1300,D0
	jsr		WRITE_MD_PLUS_FUNCTION
	jmp		DETOUR_AUDIO_COMMAND_HANDLER_END

CDDA_RESUME_LOGIC
	move.b	D0,(A0)									; Push resume command to original audio driver.
	move	#$1400,D0
	jsr		WRITE_MD_PLUS_FUNCTION
	jmp		DETOUR_AUDIO_COMMAND_HANDLER_END

CDDA_PLAY_LOGIC
	ori.w	#$1200,D0
	cmpi.b	#MUSIC_5,D0								; Any music higher than MUSIC_5 should not loop so adjust play command to $1100 instead of $1200
	bls		.keep_loop_command
	subi.w	#$0100,D0
.keep_loop_command
	subi.b	#$80,D0									; Indexing for CDDA tracks should start at $01
	jsr		WRITE_MD_PLUS_FUNCTION
	jmp		DETOUR_AUDIO_COMMAND_HANDLER_END
	

DETOUR_RESET_VECTOR
	move.w	#$1300,D0								; Move MD+ stop command into d1
	jsr		WRITE_MD_PLUS_FUNCTION
	incbin	"intro.bin"								; Show MD+ intro screen
	jmp		RESET_VECTOR_ORIGINAL					; Return to game's original entry point

; Helper Functions: --------------------------------------------------------------------------

WRITE_MD_PLUS_FUNCTION:
	move.w  #$CD54,(MD_PLUS_OVERLAY_PORT)			; Open interface
	move.w  D0,(MD_PLUS_CMD_PORT)					; Send command to interface
	move.w  #$0000,(MD_PLUS_OVERLAY_PORT)			; Close interface
	rts