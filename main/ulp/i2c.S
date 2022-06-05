/*
 * Demo of I2C ULP routines
 */

#include "soc/rtc_cntl_reg.h"
#include "soc/rtc_io_reg.h"
#include "soc/soc_ulp.h"

#include "stack.S"


/*
 * =============================== I2C code ==========================================
 * Implementation of pseudo code from
 * https://en.wikipedia.org/wiki/I%C2%B2C#Example_of_bit-banging_the_I.C2.B2C_master_protocol
 */

.bss
i2c_started:
	.long 0

i2c_didInit:
	.long 0

.text

.global i2c_start_cond
.global i2c_stop_cond
.global i2c_write_bit
.global i2c_read_bit
.global i2c_write_byte
.global i2c_read_byte

.macro I2C_delay
	wait 10 // 38 // minimal 4.7us
.endm

.macro read_SCL // Return current level of SCL line, 0 or 1
	READ_RTC_REG(RTC_GPIO_IN_REG, RTC_GPIO_IN_NEXT_S + 9, 1) // RTC_GPIO_9 == GPIO_32
.endm

.macro read_SDA // Return current level of SDA line, 0 or 1
	READ_RTC_REG(RTC_GPIO_IN_REG, RTC_GPIO_IN_NEXT_S + 8, 1) // RTC_GPIO_8 == GPIO_33
.endm

.macro set_SCL // Do not drive SCL (set pin high-impedance)
	WRITE_RTC_REG(RTC_GPIO_ENABLE_W1TC_REG, RTC_GPIO_ENABLE_W1TC_S + 9, 1, 1)
.endm

.macro clear_SCL // Actively drive SCL signal low
	// Output mode
	WRITE_RTC_REG(RTC_GPIO_ENABLE_W1TS_REG, RTC_GPIO_ENABLE_W1TS_S + 9, 1, 1)
.endm

.macro set_SDA // Do not drive SDA (set pin high-impedance)
	WRITE_RTC_REG(RTC_GPIO_ENABLE_W1TC_REG, RTC_GPIO_ENABLE_W1TC_S + 8, 1, 1)
.endm

.macro clear_SDA // Actively drive SDA signal low
	// Output mode
	WRITE_RTC_REG(RTC_GPIO_ENABLE_W1TS_REG, RTC_GPIO_ENABLE_W1TS_S + 8, 1, 1)
.endm


i2c_start_cond:
	move r1,i2c_didInit //r1 has address
	ld r0,r1,0 //r1 has value, which is 0
	jumpr didInit,1,ge //jump if r0 is greater than 1, which it isn't 
	move r0,1 //so then continue 
	st r0,r1,0// and set didInit to 1 so that it doesn't repeat again
// set GPIO to pull low when activated
	WRITE_RTC_REG(RTC_GPIO_OUT_REG, RTC_GPIO_OUT_DATA_S + 9, 1, 0) //rtc 8 and rtc 9 correspond to gpio 33 and gpio 32 
	WRITE_RTC_REG(RTC_GPIO_OUT_REG, RTC_GPIO_OUT_DATA_S + 8, 1, 0)// sda is 33/8
didInit:
	move r2,i2c_started //r2 has i2c address
	ld r0,r2,0 //has value pf i2c_started which is 0
	jumpr not_started,1,lt //if it's < 1 (basically 0 ) then jump to not started at bottom
// if started, do a restart condition
// set SDA to 1
	set_SDA
	I2C_delay
	set_SCL
clock_stretch: // TODO: Add timeout?
	read_SCL
	jumpr clock_stretch,1,lt //clock stretch until it's not 0

// Repeated start setup time, minimum 4.7us
	I2C_delay

not_started:
	// if (read_SDA() == 0) {
 	//		arbitration_lost();
 	// }

// SCL is high, set SDA from 1 to 0.
	clear_SDA
	I2C_delay
	clear_SCL
	move r0,1
	st r0,r2,0

	ret//back to line 64 of util


i2c_stop_cond:
// set SDA to 0
	clear_SDA
	I2C_delay

	set_SCL
clock_stretch_stop:
	read_SCL
	jumpr clock_stretch_stop,1,lt

// Stop bit setup time, minimum 4us
	I2C_delay

// SCL is high, set SDA from 0 to 1
	set_SDA
	I2C_delay
	// if (read_SDA() == 0) {
 	//		arbitration_lost();
 	// }

 	move r2,i2c_started
 	move r0,0
 	st r0,r2,0

 	ret


// Write a bit to I2C bus
i2c_write_bit://artificially creating a clock it looks like
	jumpr bit0,1,lt
	set_SDA
	jump bit1
bit0:
	clear_SDA
bit1:

// SDA change propagation delay
	I2C_delay
// Set SCL high to indicate a new valid SDA value is available
	set_SCL
// Wait for SDA value to be read by slave, minimum of 4us for standard mode
	I2C_delay

clock_stretch_write:
	read_SCL
	jumpr clock_stretch_write,1,lt

	// SCL is high, now data is valid
 	// If SDA is high, check that nobody else is driving SDA
 	// if (bit && (read_SDA() == 0)) {
 	// 		arbitration_lost();
 	// }

 	// Clear the SCL to low in preparation for next change
 	clear_SCL

 	ret


// Read a bit from I2C bus
i2c_read_bit:
// Let the slave drive data
	set_SDA
// Wait for SDA value to be written by slave, minimum of 4us for standard mode
	I2C_delay
// Set SCL high to indicate a new valid SDA value is available
 	set_SCL

clock_stretch_read:
	read_SCL
	jumpr clock_stretch_read,1,lt

// Wait for SDA value to be written by slave, minimum of 4us for standard mode
	I2C_delay
// SCL is high, read out bit
	read_SDA
// Set SCL low in preparation for next operation
	clear_SCL

	ret // bit in r0

// Write a byte to I2C bus. Return 0 if ack by the slave.
i2c_write_byte:
	stage_rst //set to 0
next_bit:
	and r0,r2,0x80 // he is writing one bit at at time starting with the 7th bit then shifting it left on line 193
	psr
	jump i2c_write_bit// 132 of this file
	lsh r2,r2,1
	stage_inc 1
	jumps next_bit,8,lt //keep on writing bits until you reach a byte

	psr
	jump i2c_read_bit //165 of this
	ret // nack, back to util 69


// Read a byte from I2C bus
i2c_read_byte:
	push r2
	move r2,0
	stage_rst
next_bit_read:
	psr
	jump i2c_read_bit
	lsh r2,r2,1
	or r2,r2,r0
	stage_inc 1
	jumps next_bit_read,8,lt

	pop r0
	psr
	jump i2c_write_bit

	move r0,r2

	ret

