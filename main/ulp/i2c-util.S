/*
 * I2C ULP utility routines
 */

#include "soc/rtc_cntl_reg.h"
#include "soc/rtc_io_reg.h"
#include "soc/soc_ulp.h"

#include "stack.S"

.text

write_intro:
	psr
	jump i2c_start_cond

	ld r2,r3,20 // Address (param1)
	lsh r2,r2,1 //add 0 to the rightmost to indicate write
	psr
	jump i2c_write_byte
	jumpr popfail,1,ge

	ld r2,r3,16 // Register (param2)
	psr
	jump i2c_write_byte
	jumpr popfail,1,ge
	ret


.global write8
write8:
	psr
	jump write_intro

write_b:
	ld r2,r3,8 // data byte
	psr
	jump i2c_write_byte
	jumpr fail,1,ge

	psr
	jump i2c_stop_cond

	move r2,0 // Ok
	ret //if i came from write 8, where do i return to?


.global write16
write16:
	psr
	jump write_intro

	ld r2,r3,8 // data byte 1
	rsh r2,r2,8
	psr
	jump i2c_write_byte
	jumpr fail,1,ge

	jump write_b


read_intro: //note that r2 is used to contain the content to write to the sensor
	psr
	jump i2c_start_cond//go to i2c.s

	ld r2,r3,16 // Address. remember that r3 is stack. go the the 5th item from top/ go to line 156 of bmp to see 
	lsh r2,r2,1 //puts a 0 in the rightmost to indicate a write operation (i think)
	psr
	jump i2c_write_byte // go to i2c.s 187. writes the address 
	jumpr popfail,1,ge //jump r is based on r0, so

	ld r2,r3,12 // Register
	psr
	jump i2c_write_byte //write the register
	jumpr popfail,1,ge

	psr
	jump i2c_start_cond //repeated start

	ld r2,r3,16 //get address again
	lsh r2,r2,1 // put a 1 in the rightmost to indicate a read
	or r2,r2,1 // Address Read
	psr
	jump i2c_write_byte
	jumpr popfail,1,ge

	ret //back to read16/8 on this file
popfail:
	pop r1 // pop caller return address
	move r2,1
	ret

.global read8
read8:
	psr
	jump read_intro

	move r2,1 // last byte
	psr
	jump i2c_read_byte
	push r0

	psr
	jump i2c_stop_cond

	pop r0

	move r2,0 // OK
	ret
fail:
	move r2,1
	ret

.global read16
read16:
	psr
	jump read_intro //look up in this file. it does  the start condition, address, register and 

	move r2,0
	psr
	jump i2c_read_byte //go to 203 of i2c.s. reads 1 byte
	push r0

	move r2,1 // last byte
	psr
	jump i2c_read_byte //read the next byte
	push r0

	psr
	jump i2c_stop_cond

	pop r0
	pop r2 // first byte
	lsh r2,r2,8
	or r2,r2,r0
	move r0,r2 //combining the bytes together

	move r2,0 // OK
	ret //back to 162 of bmp
