#picaxe 20M2
; Regulacia bazenu
; version 0.2
; date 21.10.2015

; ---------------------
; symbols

; input pins
symbol iTin 	= C.1
symbol iTout	= C.2

; output pins
symbol oSerSolOn	= B.0
symbol oSerSolOff = B.1
symbol oPump	= B.1
symbol oDisplay	= B.3
symbol oUVLamp	= B.4

symbol hi2csda	= B.5
symbol hi2cscl	= B.7

; variables
symbol vMode	= b10
symbol vLastMin	= b11
symbol vTin		= b12
symbol vTout	= b13
symbol vLastSolar = b14

; temporary
symbol seconds	= b0
symbol mins		= b1
symbol hour		= b2
symbol day		= b3
symbol date		= b4
symbol month	= b5
symbol year		= b6

symbol val1		= b7
symbol val2		= b8



; constants
symbol vTmin	= 25
symbol vTmax	= 29

symbol ModeHeat	= 1
symbol ModeCool	= 2
symbol ModeKeep	= 3



; ---------------------
; initialization
init:
	gosub init_rtc

; main loop
main_loop:
	gosub read_rtc
	if mins = vLastMin	then main_loop
	
	gosub display_time
	let vLastMin = mins

	if vMode = ModeHeat then
	{
	}
	elseif vMode = ModeCool then
	elsendif
	

	pause 60000
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
	bcdtoascii day, val1, val2
	serout oDisplay, N2400, (val1, val2, ",")
	bcdtoascii month, val1, val2
	serout oDisplay, N2400, (val1, val2, ".", " ")
	bcdtoascii hour, val1, val2
	serout oDisplay, N2400, (val1, val2, ":")
	bcdtoascii mins, val1, val2
	serout oDisplay, N2400, (val1, val2)
	return