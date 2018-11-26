#picaxe 20M2
; Regulacia bazenu
; version 0.9
; date 26.11.2018

; ---------------------

#define use_test
#define debug_display
#define simulate_inputs

; symbols
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

; variables
symbol vMode	= b10
symbol vStatus	= b11
symbol vLastMin	= b12
symbol vTin		= b13
symbol vTout	= b14
symbol vLastSolar = b15
symbol vTmin	= b16
symbol vTmax	= b17
symbol vWaitHour	= b18
;b19

symbol vRemainigPumpTime	= w10			; in minutes
symbol vDayPumpTime		= w11

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

symbol TimeSolarOnOff3	= 50000

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
symbol NPumpMask	= %11111110
symbol NUVMask	= %11111101
symbol NTestMask	= %11111011
symbol NSolarMask = %11110111

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
	if mins = vLastMin then
	{  
	   pause 1000
	   goto main_loop
	}
	endif

	gosub read_temperatures
	gosub display_time
	let vLastMin = mins
	debug
	
	; pumpujeme, tak testujeme cas
	let val1 = vStatus & PumpMask
	if val1 > 0 then
	{
		dec vRemainigPumpTime
		if vRemainigPumpTime > 0 then cakaj_main
		val1 = vStatus & TestMask
		if val1 > 0 then
			gosub test_stop
			goto cakaj_main
		endif
		; tu sme skoncili s cerpanim, cakajme na nasledujuci den
		gosub init_new_day
		goto cakaj_main
	}
	endif
	
	; ak mame drzat teplotu, tak ???
	if vMode = ModeKeep and hour >= vWaitHour then
		gosub pump_on
		goto cakaj_main
	endif	

	; start noveho dna
	if vMode = ModeEndDay and hour < $5 then
		gosub init_new_day
		goto cakaj_main
	endif

	if vMode = ModeWait and hour >= vWaitHour then
		gosub test_start
		goto cakaj_main
	endif
	
cakaj_main:
	pause 50000
	goto main_loop

; -------
init_rtc:
#ifdef simulate_inputs
	let seconds = 0
	let mins = 0x0
	let hour = 0x9
	let day = 0x1
	let date = 0x12
	let month = 0x12
	let year = 0x18
#else
	hi2csetup i2cmaster, %11010000, i2cslow, i2cbyte ; Ds1307 setup
	;hi2cout 0,(seconds,mins,hour,day,date,month,year,control)
#endif
	return 

; --------
read_rtc:
#ifdef simulate_inputs
	if mins >= 60 then
		inc hour
		mins = 0
	else	
		inc mins
	endif	
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
	serout oDisplay, displaySpeed, (val1, val2, ".", " ")
	bcdtoascii hour, val1, val2
	serout oDisplay, displaySpeed, (val1, val2, ":")
	bcdtoascii mins, val1, val2
	serout oDisplay, displaySpeed, (val1, val2, " M:" , #vMode)
	
	serout oDisplay, displaySpeed, (254, 192)
	serout oDisplay, displaySpeed, ("Ti:", #vTin, " To:", #vTout, " S:", #vStatus)
	return

; --------
read_temperatures:
	#ifdef debug_display
		serout oDisplay, displaySpeed, (254, 1)
		pause 30
		serout oDisplay, displaySpeed, ("Read temperatures")
		pause 2000
	#endif
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
	#ifdef debug_display
		serout oDisplay, displaySpeed, (254, 1)
		pause 30
		serout oDisplay, displaySpeed, ("Pump off->on")
		pause 1000
		gosub display_time
	#endif
	low oPump;
	vStatus = vStatus | PumpMask
	return
	
; --------
pump_off:
	#ifdef debug_display
		serout oDisplay, displaySpeed, (254, 1)
		pause 30
		serout oDisplay, displaySpeed, ("Pump on->off")
		pause 1000
		gosub display_time
	#endif
	high oPump;
	vStatus = vStatus & NPumpMask
	return
	
; --------
solar_on:
	val1 = vStatus & SolarMask
	if val1 > 0 then return endif
	#ifdef debug_display
		serout oDisplay, displaySpeed, (254, 1)
		pause 30
		serout oDisplay, displaySpeed, ("Solar off->on")
	#endif
	low oSerSolOn
	pause TimeSolarOnOff3
	pause TimeSolarOnOff3
	pause TimeSolarOnOff3
	#ifdef debug_display
		gosub display_time
	#endif
	high oSerSolOn
	vStatus = vStatus | SolarMask
	return
	
	; --------
solar_off:
	val1 = vStatus & SolarMask
	#ifdef debug_display
		serout oDisplay, displaySpeed, (254, 1)
		pause 30
		serout oDisplay, displaySpeed, ("Solar on->off")
	#endif
	if val1 = 0 then return endif
	low oSerSolOff
	pause TimeSolarOnOff3
	pause TimeSolarOnOff3
	pause TimeSolarOnOff3
	#ifdef debug_display
		gosub display_time
	#endif
	high oSerSolOff
	vStatus = vStatus & NSolarMask
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
	vWaitHour = hour + 1
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
	gosub display_time
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
