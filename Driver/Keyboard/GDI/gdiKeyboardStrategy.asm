COMMENT @%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

	(c) Copyright Geoworks 1996 -- All Rights Reserved
	GEOWORKS CONFIDENTIAL

PROJECT:	GDI
MODULE:		GDI Keyboard Driver
FILE:		gdiKeyboardStrategy.asm

AUTHOR:		Kenneth Liu, Jun  6, 1996

ROUTINES:
	Name			Description
	----			-----------
	KbdStrategy		Keyboard Strategy routine
	KbdInit			call KbdInitFar
	KbdExit			call KbdExitFar
	KbdSuspend		Unregister callback from Library
	KbdUnsuspend		Re-register callback from Library
	KbdChangeOutput		Change where the driver sends its scancode
	KbdGetState		Get internal state of driver
	KbdSetState		Set internal state of driver
	KbdAddHotkey		Call GDI Library to add hotkey
	KbdDelHotkey		Call GDI Library to delete hotkey
	KbdPassHotkey		Call GDI Library to pass hotkey
	KbdCancelHotkey		Call GDI Library to cancel hotkey
	KbdMapKey		Return all possible characters from
					given key.
	KbdCheckShortcut	See if keypress is a shortcut
	IsCharOnKeyh		See if character can be generated by
					given key.
		
REVISION HISTORY:
	Name		Date		Description
	----		----		-----------
	kliu		6/ 6/96   	Initial revision


DESCRIPTION:
	The strategy routine for the GDI keyboard driver.

	$Id: gdiKeyboardStrategy.asm,v 1.1 97/04/18 11:47:52 newdeal Exp $

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%@

;-----------------------------------------------------------------------------
;		DRIVER INFORMATION
;----------------------------------------------------------------------------

idata	segment

DriverTable     DriverExtendedInfoStruct        <
        <
            KbdStrategy,
                mask DA_HAS_EXTENDED_INFO,
                DRIVER_TYPE_INPUT
        >,
        KbdExtendedInfoSeg              ; Specify resource of extended info
>

ForceRef        DriverTable

idata	ends

KbdExtendedInfoSeg      segment lmem LMEM_TYPE_GENERAL

DriverExtendedInfoTable <
        {},
        length kbdNameTable,
        offset kbdNameTable,
        0
>

kbdNameTable    lptr.char       gdiKbdStr
                lptr.char       0

LocalDefString gdiKbdStr <"GDI Keyboard",0>

KbdExtendedInfoSeg      ends

;---------------------------------------------------------------------------
;		STRATEGY ROUTINE FOR GDI KEYBOARD DRIVER
;---------------------------------------------------------------------------

Resident segment resource


COMMENT @%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		KbdStrategy
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

SYNOPSIS:	Call the correct driver function when passed a legal
		command

CALLED BY:	EXTERNAL

PASS:		di	-> command
RETURN:		see routines
DESTROYED:	nothing

PSEUDO CODE/STRATEGY:
	The command is passed in di. Look up the near pointer to the routine
	that handles that command in a jump table and calls it.

REVISION HISTORY:
	Name	Date		Description
	----	----		-----------
	kliu	6/ 6/96    	Initial version

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%@

idataSegment	word	idata			; for ease of loading

KbdStrategy	proc	far

		uses	ds
		.enter
EC <		cmp	di, KbdFunction
EC <		ERROR_AE	KBD_BAD_ROUTINE
		mov	ds, cs:idataSegment
		cmp	di, MIN_NON_EXCLUSIVE
		jae	notExclusive

		PSem	ds, semKbdStrat
		call	cs:kbdFuncList[di]
		VSem	ds, semKbdStrat
		jmp	done

notExclusive:
		call	cs:kbdFuncList[di]
done:
		.leave
		ret
KbdStrategy	endp

kbdFuncList	label	word

;
; Following require exlusive access:
;
	word	offset Resident:KbdInit			;DR_INIT
	word	offset Resident:KbdExit			;DR_EXIT
	word	offset Resident:KbdSuspend		;DR_SUSPEND
	word	offset Resident:KbdUnsuspend		;DR_UNSUSPEND
	word	offset Resident:KbdGetState		;DR_KBD_GET_STATE
	word	offset Resident:KbdSetState		;DR_KBD_SET_STATE
	word	offset Resident:KbdXlateScan		;DR_KBD_XLATE_SCAN
	word	offset Resident:KbdAddHotkey		;DR_KBD_ADD_HOTKEY
	word	offset Resident:KbdDelHotkey		;DR_KBD_REMOVE_HOTKEY
;
; Following don't require exclusive access:
;
	word	offset Resident:KbdChangeOutput		;DR_KBD_CHANGE_OUTPUT
	word	offset Resident:KbdMapKey		;DR_KBD_MAP_KEY
	word	offset Resident:KbdCheckShortcut	;DR_KBD_CHECK_SHORTCUT
	word	offset Resident:KbdPassHotkey		;DR_KBD_PASS_HOTKEY
	word	offset Resident:KbdCancelHotkey		;DR_KBD_CANCEL_HOTKEY


COMMENT @%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		KbdInit
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

SYNOPSIS:	Initialize driver the 1st time it's loaded

CALLED BY:	Strategy Routine

PASS:		nothing
RETURN:		carry set if error
DESTROYED:	nothing

PSEUDO CODE/STRATEGY:
		call KbdInitFar
	
REVISION HISTORY:
	Name	Date		Description
	----	----		-----------
	kliu	6/ 6/96    	Initial version

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%@
KbdInit	proc	near
		.enter
		call	KbdInitFar
		.leave
		ret
KbdInit	endp


COMMENT @%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
			KbdExit
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

SYNOPSIS:	Exit driver

CALLED BY:	Strategy Routine

PASS:		nothing
RETURN:		carry set if error
DESTROYED:	(allowed) ax, bx, cx, dx, si, di, ds, es
SIDE EFFECTS:	

PSEUDO CODE/STRATEGY:
		call KbdExitFar

REVISION HISTORY:
	Name	Date		Description
	----	----		-----------
	kliu	6/ 6/96    	Initial version

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%@
KbdExit	proc	near
		.enter
		call	KbdExitFar
		.leave
		ret
KbdExit	endp


COMMENT @%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		KbdSuspend
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

SYNOPSIS:	Prepare device for being task-switched

CALLED BY:	Strategy Routine
       
PASS:		nothing	
RETURN:		carry set if error
DESTROYED:	nothing


PSEUDO CODE/STRATEGY:
		Unregister callback.

REVISION HISTORY:
	Name	Date		Description
	----	----		-----------
	kliu	6/ 6/96    	Initial version

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%@
KbdSuspend	proc	near

		uses	dx, si, ax
		.enter
		
		mov	dx, segment Resident
		mov	si, offset Resident:KbdCallback
		call	GDIKeyboardUnregister
EC <		cmp	ax, EC_NO_ERROR
EC <		ERROR_NE KBD_UNREGISTER_CALLBACK_ERROR
		
		clc
		.leave
		ret

KbdSuspend	endp


COMMENT @%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		KbdUnsuspend
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

SYNOPSIS:	Return from task switching

CALLED BY:	Strategy Routine
PASS:		nothing
RETURN:		carry set if error
DESTROYED:	nothing

PSEUDO CODE/STRATEGY:
		Re-register the callback routine.		

REVISION HISTORY:
	Name	Date		Description
	----	----		-----------
	kliu	6/ 7/96    	Initial version

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%@
KbdUnsuspend	proc	near
		uses	dx, si, ax
		.enter

		mov	dx, segment Resident
		mov	si, offset Resident:KbdCallback
		call	GDIKeyboardRegister
EC <		cmp	ax, EC_NO_ERROR
EC <		ERROR_NE KBD_REGISTER_CALLBACK_ERROR

		clc
		.leave
		ret
KbdUnsuspend	endp


COMMENT @%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		KbdChangeOutput
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

SYNOPSIS:	Change where the keyboard driver send its scan-code
		events

CALLED BY:	DR_KBD_CHANGE_OUTPUT
PASS:		bx	-> new output handle
		ds	-> dgroup
RETURN:		bx	<- old output handle
		carry set if error
DESTROYED:	nothing

PSEUDO CODE/STRATEGY:

REVISION HISTORY:
	Name	Date		Description
	----	----		-----------
	kliu	5/24/96    	Initial version

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%@
KbdChangeOutput	proc	near
		.enter
		
		xchg	ds:[kbdOutputProcHandle], bx
		clc
		
		.leave
		ret
KbdChangeOutput	endp


COMMENT @%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		KbdGetState
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

SYNOPSIS:	Returns assorted info about current keyboard state

CALLED BY:	EXTERNAL: DR_KBD_GET_KBD_STATE
PASS:		nothing
RETURN:		al	<- current ShiftState
		ah	<- current ToggleState
		bx	<- current process handle receiving MSG_KBD_SCAN
		cl	<- current XState1
		ch	<- current XState2
		dl	<- current ModeIndState (not supported here,
						 return KbdToggleState)
		dh	<- current kbdTypematicState	(originally used for
						 typematic rate, not
						 supported here yet)

		es:si	<- pointer to current DownList element
			   (or es = 0 if no last element)
		carry set if error
DESTROYED:	nothing
SIDE EFFECTS:	

PSEUDO CODE/STRATEGY:
		

REVISION HISTORY:
	Name	Date		Description
	----	----		-----------
	kliu	5/24/96    	Initial version

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%@
KbdGetState	proc	near

		.enter
		
		mov	al, ds:[kbdShiftState]
		mov	ah, ds:[kbdToggleState]
		mov	bx, ds:[kbdOutputProcHandle]
		mov	cl, ds:[kbdXState1]
		mov	ch, ds:[kbdXState2]
		mov	dl, ah			; just return toggle
		mov	dh, ds:[kbdTypematicState]
		les	si, ds:kbdCurDownElement

		clc
		.leave
		ret
KbdGetState	endp


COMMENT @%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		KbdSetState
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

SYNOPSIS:	Sets internal variable so that driver knows where to
		send output events

CALLED BY:	Strategy Routine - DR_KBD_SET_STATE
PASS:		ds	-> dgroup
		ah	-> Flags for which Kbd state items to set:
			   Bit 7 set for new process handle
			   Bit 6 set for new modIndState (not supported anymore)
			   Bit 5 set for new typematic rates & delay
							 (not supported anymore)

		bx	-> handle of process to send output to.
		ch	-> new typematic rate & delay

RETURN:		carry clear if no error
DESTROYED:	nothing
SIDE EFFECTS:	

PSEUDO CODE/STRATEGY:

REVISION HISTORY:
	Name	Date		Description
	----	----		-----------
	kliu	7/22/96    	Initial version

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%@
KbdSetState	proc	near
		uses	ax
		.enter

	;
	;	ModeIndState and Typematic rate is not supported here
	;
		shl	ah, 1				; bit 7 into carry
		jnc	KSS_10

		mov	ds:[kbdOutputProcHandle], bx
KSS_10:
		shl	ah, 1				; bit 6 into carry
		jnc	KSS_20
	;
	;	We are not doing anything for this either, handle later!
	;
KSS_20:
		shl	ah, 1
		jnc	KSS_30

	;
	;	We are now only setting this variable, nothing else
	;	has been done.
	;
		mov	ds:[kbdTypematicState], ch

KSS_30:
		clc					; indicate no error
		.leave
		ret
KbdSetState	endp


COMMENT @%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		KbdAddHotkey
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

SYNOPSIS:	Add a hotkey to be watched for.

CALLED BY:	Strategy routine: DR_KBD_ADD_HOTKEY
PASS:		ah	-> ShiftState
		cx	-> character (ch = CharacterSet, cl =
			Chars/VChars)
		^lbx:si	-> objec to notify when the key is pressed
		bp	-> message to send it
RETURN:		carry set if error
DESTROYED:	nothing
SIDE EFFECTS:	

PSEUDO CODE/STRATEGY:
		

REVISION HISTORY:
	Name	Date		Description
	----	----		-----------
	kliu	7/22/96    	Initial version

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%@
KbdAddHotkey	proc	near
		.enter
		call	GDIKeyboardAddHotkey
		.leave
		ret
KbdAddHotkey	endp


COMMENT @%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		KbdDelHotkey
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

SYNOPSIS:	Remove a hotkey being watched for.

CALLED BY:	Strategy routine: DR_KBD_REMOVE_HOTKEY
PASS:		ah	-> ShiftState
		cx	-> character (ch = characterSet, cl =
				Chars/VChars)
RETURN:		carry set if error
DESTROYED:	nothing
SIDE EFFECTS:	

PSEUDO CODE/STRATEGY:

REVISION HISTORY:
	Name	Date		Description
	----	----		-----------
	kliu	7/22/96    	Initial version

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%@
KbdDelHotkey	proc	near
		.enter
		call	GDIKeyboardDelHotkey
		.leave
		ret
KbdDelHotkey	endp


COMMENT @%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		KbdPassHotkey
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

SYNOPSIS:	Pass control to the previous keyboard-interrupt handler

CALLED BY:	Strategy routine: DR_KBD_PASS_HOTKEY
PASS:		nothing
RETURN:		carry set if error
DESTROYED:	nothing
SIDE EFFECTS:	

PSEUDO CODE/STRATEGY:
		

REVISION HISTORY:
	Name	Date		Description
	----	----		-----------
	kliu	7/22/96    	Initial version

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%@
KbdPassHotkey	proc	near
		.enter
		call	GDIKeyboardPassHotkey
		.leave
		ret
KbdPassHotkey	endp


COMMENT @%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		KbdCancelHotkey
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

SYNOPSIS:	We have decided not to hand off the keypress after
		all, so re-enable the keyboard interface.

CALLED BY:	Strategy routine: DR_KBD_CANCEL_HOTKEY
PASS:		nothing
RETURN:		carry set if error
DESTROYED:	nothing
SIDE EFFECTS:	

PSEUDO CODE/STRATEGY:
		

REVISION HISTORY:
	Name	Date		Description
	----	----		-----------
	kliu	7/22/96    	Initial version

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%@
KbdCancelHotkey	proc	near
		.enter
		call	GDIKeyboardCancelHotkey
		.leave
		ret
KbdCancelHotkey	endp


COMMENT @%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		KbdMapKey
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

SYNOPSIS:	Return all possible characters from given key.

CALLED BY:	KbdStrategy - DR_KBD_MAP_KEY

PASS:		es:si	-> ptr to KeyMapStruct to fill in
		al	-> scan code of key to map
		ds	-> dgroup 

RETURN:		es:si	<- KeyMapStruct filled in
DESTROYED:	nothing

PSEUDO CODE/STRATEGY:
		

REVISION HISTORY:
	Name	Date		Description
	----	----		-----------
	kliu	6/10/96    	Initial version

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%@
KbdMapKey	proc	near

		uses	ax, cx, di, si
		.enter

		mov	di, si			; di -> ptr to return buffer
		push	ax, di
		clr	al
		mov	cx, size KeyMapStruct
		rep	stosb
		pop	ax, di
		dec	al
		clr	ah

		push	ds			; save dgroup
		movdw	dssi, ds:[kbdKeyTableListPtr]
		movdw	dssi, ds:[si].KTL_keyDefs	; ds:si -> ptr
							; to keyDef table
if DBCS_PCGEOS
		CheckHack <(size KeyDef) eq 8>
		shl	ax, 1
else
		CheckHack <(size KeyDef) eq 4>
endif
		shl	ax, 1
		shl	ax, 1
		add	si, ax			; ds:si pointing to
						; right slot.
if DBCS_PCGEOS
		mov	ax, ds:[si].KD_char
		mov	es:[di].KMS_char, ax
		mov	ax, ds:[si].KD_shiftChar
		mov	es:[di].KMS_shift, ax
else
		mov	al, ds:[si].KD_char
		mov	es:[di].KMS_char, al
		mov	al, ds:[si].KD_shiftChar
		mov	es:[di].KMS_shift, al
endif
		mov	al, ds:[si].KD_keyType
		mov	es:[di].KMS_keyType, al
		test	al, KD_EXTENDED
		jz	notExtended
		mov	al, ds:[si].KD_extEntry
		clr	ah

		pop	ds
		movdw	dssi, ds:[kbdKeyTableListPtr]
		movdw	dssi, ds:[si].KTL_keyExts	
		
if DBCS_PCGEOS
		CheckHack <(size ExtendedDef) eq 16>
		shl	ax, 1
else
		CheckHack <(size ExtendedDef) eq 8>
endif
		shl	ax, 1
		shl	ax, 1
		shl	ax, 1
		add	si, ax			; ds:si -> ptr to correct slot
SBCS <		mov	al, ds:[si].EDD_charSysFlags
SBCS <		ornf	es:[di].KMS_virtual, al

		push	di
		lea	si, ds:[si].EDD_ctrlChar	; source
		add	di, offset KMS_ctrl		; dest.
		mov	cx, NUM_EXTENDED_CHARS
SBCS <		rep	movsb
DBCS <		rep	movsw
		pop	di

notExtended:
		pop	ds
	
if DBCS_PCGEOS
	;
	;	 KMS_virtual not needed for DBCS
	;
else
		mov	al, es:[di].KMS_keyType
		and	al, KD_TYPE
		cmp	al, KEY_ALPHA
		je	notVirtual
		cmp	al, KEY_NONALPHA
		je	notVirtual
		ornf	es:[di].KMS_virtual, EV_KEY or EV_SHIFT

notVirtual:
endif
		.leave
		ret

KbdMapKey endp


COMMENT @%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		KbdCheckShortcut
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

SYNOPSIS:	See if a keypress is a shortcut.
CALLED BY:	KbdStrategy - DR_KBD_CHECK_SHORTCUT

PASS:		same as MSG_META_KBD_CHAR:
			cl	-> Character		(Chars or VChar)
			ch	-> CharacterSet	(CS_BSW or CS_CONTROL)
			dl	-> CharFlags
			dh	-> ShiftState		(left from conversion)
			bp low	-> ToggleState
			bp high -> scan code
		ax	-> number of entries in table
		es:si	-> ptr to shortcut table (KeyboardShortcut)
		(ds - idata)

RETURN:		si	<- index of shortcut
		carry set if a shortcut
DESTROYED:	none

PSEUDO CODE/STRATEGY:
	Assumes: size(KeyboardShortcut) = 2
	Assumes: high 4 bits of CharacterSet can be ignored
	Assumes: physical bit = 0 means match character
	Assumes: low bit of ShiftState is unused
	foreach KeyboardShortcut {
	    if (physical key) {
		if (shortcut char == key[scancode w/modifiers]) {
		    if (shortcut mods == (necessary keys+ShiftState) {
			return(index);
		    }
		}
	    } else {
		if (shortcut char == Character) {
		    if (ShiftState == shortcut modifiers)
			return(index);
		}
	    }
	}
REGISTER USAGE:
	constant:
		ds = seg addr of shortcut table
		es = seg addr of keyboard map (idata)
		di:12-15 = left over modifiers
		di:8-11  = CharacterSet
		di:0-7   = Character
		dh = scan code of char
		bl:4-6 = implied modifiers from key + left over modifiers
		bp:0-7 = CharFlags (passed dl)
		bp:8-15 = ShiftState (passed dh)
	in the loop:
		ax = current shortcut (KeyboardShortcut)
		si = offset of current shortcut
		cx = # of shortcuts left to check
		dl = implied modifiers from shortcut character
		bh = key type of modifier

KNOWN BUGS/SIDE EFFECTS/IDEAS:
REVISION HISTORY:
	Name	Date		Description
	----	----		-----------
	eca	2/16/90		Initial version
	kliu	6/1/96		Borrow code for GDI Keyboard Driver

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%@

CheckHack <(size KeyboardShortcut) eq (size word)>

CheckHack <(mask CharFlags and 40h) eq 0>

KCS_NUMLOCK_FLAG	equ 	40h

KbdCheckShortcut	proc	near

	uses	ax, bx, cx, dx, bp, di, ds, es

SBCS <		cmp	ch, CS_UI_FUNCS			; UI function?		>
SBCS <		clc					; carry -> not a shortcut >
SBCS <		je	exit				; exit if UI function	>

	.enter

		push	si
 		xchg	ax, cx				; cx -> # of entries

if DBCS_PCGEOS
		
		cmp	ah, CS_CONTROL_HB		; control key?
		je	isCtrlKey			; branch if control key
		andnf	ax, mask KS_CHAR		; ignore 4 high bits
		test	ax, not (mask KS_CHAR)		; potential shortcut?
		jnz	noMatch				; branch if not

afterCtrlKey:
else
		and	ah, (KSS_CHAR_SET shr 8)	; ignore 4 high bits of ah
endif

		push	ds
		segmov	ds, es, bx			; ds -> seg addr of table
		pop	es				; es -> seg addr of idata

	;
	;	load up bx with important info
	;
		mov	bx, bp				; bl -> ToggleState
		xchg	bh, dh				; bh -> shifstate
							; dh -> scan code

	;
	;	OR in the modifier keys that were left over
	;
		ornf	ah, (mask KMS_SHIFT or mask KMS_CTRL or mask KMS_ALT) shl 4

	;
	;	See if shift left over
	;
		test	bx, (SHIFT_KEYS shl 8) or TOGGLE_SHIFTSTICK 
		jnz	shift
		andnf	ah, not (mask KMS_SHIFT shl 4)	; mark as not SHIFT'd
shift:
	;
	;	See if ctrl left over
	;
		test	bx, (CTRL_KEYS shl 8) or TOGGLE_CTRLSTICK
		jnz	ctrl
		andnf	ah, not (mask KMS_CTRL shl 4)	; mark as not CTRL'd
ctrl:
		test	bx, (ALT_KEYS shl 8) or TOGGLE_ALTSTICK
		jnz	alt
		andnf	ah, not (mask KMS_ALT shl 4)	; mark as not ALT'd
alt:
	;
	;	Find out the implied modifier keys for this keypress
	;
		xchg	bh, dh				; bh -> scan code
							; dh -> shiftstate
		mov	bp, dx				; bp -> ShiftState, CharFlags
		mov	dh, bh				; dh -> scan code
		call	IsCharOnKey			; find any other modifiers

	;
	;	If the <CapsLock> key was down, toggle the shift state
	;	if the key was of the right type.
	;
		test	bl, TOGGLE_CAPSLOCK
		jnz	checkCapslock			; branch if <CapsLock> down
afterCapslock:
	;
	;	 If the <NumLock> key was down, note the fact in bp
	;
		test	bl, TOGGLE_NUMLOCK
		jnz	checkNumlock			; branch if <NumLock> down

afterNumlock:
		ornf	ah, dl				; ah -> implied + leftover mods
		mov	di, ax				; di -> character value
		mov	bl, ah				; bl -> implied + leftover

shortcutLoop:
		lodsw					; ax -> shortcut

if DBCS_PCGEOS
		PrintMessage <remove temporary check in KbdCheckShortcut>
		push	ax
		andnf	ax, mask KS_CHAR
		cmp	ax, ' '
		ERROR_B	KBD_BAD_SHORTCUT
		pop	ax
endif
		test	ax, KSS_PHYSICAL		; see if matching key or char
		jnz	physicalKey			; branch if matching key
		cmp	ax, di				; see if char, modifiers match
		je	match				; a match!
nextShortcut:
		loop	shortcutLoop			; branch while more

DBCS <noMatch:								>
		pop	ax				; clean up stack
		clc					; carry clear
							; indicate not
							; a shortcut
		jmp	done
match:
		pop	ax				; ax -> offset of table start
		sub	si, ax				; get offset from start
		sub	si, (size KeyboardShortcut)	; back up one entry
		stc					; carry set indicate a shortcut
done:
		.leave
SBCS <exit:								>
		ret

if DBCS_PCGEOS
	;
	;	For DBCS, we special-case control characters because the
	;	allotted values for them do not fit in the scheme for
	;	shortcuts of having values < 0x1000 (which is so we can
	;	fit them in 12 bits).
	;
isCtrlKey:
		mov	ah, CS_CONTROL_HB and 0x0f
		jmp	afterCtrlKey
endif

checkCapslock:
		andnf	bh, KD_TYPE			; bh -> KeyTypeFlag
		cmp	bh, KEY_ALPHA
		jne	afterCapslock			; branch if not alphabetic
		xornf	dl, (mask KMS_SHIFT shl 4)	; toggle shift state
		jmp	afterCapslock

checkNumlock:
		ornf	bp, KCS_NUMLOCK_FLAG		; bp -> mark <NumLock> as down
		jmp	afterNumlock

physicalKey:
	;
	;	The shortcut says to match keys, not characters. See if the
	;	shortcut character is even on the key.
	;
		call	IsCharOnKey			; see if shortcut on key
		jnc	nextShortcut			; nope, try next entry

	;
	;	The character can be generated by that key. Take the implied
	;	modifiers (dl) plus the modifiers listed for the shortcut (ah),
	;	and see if those match the modifiers for the keypress
	;	plus any implied modifiers for it (bl)
	;
		and	ah, not (KSS_PHYSICAL shr 8)	; ignore physical flag
		or	dl, ah				; dl -> listed + implied mods
		cmp	dl, bl				; see if modifiers match
		jne	nextShortcut			; branch if no match
	;
	;	The modifiers matched.  We now do some extra checking if the
	;	key is part of the numeric keypad, where things are strange:
	;	- keys are overloaded (eg. <Home>/<7>
	;	- keys are sometimes redundant (eg. <Home>, <Home>/<7>)
	;	- there is a special state key (ie. <NumLock>)
	;
	;	 bp:0-7 = CharFlags for press
	;	 bp:8-15 = ShiftState for press
	;	 bh = KeyDataFlags for key being checked
	;
	;	If the key in question is not of type KEY_PAD, it isn't affected
	;	 by the <NumLock> key, so no further checking needs to be done
	;
		andnf	bh, KD_TYPE			; bh -> KeyTypeFlag
		cmp	bh, KEY_PAD			; on numeric keypad?
		jne	match				; match if not
	;
	;	If the keypress is from one of the extended keys, it isn't affected
	;	by the <NumLock> key, so no further checking needs to be done.
	;
		test	bp, mask CF_EXTENDED		; extended key?
		jnz	match				; match if so
	;
	;	The key is on the numeric keypad.  Make sure there aren't any
	;	 modifiers down -- if so, no further checking needs to be done.
	;
		test	bp, (CTRL_KEYS or ALT_KEYS or SHIFT_KEYS) shl 8
		jnz	match				; match if so
	;
	;	Finally, see if the <NumLock> key was down.  If not, then this
	;	was a match
	;
		test	bp, KCS_NUMLOCK_FLAG
		jz	match				; branch if no <NumLock>
	;
	;	After narrowing down all the above conditions, we know that:
	;	- the key is on the numeric keypad
	;	- the key is unmodified
	;	- the <NumLock> key is down
	;	 An example of this is pressing the <Home>/<7> key when the
	;	 <NumLock> key is down.  In this case the press means <7>, so
	;	 it shouldn't match something with <Shift><Home> as a shortcut.
	;
		jmp	nextShortcut

KbdCheckShortcut	endp


COMMENT @%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		IsCharOnKey
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

SYNOPSIS:	See if character can be generated by given key.
CALLED BY:	INTERNAL: KbdCheckShortcut

PASS:		al - character to check (Chars or VChar)
		ah:0-3 - character set (low 4 bits of CharacterSet)
		dh - scan code of key to check
		es - seg addr of idata
RETURN:		if carry set:
		    character can be generated by key
		    dl:4-6 - modifiers used to generate char (KeyModifiers)
		    dl:0-2 - modifiers used to generate char (KeyModifiers)
		    bh - key type (KeyDataFlags)
DESTROYED:	none

PSEUDO CODE/STRATEGY:
		assumes: size(KeyDef) = 4
		assumes: size(ExtendedDef) = 8
		Does goofy stuff with the modifiers; shift is bit 0, ctrl is
		bit 1, and alt is bit 2, so the corresponding bits OR'd
		together will give an index of the corresponding character
		in the extended entry, if any. Two copies of those bits are
		kept, one in bits 0-2, and one in bits 4-6 to return w/o shifting.
KNOWN BUGS/SIDE EFFECTS/IDEAS:
		Uses es for the seg addr of idata because that's convienent
		for KbdCheckShortcut, which calls this (potentially) for
		each shortcut in its table. Returns 2 copies of the modifier
		bits for the same reason.
REVISION HISTORY:
		Name	Date		Description
		----	----		-----------
		eca	2/ 8/90		Initial version
		kliu	6/ 1/96		Borrow code for GDI Keyboard Driver

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%@

IsCharOnKey	proc	near
		
		uses	ax, cx, di, ds, si
		.enter

SBCS <		and	ah, (KSS_CHAR_SET shr 8)	; ignore high 4 bits>
DBCS <		andnf	ax, mask KS_CHAR		; ignore high 4 bits>
DBCS <		cmp	ah, CS_CONTROL_HB and 0xf	; control key?		>
DBCS <		je	isCtrlKey			; branch if control key	>

DBCS < afterCtrlCheck:							>
		mov	cl, dh
		mov	di, cx
		and	di, 0x00ff			; di -> index of KeyDef
		dec	di				; scan codes start at 1
if DBCS_PCGEOS
		CheckHack <(size KeyDef) eq 8>
		shl	di, 1
else
		CheckHack <(size KeyDef) eq 4>
endif
		shl	di, 1
		shl	di, 1				; *4 for each KeyDef
		clr	dl				; dl -> no modifiers

		movdw	dssi, es:[kbdKeyTableListPtr]
		movdw	dssi, ds:[si].KTL_keyDefs	; ds:si = keyDefs
		add	si, di				; ds:si -> entry in
							; keyDefs
			
		mov	bh, ds:[si].KD_keyType
SBCS <		cmp	ds:[si].KD_char, al		; see if unshifted >
DBCS <		cmp	ds:[si].KD_char, ax		; see if unshifted >
		je	checkChar			; branch if match
SBCS <		cmp	ds:[si].KD_shiftChar, al	; see if shifted >
DBCS <		cmp	ds:[si].KD_shiftChar, ax	; see if shifted >
		je	checkShiftChar			; branch if match
		test	bh, KD_EXTENDED			; see if extended
		jz	noMatch				; if not extended, we're done

		mov	di, {word}ds:[si].KD_extEntry
		and	di, 0x00ff			; di -> index of extended entry
if DBCS_PCGEOS
		CheckHack <(size ExtendedDef) eq 16>
		shl	di, 1
else
		CheckHack <(size ExtendedDef) eq 8>
endif
		shl	di, 1
		shl	di, 1
		shl	di, 1				; *8 for each ExtendedDef
		ornf	dl, (mask KMS_CTRL) or \
		    (mask KMS_CTRL shl 4)		; dl -> at least <ctrl> used

		mov	cx, NUM_EXTENDED_CHARS		; cx -> # of entries
		movdw	dssi, es:[kbdKeyTableListPtr]
		movdw	dssi, ds:[si].KTL_keyExts	
		add	si, di				; ds:si = entry in ExtTable
		push	si			
		
		lea	si, ds:[si].EDD_ctrlChar
extLoop:

SBCS <	 	cmp	ds:[si], al		>
DBCS <	 	cmp	ds:[si], ax		>
		je	checkExtChar			; branch if a match
		inc	si				; advance to next char
DBCS <		inc	si			
		add	dl, 00010001b			; add next modifiers
		loop	extLoop				; check next entry
		pop	si
		jmp	noMatch				; if through loop, no match

	;
	;	 Matches standard char, make sure it's of the right type
	;
checkShiftChar:
		ornf	dl, (mask KMS_SHIFT) or \
		    (mask KMS_SHIFT shl 4)		; dl -> <shift> was used
checkChar:
if DBCS_PCGEOS
		jmp	foundChar
else
		mov	cl, bh				; cl -> key type
		andnf	cl, KD_TYPE			; keep only type bits
		cmp	ah, (CS_BSW and mask KS_CHAR_SET) ; looking for printable?
		jne	charIsVirtual			; no, do other checks
	
		cmp	cl, KEY_ALPHA			; see if alphabetic
		je	foundChar
		cmp	cl, KEY_NONALPHA		; see if other printable char
		je	foundChar
		jmp	noMatch				; not printable, no match
		
charIsVirtual:
		cmp	cl, KEY_MISC			; see if miscellaneous
		je	foundChar			; yes, it's virtual
		cmp	cl, KEY_ALPHA			; see if alphabetic
		je	noMatch				; yes, not virtual
		cmp	cl, KEY_NONALPHA		; see if other printable char
		je	noMatch				; yes, not virtual
		jmp	foundChar			; else it's virtual & a match
endif

	;
	;	Matches extended char, make sure it's of the right type
	;
checkExtChar:
if DBCS_PCGEOS
		pop	si
else
		mov	di, dx				; dl == modifiers used
		and	di, 0x000f			; si -> index of char
		mov	al, es:bitTable[di]		; al -> corresponding bit
		pop	si				; di -> offset of ext entry
		test	ds:[si].EDD_charSysFlags, al
		jnz	extIsVirtual			; branch if entry virtual
		cmp	ah, (CS_BSW and mask KS_CHAR_SET) ; looking for virtual?
		jne	noMatch				; yes, then didn't match
		jmp	foundChar			; no, we found a match

extIsVirtual:
		cmp	ah, (CS_BSW and mask KS_CHAR_SET) ; looking for virtual?
		je	noMatch				; no, then didn't match
endif

foundChar:
		andnf	dl, 0xf0			; keep only bits 4-7
		stc					; indicate match found
done:
	.leave
	ret

DBCS <isCtrlKey:							>
DBCS <		mov	ah, CS_CONTROL_HB					>
DBCS <		jmp	afterCtrlCheck						>

noMatch:
		clc					; indicate no match found
		jmp	done

IsCharOnKey	endp

Resident	ends
















