/*
 * Demo of I2C ULP routines
 */

#include "soc/rtc_cntl_reg.h"
#include "soc/rtc_io_reg.h"
#include "soc/soc_ulp.h"

#include "stack.S"


/* Define variables, which go into .bss section (zero-initialized data) */
	.bss

prev_temp:	.long 0
prev_pressure: .long 0
prev_pressure2: .long 0

	.global	counter
counter: .long 0

	.global stack
stack:
	.skip 100
	.global stackEnd
stackEnd:
	.long 0


	/* Code goes into .text section */
	.text
	.global entry
entry: //code begins here
	move r3,stackEnd //r3 has ADDRESS of stack end

	// Read the BMP-180 every 4 timer cycles:
	move r1,counter //r1 has ADDRESS of counter
	ld r0,r1,0 //load r0 with the VALUE of counter
	add r0,r0,1 //add 1 (increment)
	st r0,r1,0 // put back in counter
	and r0,r0,0x3 //check the relevant bits
	jumpr waitNext,1,ge //continue the code anytime it's 0, else you halt, which pauses until next cycle

	// GPIO2 LED ON
	//GPIO 2 corresponds to rtc gpio 12. (notice the +12 offset)
	WRITE_RTC_REG(RTC_GPIO_OUT_REG, RTC_GPIO_OUT_DATA_S + 12, 1, 1)

	//you need to call psr before subroutines
	//difference between subroutine and label is the existence of ret (return). psr and ret are defined in stack.S
	//go to file bmp180.S
	psr
	jump readBMP //bmp file line 51

	// GPIO2 LED OFF
	WRITE_RTC_REG(RTC_GPIO_OUT_REG, RTC_GPIO_OUT_DATA_S + 12, 1, 0)

	/* wake up after significant change */
	move r1,pressure
	ld r0,r1,0
	move r1,prev_pressure
	ld r2,r1,0
	sub r0,r0,r2
	psr
	jump abs
	jumpr testTemp,6,lt
	jump wakeUp

testTemp:
	move r1,temp
	ld r0,r1,0
	move r1,prev_temp
	ld r2,r1,0 //r0 has current temp, r1 has prev_temp
	sub r0,r0,r2 //find the difference
	psr
	jump abs //this just deals with negatives
	jumpr waitNext,10,lt //if difference is not big enough then halt. 

wakeUp:
	/* save new pressure and temp */
	move r1,pressure
	ld r0,r1,0
	move r1,prev_pressure
	st r0,r1,0
	move r1,temp
	ld r0,r1,0
	move r1,prev_temp
	st r0,r1,0
	/* Wake up the SoC, end program */
	wake
	/* Stop the wakeup timer so it does not restart ULP */
	WRITE_RTC_FIELD(RTC_CNTL_STATE0_REG, RTC_CNTL_ULP_CP_SLP_TIMER_EN, 0)

waitNext:
	halt

// Compute abs value of R0
abs:
	and r1,r0,0x8000
	jump noNegate,eq
	move r1,0
	sub r0,r1,r0
noNegate:
	ret
