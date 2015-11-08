; Game of Life on a 24x24 LED.

; Rules taken from Wikipedia, http://en.wikipedia.org/wiki/Conway%27s_Game_of_Life...

; The universe of the Game of Life is an infinite two-dimensional orthogonal grid of square cells,
; each of which is in one of two possible states, live or dead.
; Every cell interacts with its eight neighbours, which are the cells that are directly horizontally,
; vertically, or diagonally adjacent. At each step in time, the following transitions occur:

;   1. Any live cell with fewer than two live neighbours dies, as if by loneliness.
;   2. Any live cell with more than three live neighbours dies, as if by overcrowding.
;   3. Any live cell with two or three live neighbours lives, unchanged, to the next generation.
;   4. Any dead cell with exactly three live neighbours comes to life.

; The initial pattern constitutes the 'seed' of the system.
; The first generation is created by applying the above rules simultaneously to every cell in the seed--
; births and deaths happen simultaneously, and the discrete moment at which this happens is sometimes called a tick.
; (In other words, each generation is based entirely on the one before.)
; The rules continue to be applied repeatedly to create further generations.

; ========================================================================================

; My version has a 24x24 grid displayed on the screen.
; There is no editor so edit Grid1 and re-compile.

; Note that I have two grids 26x26 bytes, but I only use 24x24 bytes for game of life.
; This is to make the calculations simpler when calculating number of neighbours.
; I don't have to do any calculations for wrap around or anything like that.


; The Load data (pin 12) on Max 7219 is connected to PA0 (pin 2) on the 6522.
; Clock (pin 13) on Max 7219 is connected to CB1 (pin 18 ) on the 6522.
; Data In (pin 1) on Max 7219 is connected to CB2 (pin 19) on the 6522.


; File: Game.asm
; 11/08/2015

       PW 80         ;Page Width (# of char/line)
       PL 60          ;Page Length for HP Laser
       INCLIST ON     ;Add Include files in Listing

				;*********************************************
				;Test for Valid Processor defined in -D option
				;*********************************************
  	IF	USING_816
  	ELSE
  		EXIT         "Not Valid Processor: Use -DUSING_02, etc. ! ! ! ! ! ! ! ! ! ! ! !"
  	ENDIF

;****************************************************************************
;****************************************************************************
; End of testing for proper Command line Options for Assembly of this program
;****************************************************************************
;****************************************************************************


			title  "Game of Life on a 24x24 LED."
			sttl

; Constants, VIA addresses
VIA           EQU $7FC0
VIA_IOB       EQU VIA             ; Input/Output register B
VIA_IOA       EQU VIA+1           ; Input/Output register A
VIA_DDRB      EQU VIA+2           ; Data Direction Port B
VIA_DDRA      EQU VIA+3           ; Data Direction Port A
VIA_T1CL      EQU VIA+4           ; T1 Low Order Counter
VIA_T1CH      EQU VIA+5           ; T1 High Order Counter
VIA_T1LL      EQU VIA+6           ; T1 Low Order Latches
VIA_T1LH      EQU VIA+7           ; T1 High Order Latches
VIA_T2CL      EQU VIA+8           ; T2 Low Order Counter
VIA_T2CH      EQU VIA+9           ; T2 High Order Counter
VIA_SR        EQU VIA+10          ; Shift Register
VIA_ACR       EQU VIA+11          ; Auxiliary Control Register
VIA_PCR       EQU VIA+12          ; Pheriperal Control Register
VIA_IFR       EQU VIA+13          ; Interrupt Flag Register
VIA_IER       EQU VIA+14          ; Interrupt Enable Register
VIA_IOA2      EQU VIA+15          ; Input/Output register A, No handshake

; VIA stuff
add           EQU $30             ; Address in Max7219
dat           EQU $31             ; Data for Address
units         EQU $32             ; LED units.
count         EQU $33             ; Counter
rows          EQU $34             ; Rows
cols          EQU $35             ; Columns
temp          EQU $36             ; Temp Storage
LEDGridl      EQU $37             ; Grid Pointer Low
LEDGridh      EQU $38             ; Grid Pointer High
temp2         EQU $39             ; Temp Storage 2

; Game Of Life Stuff
tick          EQU $40             ; Even use grid 1, Odd use grid 2
row_counter   EQU $41             ; count the rows to print.
GridLow       EQU $42             ; Grid pointer.
GridHi        EQU $43
WorkGridLow   EQU $44             ; Grid Pointer for work grid.
WorkGridHi    EQU $45
cell_count    EQU $46             ; Used to count cells.

  CHIP	65C02
  LONGI	OFF
  LONGA	OFF

  .sttl "Game of Life on a 24x24 LED."
  .page

; Put in code segment...
 CODE

; START @ $1000
              org $1000
	START:

              LDA #$09            ; 9 UNITS, 24X24 ledS
              STA units
              JSR init_VIA        ; Init VIA
              JSR init_max7219    ; Inint Dispaly
              LDA #$00
              STA tick            ; Start with grid 1

MainLoop      JSR LifeToLED       ; Conver Lif grid to LED grid
              JSR showGridData    ; Display it
              JSR next_tick       ; Calculate next move in the Game of Life Universe.
              INC tick            ; Next tick
              JSR delay           ; Small delay
              JSR delay           ; Small delay
              JSR delay           ; Small delay
              JSR delay           ; Small delay
              BRA MainLoop        ; Make it an infinite loop.

delay         LDY #$00            ; Loop 256*256 times...
              LDX #$00
dloop1        DEX
              BNE dloop1
              DEY
              BNE dloop1
              RTS

LifeToLED     LDA tick            ; Test which grid to print.
              AND #$01
              BNE load_grid2
              LDA #<Grid1         ; Load Grid1 to pointer.
              STA GridLow
              LDA #>Grid1
              STA GridHi
              BRA grid_loaded
load_grid2    LDA #<Grid2         ; Load Grid2 to pointer.
              STA GridLow
              LDA #>Grid2
              STA GridHi
grid_loaded   CLC                 ; Clear carry so we can add 27 to the grid address.
              LDA GridLow
              ADC #27             ; Add 27 bytes, that means we are on the second row, second column.
              STA GridLow
              BCC no_carry        ; If we got a carry, we need to increase the High byte.
              INC GridHi
no_carry      LDA #<GridData      ; Pointer to LED Grid
              STA LEDGridl
              LDA #>GridData
              STA LEDGridh
              LDA #$08            ; Count 8 bit per byte.
              STA count
              LDY #0              ; Start at second row in grid, one byte in.
              STY cols            ; Since it's zero, set offset in LED grid as well.
              LDX #24             ; We want to set 24 LEDs per row.
              STX row_counter
grid_loop2    LDA (GridLow),Y     ; Get byte in current grid.
              BEQ setDead         ; If, zero it's a dead cell.
              SEC
              JSR updateLedGrid
              BRA set_Done
setDead       CLC
              JSR updateLedGrid
set_Done      INY                 ; Next byte.
              DEX                 ; Count down column.
              BNE grid_loop2      ; Are we done with this row ?
              CLC                 ; Clear carry so we can add 26 to the grid address.
              LDA GridLow
              ADC #26             ; Add 26 bytes, that means we are on the next row, second column.
              STA GridLow
              BCC no_carry2       ; If we got a carry, we need to increase the High byte.
              INC GridHi
no_carry2     LDY #0              ; Reset Y
              LDX #24             ; Reset column bytes
              DEC row_counter
              BNE grid_loop2
              RTS

updateLedGrid ROL temp            ; Shift in LED.
              DEC count           ; 8 bits yet ?
              BNE ulgdone
              LDA #$08
              STA count           ; Reset counter
              STY temp2           ; Save Y
              LDY cols            ; Load offset in LED grid.
              LDA temp            ; Get LED data
              STA (LEDGridl),y    ; Store it in grid.
              INC cols            ; Increase offset.
              LDY temp2           ; Restore Y.
ulgdone       RTS


next_tick     LDA tick
              AND #$01
              BNE a_load_grid2
              LDA #<Grid1         ; Load Grid1 to pointer.
              STA GridLow
              LDA #>Grid1
              STA GridHi
              LDA #<Grid2         ; Load Grid2 to Work grid pointer.
              STA WorkGridLow
              LDA #>Grid2
              STA WorkGridHi
              BRA a_grid_loaded
a_load_grid2  LDA #<Grid2         ; Load Grid2 to pointer.
              STA GridLow
              LDA #>Grid2
              STA GridHi
              LDA #<Grid1         ; Load Grid1 to Work grid pointer.
              STA WorkGridLow
              LDA #>Grid1
              STA WorkGridHi
a_grid_loaded CLC                 ; We will count cells on Grid(Low/Hi) and put them on WorkGrid(Low/Hi).
              LDA WorkGridLow
              ADC #27             ; Add 27 bytes, that means we are on the second row, second column.
              STA WorkGridLow
              BCC a_no_carry      ; If we got a carry, we need to increase the High byte.
              INC WorkGridHi
a_no_carry    LDX #24             ; We want to scan 24 rows
              STX row_counter
grid_loop     JSR count_hood      ; Count neighbours.
              LDY #0              ; Zero Y
              LDA cell_count      ; Get result
              CMP #02             ; Two cells ?
              BCC cell_dies       ; Less than two, cell dies.
              CMP #3              ; Three cells ?
              BEQ cell_birth      ; Three cells will come a life or stay alive, just put one there.
              BCS cell_dies       ; If more than 3 cells, it dies.
              LDY #27             ; We have two cells alive, copy cell from Grid(Low/Hi).
              LDA (GridLow),Y     ; Got the cell
              LDY #0              ; Form pos 27 on Grid(*) to WorkGrid(*).
              STA (WorkGridLow),Y ; Store cell.
              BRA cell_count_done ; Continue on...
cell_dies     LDA #0              ; Cell dies, A = 0
              STA (WorkGridLow),Y ; Store cell.
              BRA cell_count_done ; Continue on...
cell_birth    LDA #1              ; Cell was born, A = 1
              STA (WorkGridLow),Y ; Store cell.
cell_count_done
              INC WorkGridLow     ; Next position
              BNE a_no_inc1
              INC WorkGridHi
a_no_inc1     INC GridLow         ; Next position
              BNE a_no_inc2
              INC GridHi
a_no_inc2     DEX                 ; Next col.
              BNE grid_loop       ; Row not done, continue.
              LDX #24             ; Reset col counter.
              INC WorkGridLow     ; Next position, for each row we have to move Two spaces.
              BNE a_no_inc3
              INC WorkGridHi
a_no_inc3     INC GridLow         ; Next position 1 Grid
              BNE a_no_inc4
              INC GridHi
a_no_inc4     INC WorkGridLow     ; Next position 2 WorkGrid
              BNE a_no_inc5
              INC WorkGridHi
a_no_inc5     INC GridLow         ; Next position 2 Grid
              BNE a_no_inc6
              INC GridHi
a_no_inc6     DEC row_counter     ; Next row.
              BNE grid_loop       ; Row not done, continue.
              RTS

count_hood    LDY #0
              STY cell_count      ; Zero cell count.
              LDA (GridLow),Y     ; Y=0, neighbour top left.
              BEQ b_no_add1
              INC cell_count
b_no_add1     LDY #1
              LDA (GridLow),Y     ; Y=1, neighbour top middle.
              BEQ b_no_add2
              INC cell_count
b_no_add2     LDY #2
              LDA (GridLow),Y     ; Y=2, neighbour top right.
              BEQ b_no_add3
              INC cell_count
b_no_add3     LDY #26
              LDA (GridLow),Y     ; Y=26, neighbour to the left.
              BEQ b_no_add4
              INC cell_count
b_no_add4     LDY #28
              LDA (GridLow),Y     ; Y=28, neighbour to the right.
              BEQ b_no_add5
              INC cell_count
b_no_add5     LDY #52
              LDA (GridLow),Y     ; Y=52, neighbour to the bottom left.
              BEQ b_no_add6
              INC cell_count
b_no_add6     LDY #53
              LDA (GridLow),Y     ; Y=53, neighbour to the bottom middle.
              BEQ b_no_add7
              INC cell_count
b_no_add7     LDY #54
              LDA (GridLow),Y     ; Y=53, neighbour to the bottom middle.
              BEQ b_no_add8
              INC cell_count
b_no_add8     RTS

showGridData
              LDA #<GridData
              STA LEDGridl
              LDA #>GridData
              STA LEDGridh
              LDY #1              ; Start with row 1
              STY rows
              LDY #8
              STY count           ; Count 8 rows

sgdloop1      LDX rows            ; Row to X
              STX add             ; Store in address
              STX temp            ; Prepare to multiply by three
              CLC
              ROL temp
              LDA rows
              ADC temp
              ADC #47
              TAY                 ; Y=(row*3) + 47, this is 9:th chars row.
              LDX #3              ; do three chars
              STX temp2           ; three times = 9 chars.

c_loop1       LDA (LEDGridl),y
              STA dat
              JSR SendData
              DEY                 ; point to previous chars byte.
              DEX                 ; Three chars ?
              BNE c_loop1
              TYA
              SEC
              SBC #21
              TAY                 ; Y = Y - 21, move back 3 chars and compensate for the three rows already done.
              LDX #3              ; Three more chars to go.
              DEC temp2           ; did we do all 9 chars ?
              BNE c_loop1

              JSR LatchData

              INC rows            ; Next row
              DEC count           ; Did we do them all ?
              BNE sgdloop1        ; Nope, recalculate etc...
              RTS

init_VIA      LDA #$FF            ; Make port A output.
              STA VIA_DDRA
              LDA #$00            ; Make ports low.
              STA VIA_IOA
              LDA VIA_ACR         ; Load ACR
              AND #$E3            ; Zero bit 4,3,2.
              ORA #$18            ; Shift out using Phi2
              STA VIA_ACR
              RTS

init_max7219  LDA #10             ; Intensity address
              STA add
              LDA #10             ; 10 out of 15
              STA dat
              JSR SendAllUnits
              JSR LatchData

              LDA #11             ; Scan limits (How many rows)
              STA add
              LDA #7              ; All 8 rows
              STA dat
              JSR SendAllUnits
              JSR LatchData

              LDA #9              ; Decode mode
              STA add
              LDA #0              ; No decoding, use all 8 bits as data
              STA dat
              JSR SendAllUnits
              JSR LatchData

              LDA #12             ; Shutdown register
              STA add
              LDA #1              ; No shutdown, normal operation
              STA dat
              JSR SendAllUnits
              JSR LatchData
              RTS

SendAllUnits  LDY units           ; Send same data to all units
sauloop       JSR SendData
              DEY
              BNE sauloop
              RTS

SendData      LDA add             ; Address for MAX7219
              STA VIA_SR          ; Shift it...
d_wait1       LDA VIA_IFR         ; Are we done yet ?
              AND #$04
              BEQ d_wait1         ; Nope, continue...
              LDA dat             ; Data for MAX7219
              STA VIA_SR          ; Shift it...
d_wait2       LDA VIA_IFR         ; Are we done yet ?
              AND #$04
              BEQ d_wait2         ; Nope, continue...
              RTS

LatchData     LDA #$01            ; Set Pin PA0 high
              STA VIA_IOA         ; This will load the data...
              LDA #$00            ; Set Pin PA0 Low
              STA VIA_IOA         ; Done loading the data, ready for more...
              RTS

 ENDS

; Put in data segment.
 DATA

GridData
      BYTE $7E, $00, $00 ; 1
      BYTE $7E, $00, $00 ; 2
      BYTE $66, $00, $00 ; 3
      BYTE $66, $3C, $00 ; 4
      BYTE $0C, $3C, $00 ; 5
      BYTE $0C, $66, $00 ; 6
      BYTE $18, $66, $00 ; 7
      BYTE $18, $66, $3C ; 8
      BYTE $18, $66, $3C ; 9
      BYTE $18, $3C, $66 ; 10
      BYTE $18, $3C, $66 ; 11
      BYTE $18, $66, $66 ; 12
      BYTE $18, $66, $66 ; 13
      BYTE $18, $66, $3E ; 14
      BYTE $00, $66, $3E ; 15
      BYTE $00, $3C, $06 ; 16
      BYTE $00, $3C, $06 ; 17
      BYTE $00, $00, $66 ; 18
      BYTE $00, $00, $66 ; 19
      BYTE $00, $00, $3C ; 20
      BYTE $00, $00, $3C ; 21
      BYTE $11, $00, $00 ; 22
      BYTE $00, $11, $00 ; 23
      BYTE $00, $00, $11 ; 24

;      .org $1300      ; For Debug

Grid1      BYTE 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; 1
      BYTE 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; 2
      BYTE 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; 3
      BYTE 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; 4
      BYTE 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; 5
      BYTE 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; 6
      BYTE 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; 7
      BYTE 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; 8
      BYTE 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; 9
      BYTE 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; 10
      BYTE 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; 11
      BYTE 0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0 ; 12
      BYTE 0,0,0,0,0,0,0,0,0,1,0,1,1,1,1,0,1,0,0,0,0,0,0,0,0,0 ; 13
      BYTE 0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0 ; 14
      BYTE 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; 15
      BYTE 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; 16
      BYTE 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; 17
      BYTE 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; 18
      BYTE 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; 19
      BYTE 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; 20
      BYTE 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; 21
      BYTE 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; 22
      BYTE 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; 23
      BYTE 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; 24
      BYTE 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; 25
      BYTE 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; 26

;      .org $1600      ; For Debug

Grid2      BYTE 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; 1
      BYTE 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; 2
      BYTE 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; 3
      BYTE 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; 4
      BYTE 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; 5
      BYTE 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; 6
      BYTE 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; 7
      BYTE 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; 8
      BYTE 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; 9
      BYTE 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; 10
      BYTE 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; 11
      BYTE 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; 12
      BYTE 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; 13
      BYTE 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; 14
      BYTE 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; 15
      BYTE 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; 16
      BYTE 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; 17
      BYTE 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; 18
      BYTE 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; 19
      BYTE 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; 20
      BYTE 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; 21
      BYTE 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; 22
      BYTE 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; 23
      BYTE 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; 24
      BYTE 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; 25
      BYTE 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; 26


 ENDS



; Standard stuff to make compiler and Debug work...

  ; Back in code segment.
 CODE
      ;;-------------------------------------------------------------------------
      ;; FUNCTION NAME	: Event Hander re-vectors
      ;;------------------:------------------------------------------------------
      	IRQHandler:
      		pha
      		pla
      		rti

      badVec:		; $FFE0 - IRQRVD2(134)
      	php
      	pha
      	lda #$FF
      				;clear Irq
      	pla
      	plp
      	rti
      		;;-----------------------------
      		;;
      		;;		Reset and Interrupt Vectors (define for 265, 816/02 are subsets)
      		;;
      		;;-----------------------------

 ENDS

Shadow_VECTORS	SECTION OFFSET $7EE0
      					;65C816 Interrupt Vectors
      					;Status bit E = 0 (Native mode, 16 bit mode)
      		dw	badVec		; $FFE0 - IRQRVD4(816)
      		dw	badVec		; $FFE2 - IRQRVD5(816)
      		dw	badVec		; $FFE4 - COP(816)
      		dw	badVec		; $FFE6 - BRK(816)
      		dw	badVec		; $FFE8 - ABORT(816)
      		dw	badVec		; $FFEA - NMI(816)
      		dw	badVec		; $FFEC - IRQRVD(816)
      		dw	badVec		; $FFEE - IRQ(816)
      					;Status bit E = 1 (Emulation mode, 8 bit mode)
      		dw	badVec		; $FFF0 - IRQRVD2(8 bit Emulation)(IRQRVD(265))
      		dw	badVec		; $FFF2 - IRQRVD1(8 bit Emulation)(IRQRVD(265))
      		dw	badVec		; $FFF4 - COP(8 bit Emulation)
      		dw	badVec		; $FFF6 - IRQRVD0(8 bit Emulation)(IRQRVD(265))
      		dw	badVec		; $FFF8 - ABORT(8 bit Emulation)

      					; Common 8 bit Vectors for all CPUs
      		dw	badVec		; $FFFA -  NMIRQ (ALL)
      		dw	START		; $FFFC -  RESET (ALL)
      		dw	IRQHandler	; $FFFE -  IRQBRK (ALL)

 ends

vectors	SECTION OFFSET $FFE0
      					;65C816 Interrupt Vectors
      					;Status bit E = 0 (Native mode, 16 bit mode)
      		dw	badVec		; $FFE0 - IRQRVD4(816)
      		dw	badVec		; $FFE2 - IRQRVD5(816)
      		dw	badVec		; $FFE4 - COP(816)
      		dw	badVec		; $FFE6 - BRK(816)
      		dw	badVec		; $FFE8 - ABORT(816)
      		dw	badVec		; $FFEA - NMI(816)
      		dw	badVec		; $FFEC - IRQRVD(816)
      		dw	badVec		; $FFEE - IRQ(816)
      					;Status bit E = 1 (Emulation mode, 8 bit mode)
      		dw	badVec		; $FFF0 - IRQRVD2(8 bit Emulation)(IRQRVD(265))
      		dw	badVec		; $FFF2 - IRQRVD1(8 bit Emulation)(IRQRVD(265))
      		dw	badVec		; $FFF4 - COP(8 bit Emulation)
      		dw	badVec		; $FFF6 - IRQRVD0(8 bit Emulation)(IRQRVD(265))
      		dw	badVec		; $FFF8 - ABORT(8 bit Emulation)

      					; Common 8 bit Vectors for all CPUs
      		dw	badVec		; $FFFA -  NMIRQ (ALL)
      		dw	START		; $FFFC -  RESET (ALL)
      		dw	IRQHandler	; $FFFE -  IRQBRK (ALL)

 ends
