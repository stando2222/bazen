#picaxe 20M2
REM symboly
symbol iTin 	= C.1
symbol iTout	= C.2
symbol oSerSolOn	= B.0
symbol oSerSolOff = B.1
symbol oPump	= B.1
symbol oDisplay	= B.3
symbol oUVLamp	= B.4

symbol vTin		= B10
symbol vTout	= B11
symbol vLastSolar = B12

symbol sSolarOpen	= 225
symbol sSolarClose= 75

symbol vTmin	= 25
symbol vTmax	= 29

init:
REM nacitanie zapamatovanych hodnot


REM test prebieha nasledujucim sposobom
REM	- spusti sa pumpa
REM	- caka sa minutu a kontroluju sa podmienky az do 15 min. ak je vonku zima, vypiname pumpu a koncime. Ak je to ok, cerpame dalej
TestConditions:
gosub SolarOn
gosub PumpOn
for b0 = 0 to 15
    pause 60000
    readtemp iTin, vTin
    readtemp iTout, vTout
    b1 = vTout + 1
    b2 = vTout - 1
    if vTin < b1 then	;asi je to dobre, cerpame s otvorenym zipsom
	return
    elseif vTin > b2 then
	;je to zle - vonku je zima
	exit
    endif
next
REM inak zastavime test
gosub PumpOff
return

PumpOn:
  high oPump
  return
PumpOff:
  high oPump
  return
SolarOn: 
  low oSerSolOff
  high oSerSolOn
  pause 1000
  return
SolarOff: 
  low oSerSolOn
  high oSerSolOff
  pause 1000
  return
  