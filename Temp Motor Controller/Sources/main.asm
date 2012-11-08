;************************************************************************************
;*
;* File name: DS1620.ASM
;* Example Code for the MC68HC705J1A Interface to the
;* Dallas DS1620 Digital Thermometer
;* Ver: 1.0
;* Date: June 5, 1998
;* Author: Mark Glenewinkel
;* Freescale Field Applications
;* Consumer Systems Group
;* Assembler: P&E IDE ver 1.02
;*
;* For code explanation and flow charts,
;* please consult Freescale Application Note
;* "Interfacing the MC68HC705J1A to the DS1620 Digital Thermometer"
;* Literature # AN1754/D
;*
;***********************************************************************************
;*** SYSTEM DEFINITIONS AND EQUATES **************************************************
;*** Internal Register Definitions
PORTA        EQU $00     ;PortA
DDRA         EQU $04     ;data direction for PortA
;*** Application Specific Definitions
SER_PORT    EQU $00     ;PORTA is SER_PORT
CLK          EQU 1T      ;PORTA, bit 1, clock signal
DQ           EQU 0T      ;PORTA, bit 0, data signal
RST          EQU 2T      ;PORTA, bit 2, reset signal
DQ_DIR       EQU 0T      ;PortA Data Dir for DQ signal
READ_TEMP    EQU $AA     ;instr for reading temperature
START_CONV   EQU $EE     ;instr for staarting temperature conv
STOP_CONV    EQU $22     ;instr for stopping temperature conv
WRITE_TH     EQU $01     ;instr for writes high temp limit to TH reg
WRITE_TL     EQU $02     ;instr for writes low temp limit to TL reg
READ_TH      EQU $A1     ;instr for reads high temp limit from TH reg
READ_TL      EQU $A2     ;instr for reads high temp limit from TL reg
WRITE_CONFIG EQU $0C     ;instr for writes to config reg
READ_CONFIG  EQU $AC     ;instr for reads from config reg
;*** Memory Definitions
EPROM        EQU $300    ;staart of EPROM mem
RAM          EQU $C0     ;staart of RAM mem
RESET        EQU $7FE    ;vector for reset

;*** RAM VARIABLES ******************************************************************
             ORG RAM
TEMP_MSB     DB   1      ;temperature reading MSB
TEMP_LSB     DB   1      ;temperature reading MSB
TH_MSB       DB   1      ;High temp trigger MSB
TH_LSB       DB   1      ;High temp trigger LSB
TL_MSB       DB   1      ;Low temp trigger MSB
TL_LSB       DB   1      ;Low temp trigger LSB
;*** MAIN ROUTINE *******************************************************************
             ORG EPROM   ;staart at begining of EPROM
;*** Intialize Ports
START        ldaa #$07    ;init SER_PORT
             staa SER_PORT
             ldaa #$07    ;make SER_PORT pins outputs
             staa DDRA
;*** Write $00 to Config reg, setup for cont conv
             ldaa #WRITE_CONFIG ;load Acca with instruction
             jsr TXD      ;transmit instruction
             ldaa #$00     ;load Acc with data
             jsr TXD      ;transmit data
             bclr RST,SER_PORT ;toggle RST
             bset RST,SER_PORT
             jsr NV_WAIT  ;wait ~50 ms for NV memory operation
;*** Set the TH reg to $3C = 30C = 86F
             ldaa #WRITE_TH ;load Acca with instruction
             jsr TXD       ;transmit instruction
             ldaa #$3C      ;load Acc with data
             jsr TXD       ;transmit data
             ldaa #$00      ;load Acc with data
             jsr TXD       ;transmit data
             bclr RST,SER_PORT ;toggle RST
             bset RST,SER_PORT
             jsr NV_WAIT   ;wait ~50 ms for NV memory operation
;*** Read the TH reg to verify
             ldaa #READ_TH  ;load Acca with instruction
             jsr TXD       ;transmit instruction
             jsr RXD       ;receive data
             staa TH_LSB    ;store away result
             jsr RXD       ;receive data
             staa TH_MSB    ;store away result
             bclr RST,SER_PORT ;toggle RST
             bset RST,SER_PORT
;*** Set the TL reg to $28 = 20C = 68F
             ldaa #WRITE_TL ;load Acca with instruction
             jsr TXD       ;transmit instruction
             ldaa #$28      ;load Acc with data
             jsr TXD       ;transmit data
             ldaa #$00      ;load Acc with data
             jsr TXD       ;transmit data
             bclr RST,SER_PORT ;toggle RST
             bset RST,SER_PORT
             jsr NV_WAIT   ;wait ~50 ms for NV memory operation
;*** Read the TL reg to verify
             ldaa #READ_TL  ;load Acca with instruction
             jsr TXD       ;transmit instruction
             jsr RXD       ;receive data
             staa TL_LSB    ;store away result
             jsr RXD       ;receive data
             staa TL_MSB    ;store away result
             bclr RST,SER_PORT ;toggle RST
             bset RST,SER_PORT
;*** start temperature conversion
             ldaa #START_CONV ;load Acca with instruction
             jsr TXD       ;transmit instruction
             bclr RST,SER_PORT ;toggle RST
             bset RST,SER_PORT
;*** Read current temperature
             ldaa #READ_TEMP ;load Acca with instruction
             jsr TXD        ;transmit instruction
             jsr RXD        ;receive data
             staa TEMP_LSB   ;store away result
             jsr RXD        ;receive data
             staa TEMP_MSB   ;store away result
             bclr RST,SER_PORT ;toggle RST
             bset RST,SER_PORT
             DUMMY bra DUMMY ;test sequence is over
;*** SUBROUTINES ********************************************************************
;*** Routine takes contents of AccA and transmits it serially to
;*** the DS1620, LSB first
TXD          ldx #8T ;set counter

WRITE        asra ;Carry bit = LSB
             bcc J1
             bset DQ,SER_PORT ;DQ=1
             bra CLOCK_IT ;branch to clock_it             
J1           bclr DQ,SER_PORT ;DQ=0
             brn J1 ;evens it out
             
CLOCK_IT     bclr CLK,SER_PORT ;CLK=0
             bset CLK,SER_PORT ;CLK=1
             dex ;decrement counter
             bne WRITE
             rts ;return from sub
;*** Routine clocks the DS1620 to read data from DQ, LSB first
;*** 8 bit contents are put in AccA
RXD          bclr DQ_DIR,DDRA ;make the DQ pin on J1A input
             ldx #8T ;set counter
             
READ         bclr CLK,SER_PORT ;CLK=0
             brclr DQ,SER_PORT,J2 ;carry bit = DQ
J2           rora ;put carry bit into AccA LSB
             bset CLK,SER_PORT ;CLK=1
             
             dex ;decrement counter
             bne READ
             
             bset DQ_DIR,DDRA ;make the DQ pin on J1A output
             rts ;return from sub
;*** Routine creates a ~50 ms routine with a 2MHz MCU internal bus for
;*** NV memory to be set correctly
NV_WAIT      ldx #66T
J3           ldaa #255T
J4           deca ;3
             bne J4 ;3
             dex
             bne J3
             rts
             
;*** VECTOR TABLE *******************************************************************
             ORG RESET
             DW START