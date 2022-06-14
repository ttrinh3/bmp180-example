# ULP Process

## 1. Entry
-initialize stack
-create loop that reads at the 4th cycle (jump to waitNext 3/4 times)
-turns on GPIO2 but this is not necessary for our project

## 2. readBMP
- does something with the calibration values that will not be applicable to bme680

## 3. didInit
- put 1. slave addr, 2. register addr, 3. command on stack
- write these using write8

### write8
- write_intro intitiates the communication with START COMMAND
- follows up by writing slave_addr (7bit slave_addr + 0 bit to indicate write) using write_byte
- follows up writing register write_byte

### write_b
- writes the command using write_byte
- issues stop command (at this point 3 parameters that were on the stack are used)

## 3. Back to didInit
- remove the 3 parameters that were all used in the subroutines

- push slave address and reg_result (after writing command this register contains a word representing temperature). It's on the datasheet p.22 if you don't believe me

- read16 reads 2bytes because the temperature is contained by a word

- remove 2 parameters that were pushed to the stack

- at this point r0 probably contains the word and is stored in r1

- put that result in temp

- repeat the process for reading pressure

## 4. Entry
- compares new pressure with the prev_pressure 
- if not enough change then check temperature difference else wakeup
- if temp difference not enough wait for next cycle else wakeup

## 5. wakeUp

- saves new pressure and temperature
- disables ULP and wakes up system



