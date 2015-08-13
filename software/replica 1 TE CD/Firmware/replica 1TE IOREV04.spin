''    replica 1 TE I/O controller by Briel Computers
''
''    version 3.01  FIRST INITIAL TEST
''    version 3.02  FIX FOR WHEN ASCII NOT ATTACHED, NO GHOST DATA
''    version 3.03  COLOR FIX FOR TRUE B&W
''    version 3.04  FIX CTRL CODES TO WORK
''    
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
  BaudRate   = 2_400
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


OBJ
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
OBJ
  VideoDisplay: "char_mode_08"   
  Serport: "Serial_IO"
  'kb: "keyboard"
 
PUB   main                                       'Main startup and video handler                
  
  VideoDisplay.Start                             'Start Video Driver
  VideoDisplay.Out(VideoCls)                     'Clear screen
  Serport.startx(RX_Pin, TX_Pin, BaudRate)       'Start Serial Port, set baud, pins, etc
  'kb.startx(26, 27, NUM+CAPS, RepeatRate)        'Start Keyboard Driver, set Caps lock
  DIRA[23..16]~                                  'Set ASCII keyboard port as input 
  DIRA[25]~~                                     'Set ASCII buffer pin as output
  DIRA[8]~~                                      'Set P8 as output pin to RDA signal 
  'cognew (ps2 , @stack1)
  cognew (blink , @Stack)
  cognew (serial, @stack2)
      
  Repeat
      OUTA[8]~~                                  'Turn on P8 to recieve video data (to RDA)
      temp := INA[7]                             'Read DA signal from 6821
      if temp >> 0                               'Is there data out there?
          temp :=INA[6..0]                       'Yes, get video data
          !OUTA[8]                               'Turn off RDA signal
          PauseMS(12)                            'Pause 12ms        
          if temp == 13                          'Is data a Carriage Return (CR)?
             VideoDisplay.Outcursor(32)          'yes, remove cursor with a blank so it won't shadow
          if temp > 31 or temp == 13             'is character Apple 1 style?
             VideoDisplay.Out(temp)              'Yes, send it to TV output
             VideoDisplay.Outcursor(64)          'Set the new cursor
          Serport.out(temp)                   'Send it out serial port          
{-
PUB ps2                                          'PS/2 Keyboard COG

  DIRA[23..16]~                                  'Make Keyboard port ASCII ready                                                  
  DIRA[25]~~                                     'Set buffer pin to OUTPUT
  OUTA[25]~                                      'Turn buffer on for ASCII keyboard
  Repeat
      key := kb.getkey                           'Go get keystroke, then return here
      if key > 576 and key < 603                        'ctrl A-Z
        key:= key - 576
      'debug code
      'VideoDisplay.dec(key)                             'send value of character
      
      OUTA[25]~~                                 'Turn off buffer for ASCII keyboard
      DIRA[23..16]~~                             'Set pins to output ASCII code
      OUTA[23]~                                  'Make sure STROBE signal is off             
      if key == 203                              'Is it upper code for ESC key?
          key:= 27                               'Yes, convert to standard ASCII value
      if key <96                                 'Is the keystroke Apple 1 compatible?
          outa[22..16]:= key                     'Yes, send the 7 bit code
          outa[23]~~                             'Set strobe high
          PauseMS(20)                            'Pause long enough to register as a keystroke
          'outa[23]~                              'Ok, turn off strobe bit
      DIRA[23..16]~                              'Set pins back to ASCII keyboard ready
      OUTA[25]~                                  'Set buffer to accept ASCII keyboard input
      OUTA[23]~
-}
      
PUB blink                                        'Blinking '@' Cursor COG

  repeat
      VideoDisplay.Outcursor(64)
      PauseMS(250)
      VideoDisplay.Outcursor(32)
      PauseMS(250)

PUB serial                                       'Serial INPUT COG    
  DIRA[23..16]~
  DIRA[25]~~
  OUTA[25]~
  repeat          
      serdata:= Serport.in                      'Get data from serial port, wait until received
      OUTA[25]~~
      DIRA[23..16]~~
      OUTA[23]~
      if serdata < 96
          OUTA[22..16]:= serdata                 'send data to keyboard port on 6821       
          OUTA[23]~~                             'set strobe
          PauseMS(20)                            'pause for strobe effect           
      DIRA[23..16]~
      OUTA[25]~
      OUTA[23]~ 
                           
PRI PauseMs( mS )

  waitcnt( ( clkfreq / 1000 ) * mS + cnt )
                