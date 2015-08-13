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
  VideoPins  = 12
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
DAT

tvCursorOn    byte true
  tvForeColor   byte 7                                                          'Composite color value index
  tvBackcolor   byte 0
cursor        byte 3
'cursors       byte %000, %001, %101, %010, %110, %011, %111
'terminalModes byte text#SET_DECAWM
VAR
  Byte Index
  Byte Rx                        
  Word key
  Byte keystep
  Byte rxbyte
  Long Stack[300],stack1[300],stack2[300]
  Byte temp
  Byte ascii
  Byte keyinuse
  Byte serdata
  Byte strobe
  Byte BS
OBJ
'  VideoDisplay: "char_mode_09"   
  Serport: "Serial_IO"
  kb: "keyboard"
  VideoDisplay:   "aigeneric_driver"
PUB   main                                       'Main startup and video handler                

  BS := 0                                        ' Standard Backspace mode emulating apple 1 = 0 or working BS = 1
  cognew(@INVERSE, 0)
  dira[CLK0]~~                                          ' Set CLK0 pin to output for Phase 0 clock 
  ctra := %00100_000 << 23 + 1 << 9 + CLK0              ' Calculate frequency setting
  frqa := $333_0000                                     ' Set FRQA so PHSA[31]
  VideoDisplay.Start(videopins)
  VideoDisplay.Out(VideoCls)                     'Clear screen

'display garbage screen
  VideoDisplay.str(string("0.3 "))
  VideoDisplay.fill
  Serport.startx(RX_Pin, TX_Pin, BaudRate)       'Start Serial Port, set baud, pins, etc
  kb.startx(26, 27, NUM+CAPS, RepeatRate)        'Start Keyboard Driver, set Caps lock
  DIRA[23..16]~                                  'Set ASCII keyboard port as input 
  DIRA[8]~~                                      'Set P8 as output pin to RDA signal 
  cognew (ps2 , @stack1)
  cognew (blink , @Stack)
  cognew (serial, @stack2)    
  Repeat
      TEMP := INA[9]
      IF TEMP >> 0                               ' IS CLEAR BUTTON PRESSED?
        VideoDisplay.cls
        repeat until INA[9] == 0
          temp := 0
      OUTA[8]~~                                  'Turn on P8 to recieve video data (to RDA)
      PAUSEMS(12)
      temp := INA[7]                             'Read DA signal from 6821
      
      if temp >> 0                               'Is there data out there?
          temp :=INA[6..0]                       'Yes, get video data
          if temp > 126
            temp := 0
          !OUTA[8]                               'Turn off RDA signal
          'PauseMS(6)                            'Pause 12ms   was 6
          if temp == 95                          ' Is it _ backspace character?
             case BS
                $00   :  'no change
                $01   :  temp := 08
                         VideoDisplay.Outcursor(32)
                         VideoDisplay.out(temp)  
          if temp == 13                          'Is data a Carriage Return (CR)?
             VideoDisplay.Outcursor(32)          'yes, remove cursor with a blank so it won't shadow
             Serport.out(10)
          if temp > 31 or temp == 13             'is character Apple 1 style?
             VideoDisplay.Out(temp)              'Yes, send it to TV output
             VideoDisplay.Outcursor(64)          'Set the new cursor
          Serport.out(temp)                   'Send it out serial port
    

PUB ps2                                          'PS/2 Keyboard COG
'9-18 REM'd OUTA 25 all lines
  DIRA[23..16]~                                  'Make Keyboard port ASCII ready                                                  
  DIRA[25]~~                                     'Set buffer pin to OUTPUT
'  OUTA[25]~                                      'Turn buffer on for ASCII keyboard
  Repeat
      repeat until INA[24] == 0
        dira[25]~
      dira[25]~~
      key := kb.getkey                           'Go get keystroke, then return here
      if key == 196                              ' PS/2 keyboard CLS
        VideoDisplay.out(0)                      ' Clear screen
      if key > 576 and key < 603                 ' ctrl A-Z
        key:= key - 576
      'debug code
      'VideoDisplay.dec(key)                             'send value of character
      if key == 720
         key := 0
         case BS
           $00   :   BS := 1
                     'videodisplay.dec(0)
           $01   :   BS := 0
                     'videodisplay.dec(1)
      if key == 200
        key := 95                     
      if key >> 94
         key := 0                 
      DIRA[23..16]~~                             'Set pins to output ASCII code
      OUTA[23]~                                  'Make sure STROBE signal is off             
      if key == 203                              'Is it upper code for ESC key?
          key:= 27                               'Yes, convert to standard ASCII value
      if key << 96                                 'Is the keystroke Apple 1 compatible?
          outa[22..16]:= key                     'Yes, send the 7 bit code
          outa[23]~~                             'Set strobe high
          PauseMS(10)                            'Pause long enough to register as a keystroke   was 20
          outa[23]~                              'Ok, turn off strobe bit
      DIRA[23..16]~                              'Set pins back to ASCII keyboard ready
'      OUTA[25]~                                  'Set buffer to accept ASCII keyboard input
      OUTA[23]~

        
PUB blink                                        'Blinking '@' Cursor COG

  repeat
      VideoDisplay.Outcursor(64)
      PauseMS(250)
      VideoDisplay.Outcursor(32)
      PauseMS(250)

PUB serial                                       'Serial INPUT COG
' 9-18 remd all outa 25 lines
  DIRA[23..16]~
  DIRA[25]~~
'  OUTA[25]~
  repeat          
      serdata:= Serport.in                      'Get data from serial port, wait until received
'      OUTA[25]~~
      DIRA[23..16]~~
      OUTA[23]~
      if serdata < 96
          OUTA[22..16]:= serdata                 'send data to keyboard port on 6821       
          OUTA[23]~~                             'set strobe
          PauseMS(20)
          'PauseMS(7)                            'pause for strobe effect WAS 20
          OUTA[23]~          
      DIRA[23..16]~
'      OUTA[25]~
      OUTA[23]~ 
                           
PRI PauseMs( mS )

  waitcnt( ( clkfreq / 1000 ) * mS + cnt )
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
                       