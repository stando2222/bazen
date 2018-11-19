#picaxe 20M2
; Regulacia bazenu
; version 0.4
; date 31.10.2015

; ---------------------
; symbols

#define use_test

; input pins
symbol iTin 	= C.0
symbol iTout	= C.1
symbol iSw0		= C.2
symbol iSw1		= C.3
symbol iSw2		= C.4
symbol iSw3		= C.5

; output pins
symbol oDisplay	= B.0
symbol oSerSolOn	= B.1
symbol oSerSolOff = B.2
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


symbol DefaTmin			= 25
symbol DefaTmax			= 29
symbol DefaPumpTime		= 600			; in minutes


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



; debug start
debug_init:

	pause 1000
	
; temporary init
	vTmin = DefaTmin
	vTmax = DefaTmax


; ---------------------
; initialization
init:	
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
	
	if vMode = ModeKeep and hour >= vWaitHour then
		gosub pump_on
		goto cakaj_main
	endif	

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

init_rtc:
	hi2csetup i2cmaster, %11010000, i2cslow, i2cbyte ; Ds1307 setup
	;hi2cout 0,(seconds,mins,hour,day,date,month,year,control)
	return 

; --------
read_rtc:
	hi2cin 0,(seconds,mins,hour,day,date,month,year)
	return
; --------
display_time:
	serout oDisplay, N2400, (254, 1)
	pause 30
	
	;backligth off
	serout oDisplay, N2400, (255, 4)
	
	bcdtoascii date, val1, val2
	serout oDisplay, N2400, (val1, val2, ".")
	bcdtoascii month, val1, val2
	serout oDisplay, N2400, (val1, val2, ".", " ")
	bcdtoascii hour, val1, val2
	serout oDisplay, N2400, (val1, val2, ":")
	bcdtoascii mins, val1, val2
	serout oDisplay, N2400, (val1, val2, " M:" , #vMode)
	
	serout oDisplay, N2400, (254, 192)
	serout oDisplay, N2400, ("Ti:", #vTin, " To:", #vTout, " S:", #vStatus)
	return
; --------
read_temperatures:
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
	pause 15000
	high oSerSolOn
	vStatus = vStatus | SolarMask
	return
	; --------
solar_off:
	val1 = vStatus & SolarMask
	if val1 = 0 then return endif
	low oSerSolOff
	pause 15000
	high oSerSolOff
	vStatus = vStatus & NSolarMask
	return
test_start:
	gosub solar_on
	gosub pump_on
	vStatus = vStatus | TestMask
	let vRemainigPumpTime = 10
	return
	; -----------
test_stop:
	vstatus = vstatus & NTestMask
	if vTin > vTMax then
		vMode = ModeCool
		gosub set_remaining_pump_time
		vWaitHour = $23
		gosub pump_off
		return
	endif
	val1 = vTout - 2
	if vTin >= vTmin and vTin <= vTmax or vTin > val1 and hour => $23 then
		gosub set_remaining_pump_time
		gosub solar_off
		vMode = ModeKeep
		return
	endif
	;inak chceme hriat
	if vTin > val1 then
		; tuto cakame na pocasie	
		gosub pump_off
		gosub wait_1hour
	endif	
	gosub set_remaining_pump_time
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
	serout oDisplay, N2400, (254, 1)
	pause 30
	;backligth on
	serout oDisplay, N2400, (255, 0)
	serout oDisplay, N2400, ("Test RTC,Tin,Tou")
	pause 2000
	gosub read_rtc
	gosub read_temperatures
	gosub display_time
	pause 2000
	
	; relays test
	serout oDisplay, N2400, (254, 1)
	pause 30
	;backligth on
	serout oDisplay, N2400, (255, 0)
	serout oDisplay, N2400, ("Test SolOn-on")
	low oSerSolOn
	pause 2000
	serout oDisplay, N2400, (254, 1)
	pause 30
	serout oDisplay, N2400, ("Test SolOn-off")
	high oSerSolOn
	pause 2000
	serout oDisplay, N2400, (254, 1)
	pause 30
	serout oDisplay, N2400, ("Test SolOff-on")
	low oSerSolOff
	pause 2000
	serout oDisplay, N2400, (254, 1)
	pause 30
	serout oDisplay, N2400, ("Test SolOff-off")
	high oSerSolOff
	pause 2000
	serout oDisplay, N2400, (254, 1)
	pause 30
	serout oDisplay, N2400, ("Test Pump-on")
	low oPump
	pause 2000
	serout oDisplay, N2400, (254, 1)
	pause 30
	serout oDisplay, N2400, ("Test Pump-off")
	high oPump
	pause 2000
	serout oDisplay, N2400, (254, 1)
	pause 30
	serout oDisplay, N2400, ("Test UVLamp-on")
	low oUVLamp
	pause 2000
	serout oDisplay, N2400, (254, 1)
	pause 30
	serout oDisplay, N2400, ("Test UVLamp-off")
	high oUVLamp
	pause 2000
	
	; testing switches
	
	return
#endif