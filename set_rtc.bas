; Use a Ds1307 RTC
#picaxe 20m2 ; type chip used


symbol val = b13  ; if needed
symbol temp = b14




symbol seconds = b0
symbol mins = b1
symbol hour = b2
symbol day = b3
symbol date = b4
symbol month = b5
symbol year = b7
symbol control = b8

   
hi2csetup i2cmaster, %11010000, i2cslow, i2cbyte ; Ds1307 setup

   
gosub set_clock

   
main:


hi2cin 0,(seconds,mins,hour,day,date,month,year)
debug

; ASCII code 48 -> 57 is 0 -> 9 so add/subtract 48
; order is sec - min - hours - day - month - year
; could also use bcdtoaschii (p. 35) but this illustrates the process.


serout 0,N2400,("Cas ")

; print hours

val = hour / 16 + 48  
; shift high nibble 4 places right change to ASCII
serout 0, N2400, (val)
val = hour & %000001111 + 48 
; mask high nibble change lower nibble to ASCII
serout 0, N2400, (val)

; print minutes

val = mins /16 + 48   
; shift high nibble 4 places right change to ASCII
serout 0, N2400, (":", val)
val = mins & %00001111 + 48 
; mask high nibble change lower nibble to ASCII
serout 0, N2400, (val)


; print seconds

val = seconds / 16 + 48  
; shift high nibble 4 places right change to ASCII
serout 0, N2400, (":", val)
val = seconds & %00001111 + 48 
; mask high nibble change lower nibble to ASCII
serout 0, N2400, (val) ; LF - CR


; print day
val = date / 16 + 48  
serout 0, N2400, (" ", val)
val = date & %00001111 + 48 
; mask high nibble change lower nibble to ASCII
serout 0, N2400, (val) ; LF - CR

; print month
val = month / 16 + 48  
serout 0, N2400, (".", val)
val = month & %00001111 + 48 
; mask high nibble change lower nibble to ASCII
serout 0, N2400, (val) ; LF - CR

; print year
val = year / 16 + 48  
serout 0, N2400, (".", val)
val = year & %00001111 + 48 
; mask high nibble change lower nibble to ASCII
serout 0, N2400, (val, 13, 10) ; LF - CR



pause 1000

goto main


set_clock: ; input time to Ds1307

let seconds = $00; 00 Note all BCD format
let mins    = $44; 59 Note all BCD format
let hour    = $09; 11 Note all BCD format
let day     = $06; Note all BCD format
let date    = $19; 25 Note all BCD format
let month   = $02; 12 Note all BCD format
let year    = $17; 03 Note all BCD format
let control = %00010000 ; Enable output at 1Hz
hi2cout 0,(seconds,mins,hour,day,date,month,year,control)

pause 1000


goto main

