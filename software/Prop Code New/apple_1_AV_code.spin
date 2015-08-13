''    replica 1 TEN I/O controller by Briel Computers
''
''    TE-110 update includes 1MHz signal on pin P15 (pin 20 physical)
''    Added 2 pin inverter code to eliminate 74LS04 from previous design
''    Added jumper for PS/2 disable if high
''    Added code to CLS if pin P24 goes high
''    Added code so if HOME is pressed, backspace does _ out but screen does backspace!
''    Keyboard setup so ASCII will be jumpered if enabled
''    changed BAUD rate to 9600
''    As of July 3, 2008 only NTSC is available

''    
''    Idendify port pins below
''    P0-P6 are Video Data Bus pins
''    P7 is Data Available from 6821 letting you know there is data
''    P8 is Ready Data Available letting 6821 know you can receive
''    P12-P14 Video port
''    P16-23 is keyboard data out to 6821 P23 is Strobe bit
''    P25 is ASCII keyboard buffer pin
''
''****************************************************************    
CON
  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000
'
  RX_Pin     = 31
  TX_Pin     = 30                                          
  Out        = %1
  Low        = 0
  High       = 1
  CR         = 13
  LF         = 10
  BaudRate   = 9_600
  VideoPins  = 13
  VideoCls   = 0
  NUM        = %100
  CAPS       = %010
  SCROLL     = %001
  RepeatRate = 40
'Set emulation type for pin configuration
   Demo      = true                    ' Demo Board
   Proto     = false                   ' Proto Board
   Hydra     = false                   ' Hydra

'  dspPins   = (Hydra & 24) | ((Demo | Proto) & 12)   ' TV
   dspPins   = 16                                     ' VGA
   keyPins   = (Hydra & 13) | ((Demo | Proto) & 26)
   spiDO     = (Hydra & 16) | (Demo & 0) | (Proto & 8)
   spiClk    = (Hydra & 17) | (Demo & 1) | (Proto & 9)
   spiDI     = (Hydra & 18) | (Demo & 2) | (Proto & 10)
   spiCS     = (Hydra & 19) | (Demo & 3) | (Proto & 11)

   CLK0      = 15 'Pin P15 (physical 20) is the Phase 0 clock to drive the 6502
   revision  = 2
   zero      = 0

   clockOut     = 25
   latchOut     = 24
   columnOut    = 26
   rowIn        = 27

   
DAT

tvCursorOn    byte true
  tvForeColor   byte 7                                                          'Composite color value index
  tvBackcolor   byte 2
cursor        byte 3
'cursors       byte %000, %001, %101, %010, %110, %011, %111
'terminalModes byte text#SET_DECAWM
VAR
  Byte Index
  Byte Rx                        
  Word key
  Byte keystep
  Byte rxbyte
  Long stack0[300], stack1[300]
  Byte temp
  Byte ascii
  Byte keyinuse
  Byte serdata
  Byte strobe
  Byte BS

  word cursorBlink

  word rowState
  word columnSelect
  word check

  byte debounce[56]
  
OBJ
'  VideoDisplay: "char_mode_09"   
  Serport: "Serial_IO"
  VideoDisplay:   "aigeneric_driver"

PUB   main | te,p                                       'Main startup and video handler                

  BS := 0                                        ' Standard Backspace mode emulating apple 1 = 0 or working BS = 1
    
  VideoDisplay.Start(videopins)
  VideoDisplay.Out(VideoCls)                     'Clear screen
  'VideoDisplay.Color($0F00)
   
  Serport.startx(RX_Pin, TX_Pin, BaudRate)       'Start Serial Port, set baud, pins, etc

  DIRA[23..16]~
  DIRA[25]~~
  
  DIRA[8]~~                                      'Set P8 as output pin to RDA signal 

  'cognew (serial, @stack0)                              'Cog sits around looking for serial input data
  cognew (keyboard, @stack1)
 
  repeat

    outa[8]~~

    pauseMS(12)

    cursorBlink += 1

    if cursorBlink == 50
      VideoDisplay.Outcursor(64)
      
    if cursorBlink > 100
      VideoDisplay.Outcursor(32)
      cursorBlink := 0
    
    temp := ina[7]                             'Read DA signal from 6821

    if ina[7]                                           'Data on line?

      temp := ina[6..0]                                 'Get it

      if temp > 126
        temp := 0

      !outa[8]                                          'Turn off RDA signal                                           

      if temp == 95 and BS

        VideoDisplay.Outcursor(32)
        VideoDisplay.out(temp)          

      if temp == 13                          'Is data a Carriage Return (CR)?
         VideoDisplay.Outcursor(32)          'yes, remove cursor with a blank so it won't shadow
         Serport.out(10)
         
      if temp > 31 or temp == 13             'is character Apple 1 style?
         VideoDisplay.Out(temp)              'Yes, send it to TV output
         VideoDisplay.Outcursor(64)          'Set the new cursor
         
      '
       Serport.out(temp)                      'Send it out serial port


PUB serial | tempSer                                       'Serial INPUT COG

  repeat          

    tempSer := Serport.in

    if tempSer
  
      keyOut(tempSer)                                'If we get a key via serial, send it out


PUB keyOut(whatCharacter)                               'Types a characters into the Apple 1


  if whatCharacter > 96                                 'Lowercase to upper
    whatCharacter -= 32

  DIRA[23..16]~~
  OUTA[23]~

  OUTA[22..16]:= whatCharacter                          'send data to keyboard port on 6821
         
  OUTA[23]~~                                            'set strobe
  PauseMS(20)                                           '20 MS is a safe amount of time.
  OUTA[23]~
            
  DIRA[23..16]~
  OUTA[23]~ 



PUB keyboard | offset, g

  columnSelect := 0

  repeat


    check := (keyScan(1 << columnSelect) >> 8)
    
    
    'VideoDisplay.bin(check, 16)
    'VideoDisplay.out(13)     
    'VideoDisplay.bin(1 << columnSelect, 16)
    'VideoDisplay.out(13)

    'PauseMS(1)

    if check & %0100_0000                               'Look for SHIFT
    
      offset := 0
      
    else
    
      offset := 56
 
    if check & 8 and debounce[columnSelect] == 0                                       'Something on Row 1

      outputKey(characters[columnSelect + offset], check & %1000_0000)
      debounce[columnSelect] := 100

    if check & 4 and debounce[columnSelect + 14] == 0                                       'Something on Row 2
    
      outputKey(characters[columnSelect + 14 + offset], check & %1000_0000)
      debounce[columnSelect + 14] := 100
     
    if check & 2 and debounce[columnSelect + 28] == 0                                       'Something on Row 3
    
      outputKey(characters[columnSelect + 28 + offset], check & %1000_0000)    
      debounce[columnSelect + 28] := 100
            
    if check & 1 and debounce[columnSelect + 42] == 0                                       'Something on Row 4
    
      outputKey(characters[columnSelect + 42 + offset], check & %1000_0000)
      debounce[columnSelect + 42] := 100
            
    columnSelect += 1
     
    if columnSelect > 13
     
      columnSelect := 0

    repeat g from 0 to 55
     
      if debounce[g]
        debounce[g] -= 1

      


PUB outputKey(whatKey, control)

  if control == 0 and whatKey > 63                           'A control key character, and not gonna return a negative number?

    whatKey -= 64

  keyOut(whatKey)

    

PUB keyScan(whichColumn) | temp0, temp1

  temp0 := whichColumn '<< 1                               'Set active column
   
  dira[latchOut]~~
  dira[clockOut]~~
  dira[columnOut]~~
  dira[rowIn]~
   
  OUTA[latchOut]~                                                'Set latch...
  OUTA[clockOut]~                                                '... and clock to LOW to get started.
  OUTA[latchOut]~~                                               'Set latches HIGH to start. No change for the lights (registers should still be same as last cycle), brings up first bit of Sense
  OUTA[latchOut]~                                                'Reset latch for next time
   
  temp1 := 0                                           'Clear this

  repeat 16                       
   
    temp1 <<= 1                                           'Shift sense bits LEFT to allow next bit in for LSB    
    temp1 += ina[rowIn]                                      'Set LSB of Sense to the bit on the Sense input (0 or 1) 
   
    outa[columnOut] := temp0                                     'Set next LSB bit for Light0 OUT
   
    OUTA[clockOut]~~                                             'CLK input and output shift registers
    OUTA[clockOut]~                                              'Sends OUT light data, brings IN sense data, which we now check
   
    temp0 >>= 1                                           'Shift light bits RIGHT to put next one in LSB
   
    
  OUTA[latchOut]~~
  OUTA[latchOut]~                                         'Set latches to output light data (also re-latches input data but who cares?)
   
   
   
  return temp1



                          
PRI pauseMS(howManyMS)

  waitcnt( ( clkfreq / 1000 ) * howManyMS + cnt )



DAT

characters
        byte    "x1234567890-=", 95
        byte    "xQWERTYUIOP[]\"
        byte    "xASDFGHJKL;'", 13, 0
        byte    "xZXCVBNM,./x", 32, 0

        byte    "x1234567890_+", 8
        byte    "xQWERTYUIOP[]\"
        byte    "xASDFGHJKL:", 34, 13, 0
        byte    "xZXCVBNM<>?x", 32, 0

  
DAT

        org 0
INVERSE

mask_INV  LONG (|<11)            ' Inverter input pin
mask_INVO LONG (|<10)            ' Inverted pin out  \
shift     LONG 1                 ' number of positions to shift data
'temp      LONG 0
temp2     LONG 0
        mov  dira, mask_INVO     ' make px output pin
INVLOOP
        
        mov   temp2, INA
        xor   temp2, mask_INV    ' invert bit 10
        shr   temp2, shift       ' shift so bit 10 is moved to bit 9
        mov   OUTA, temp2
        jmp   #INVLOOP






                               