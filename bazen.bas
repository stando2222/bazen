
#picaxe 20M2
; Regulacia bazenu
; version 0.13
; date 3.1.2019
; partial step 2 to general refaktoring - main loop every 1 sec - vStatus and all flow due to vMode
; ---------------------

;#define use_test
;#define debug_display
#define simulate_inputs

; ---------- symbols ---------------
; misc
symbol displaySpeed = N2400

; input pins
symbol iTin 	= C.0
symbol iTout	= C.1
symbol iSw0		= C.2
symbol iSw1		= C.3
symbol iSw2		= C.4
symbol iSw3		= C.5

; output pins
symbol oDisplay	= B.0
symbol oSerSolOff	= B.1
symbol oSerSolOn  = B.2
symbol oPump	= B.3
symbol oUVLamp	= B.4


symbol hi2csda	= B.5
symbol hi2cscl	= B.7

; ---------------- variables -------------------
symbol vMode	= b10
symbol vStatus	= b11
symbol vLastMin	= b12
symbol vTin		= b13
symbol vTout	= b14
symbol vLastSolar = b15
symbol vTmin	= b16
symbol vTmax	= b17
symbol vWaitHour	= b18
symbol vSubMode   = b19
symbol vWaitMin	= b20
;b21

symbol vRemainigPumpTime	= w11			; in minutes
symbol vDayPumpTime		= w12
;w13

; temporary - !!!! max b9
symbol seconds	= b0
symbol mins		= b1
symbol hour		= b2
symbol day		= b3
symbol date		= b4
symbol month	= b5
symbol year		= b6

symbol val1		= b7
symbol val2		= b8

; default values
symbol DefaTmin			= 25
symbol DefaTmax			= 29
symbol DefaPumpTime		= 600			; in minutes

symbol TimeSolarServo		= 1

; mode symbols
symbol ModeHeat	= 1
symbol ModeCool	= 2
symbol ModeKeep	= 3
symbol ModeWait	= 4
symbol ModeTest	= 5
symbol ModeEndDay = 6
symbol PumpMask	= %00000001
symbol UVMask	= %00000010
symbol TestMask	= %00000100
symbol SolarMask	= %00001000
symbol ServoToOn  = %00010000
symbol ServoToOff = %00100000
symbol NPumpMask	= %11111110
symbol NUVMask	= %11111101
symbol NTestMask	= %11111011
symbol NSolarMask = %11110111
symbol NServoToOn = %11101111
symbol NServoToOff= %11011111


; submode symbols
symbol SModePumpONOFF	= 1
symbol SModePumpOFFON	= 2

; ---------------------	
; temporary init
; ---------------------
	vTmin = DefaTmin
	vTmax = DefaTmax


; ---------------------
; initialization
; ---------------------
	output oPump
	high oPump
	output oSerSolOn
	high oSerSolOn
	output oSerSolOff
	high oSerSolOff
	output oUVLamp
	high oUVLamp
	output oDisplay
		
	pullup %11110000000000	;nastavenie pullup rezistorov pre vstupy switchov

	
	gosub init_rtc
	
	gosub start_init_new_day

#ifdef use_test
	gosub test_routine
#endif

; main loop
main_loop:
	gosub read_rtc
	
	gosub display_info
		
	
	; waiting for new minute
	if mins = vLastMin then
	{  
	   pause 1000
	   goto main_loop
	}
	endif
	
	gosub read_temperatures

	; handling pending servo
	val1 = vStatus & ServoToOn 
	if val1 > 0 then
		dec vWaitMin
		if vWaitMin > 0 then main_loop
		vStatus = vStatus | SolarMask
		vStatus = vStatus & NServoToOn
		high oSerSolOn 
	endif

	val1 = vStatus & ServoToOFF 
	if val1 > 0 then
		dec vWaitMin
		if vWaitMin > 0 then main_loop
		vStatus = vStatus & NSolarMask
		vStatus = vStatus & NServoToOff
		high oSerSolOff		
	endif
	

	; pumpujeme, tak testujeme cas
	let val1 = vStatus & PumpMask
	if val1 > 0 then
	{
		; gosub read_temperatures
		dec vRemainigPumpTime
		if vRemainigPumpTime > 0 then main_loop
		val1 = vStatus & TestMask
		if val1 > 0 then
			gosub test_stop
			goto main_loop
		endif
		; tu sme skoncili s cerpanim, cakajme na nasledujuci den
		gosub init_new_day
		goto main_loop
	}
	endif
	
	; ak mame drzat teplotu, tak ???
	if vMode = ModeKeep and hour >= vWaitHour then
		gosub pump_on
		goto main_loop
	endif	

	; start noveho dna
	if vMode = ModeEndDay and hour < $5 then
		gosub init_new_day
		goto main_loop
	endif

	if vMode = ModeWait and hour >= vWaitHour then
		gosub test_start
		goto main_loop
	endif
	
	goto main_loop

; -------
init_rtc:
#ifdef simulate_inputs
	let seconds = $00
	let mins = 	$55
	let hour = 	$09
	let day = 	$01
	let date = 	$11
	let month = $12
	let year = 	$18
#else
	hi2csetup i2cmaster, %11010000, i2cslow, i2cbyte ; Ds1307 setup
	;hi2cout 0,(seconds,mins,hour,day,date,month,year,control)
#endif
	gosub read_rtc
	vLastMin = mins - 1 
	return 

; --------
read_rtc:
#ifdef simulate_inputs
	{
	if mins >= $59 then
		val1 = hour % $10
		if val1 = $09 then
			hour = hour + $07
		else
			inc hour
		endif
		mins = 0
	else	
		val1 = mins % $10
		if val1 = $09 then
			mins = mins + $07
		else
			inc mins
		endif
	endif
	inc seconds
	seconds = seconds % 10
	}
#else
	hi2cin 0,(seconds,mins,hour,day,date,month,year)
#endif
	return
	
; --------
display_time:
	serout oDisplay, displaySpeed, (254, 1)
	pause 30

	#ifndef debug_display
	;backligth off
	serout oDisplay, displaySpeed, (255, 4)
	#endif
	
	bcdtoascii date, val1, val2
	serout oDisplay, displaySpeed, (val1, val2, ".")
	bcdtoascii month, val1, val2
	serout oDisplay, displaySpeed, (val1, val2, " ")
	bcdtoascii hour, val1, val2
	serout oDisplay, displaySpeed, (val1, val2, ":")
	bcdtoascii mins, val1, val2
	serout oDisplay, displaySpeed, (val1, val2, ":")
	bcdtoascii seconds, val1, val2
	serout oDisplay, displaySpeed, (val1, val2)
	serout oDisplay, displaySpeed, (254, 192)
	return
	
; --------
display_info:

	gosub display_time
	
	; kazdu 2 sekundu teploty
	val1 = seconds % 10
	val2 = val1 % 2
	if val2 = 0 then
		serout oDisplay, displaySpeed, ("Ti:", #vTin, " To:", #vTout)
		return
	endif

	if val1 = 3 then
		val2 = vStatus & TestMask
		if val2 > 0 then
			serout oDisplay, displaySpeed, ("Test running")
			return
		endif
	elseif val1 = 5 then
		val2 = vStatus & PumpMask
		if val2 > 0 then
			serout oDisplay, displaySpeed, ("Pump rmin: ", #vRemainigPumpTime)
			return
		endif
	elseif val1 = 7 then
		val2 = vStatus & UVMask
		if val2 > 0 then
			serout oDisplay, displaySpeed, ("UV on")
			return
		endif
	elseif val1 = 9 then
		val2 = vStatus & SolarMask
		if val2 > 0 then
			serout oDisplay, displaySpeed, ("Sol on")
		endif
		val2 = vStatus & ServoToOn
		if val2 > 0 then
			serout oDisplay, displaySpeed, (",Ser 0->1")
		endif
		val2 = vStatus & ServoToOff
		if val2 > 0 then
			serout oDisplay, displaySpeed, (",Ser 1->0")
		endif
		return
	endif
	
	; default
	if vMode = ModeWait then
		bcdtoascii vWaitHour, val1, val2
		serout oDisplay, displaySpeed, ("Wait for " , val1, val2, "h")
		return
	endif	
	serout oDisplay, displaySpeed, ("M:" , #vMode, " S:", #vStatus)
	return

; --------
read_temperatures:
	#ifdef simulate_inputs
		let vTin = 25
		let vTout= 28
	#else
		readtemp iTin, vTin
		if vTin > 127 then
		{
			vTin = vTin - 128
		}
		endif

		readtemp iTout, vTout
		if vTout > 127 then
			vTout = vTout - 128
		endif
	#endif

return

; --------
pump_on:
	low oPump;
	vStatus = vStatus | PumpMask
	return
	
; --------
pump_off:
	high oPump;
	vStatus = vStatus & NPumpMask
	return
	
; --------
solar_on:
	val1 = vStatus & SolarMask
	if val1 > 0 then return endif
	low oSerSolOn
	vStatus = vstatus & NServoToOff
	vStatus = vStatus | ServoToOn
	vWaitMin = TimeSolarServo
	return
	
	; --------
solar_off:
	val1 = vStatus & SolarMask
	if val1 = 0 then return endif
	low oSerSolOff
	vStatus = vstatus & NServoToOn
	vStatus = vStatus | ServoToOff
	vWaitMin = TimeSolarServo
	return
	
	;------------
test_start:
	gosub solar_on
	gosub pump_on
	vStatus = vStatus | TestMask
	let vRemainigPumpTime = 10
	return
	
	; -----------
test_stop:
	vstatus = vstatus & NTestMask
	gosub set_remaining_pump_time
	if vTin > vTMax then
		; chceme chladit
		vMode = ModeCool
		vWaitHour = $23
		gosub pump_off
		return
	endif
	val1 = vTout - 2
	if vTin >= vTmin and vTin <= vTmax or vTin > val1 and hour => $23 then
		gosub solar_off
		vMode = ModeKeep
		return
	endif
	;inak chceme hriat
	if vTin > val1 then
		; tuto cakame na pocasie	
		gosub pump_off
		gosub wait_1hour
		return
	endif	
	vMode = ModeHeat
	return
	
	; -----------
init_new_day:
	; ak je to cez den, nastavime cakanie na novy den
	if hour >= $10 then
		vMode = ModeEndDay
		gosub wait_1hour
		return
	endif

	;------------
start_init_new_day:
	if hour >= $20 then init_new_day
	; dame sa do modu Wait a nastavime cakanie na rozumnu hodinu pre test solaru
	let vMode		= ModeWait
	let vWaitHour	= $10
	return
	
	; ---------
wait_1hour:
	val1 = hour % $10
	if val1 = $09 then
		vWaitHour = vWaithour + $07
	else
		vWaitHour = hour + 1
	endif
	return
	
	; -----------
set_remaining_pump_time:
	if vTin > 25 then
		vRemainigPumpTime = 600
	elseif vTin > 20 then
		vRemainigPumpTime = 450
	else
		vRemainigPumpTime = 300
	endif
	return
	
;------------
#ifdef use_test
test_routine:
	; test rtc and sensors
	; clear display
	serout oDisplay, displaySpeed, (254, 1)
	pause 30
	;backligth on
	serout oDisplay, displaySpeed, (255, 0)
	serout oDisplay, displaySpeed, ("Test RTC,Tin,Tou")
	pause 2000
	gosub read_rtc
	gosub read_temperatures

	pause 2000
	
	; relays test
	serout oDisplay, displaySpeed, (254, 1)
	pause 30
	;backligth on
	serout oDisplay, displaySpeed, (255, 0)
	serout oDisplay, displaySpeed, ("Test SolOn-on")
	low oSerSolOn
	pause 2000
	serout oDisplay, displaySpeed, (254, 1)
	pause 30
	serout oDisplay, displaySpeed, ("Test SolOn-off")
	high oSerSolOn
	pause 2000
	serout oDisplay, displaySpeed, (254, 1)
	pause 30
	serout oDisplay, displaySpeed, ("Test SolOff-on")
	low oSerSolOff
	pause 2000
	serout oDisplay, displaySpeed, (254, 1)
	pause 30
	serout oDisplay, displaySpeed, ("Test SolOff-off")
	high oSerSolOff
	pause 2000
	serout oDisplay, displaySpeed, (254, 1)
	pause 30
	serout oDisplay, displaySpeed, ("Test Pump-on")
	low oPump
	pause 2000
	serout oDisplay, displaySpeed, (254, 1)
	pause 30
	serout oDisplay, displaySpeed, ("Test Pump-off")
	high oPump
	pause 2000
	serout oDisplay, displaySpeed, (254, 1)
	pause 30
	serout oDisplay, displaySpeed, ("Test UVLamp-on")
	low oUVLamp
	pause 2000
	serout oDisplay, displaySpeed, (254, 1)
	pause 30
	serout oDisplay, displaySpeed, ("Test UVLamp-off")
	high oUVLamp
	pause 2000
	
	; testing switches
	
	return
#endif
