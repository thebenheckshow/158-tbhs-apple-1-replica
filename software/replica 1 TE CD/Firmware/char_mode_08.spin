{


Character mode TV Text driver, with font table   Rev 01

Doug Dingus  09/07

*********************************
* Character Mode TV Text Driver *   Adapted by Jeff Ledger
*********************************

I've adapted the routines from TV_Text to allow for drop-in compatibilty.
Even bin,hex,and dec have been moved and adapted.
I'm positive there are bugs, but it seems to work.

Modified by Vince Briel April 2008 for the replica 1 TE
Changed character font set to match 2513 character generator ROM
added cursor control so last character in bottom right cursor doesn't scroll

}

CON

  cols = 40
  rows = 24

  screensize = cols * rows
  lastrow = screensize - cols

  ' Set up the processor clock in the standard way for 80MHz on HYDRA
  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000

  
VAR

  long  col, row, color, flag
  
  word  screen[screensize]
  long  colors[8 * 2]

  byte          displayb[4096]   'allocate max display buffer in RAM  40x24 (longs)

  long          index            'just an index...

  long          params[4]
                '[0] screen memory
                '[1] font table
                '[2] pix_mode not yet implemented...
                '[3] colors, or 16 bit mode = $00
  
OBJ
  tv : "char_mode_08_TV"  'the TV display driver
  
PUB start |  c, o, d, p

    params[0] := @displayb
{
    Simple display buffer, one character per byte.  40x24 = 960 bytes, unless 16 bit mode is on
}
    
    params[1] := @fonttab
    
    params[2] := $0000_0000    'Not implemented....  This is going to be pixel sizes and such...
                               'see driver for possible values
  
    
    params[3] := $00000e0a    'uncomment for two color mode test
   ' params[3] := $00   'running in 16 bit mode

    tv.start(@params)    'start the tv cog & pass it the parameter block


PUB out(c) | i, k

'' Output a character
''
''     $00 = clear screen
''     $01 = home
''     $08 = backspace
''     $09 = tab (8 spaces per)
''     $0A = set X position (X follows)
''     $0B = set Y position (Y follows)
''     $0C = set color (color follows)
''     $0D = return
''  others = printable characters

  case flag
    $00: case c
           $00: wordfill(@displayb, $00, screensize)
                col := row := 0
           $01: col := row := 0
           $08: if col
                  col--
           $09: repeat
                  print(" ")
                while col & 7
           $0A..$0C: flag := c
                     return
           $0D: newline
           other: print(c)
    $0A: col := c // cols
    $0B: row := c // rows
    $0C: color := c & 7
  flag := 0

PUB outcursor(c) | i, k

'' Output a character
''
''     $00 = clear screen
''     $01 = home
''     $08 = backspace
''     $09 = tab (8 spaces per)
''     $0A = set X position (X follows)
''     $0B = set Y position (Y follows)
''     $0C = set color (color follows)
''     $0D = return
''  others = printable characters

  case flag
    $00: case c
           $00: wordfill(@displayb, $00, screensize)
                col := row := 0
           $01: col := row := 0
           $08: if col
                  col--
           $09: repeat
                  print(" ")
                while col & 7
           $0A..$0C: flag := c
                     return
           $0D: newline
           other: printcursor(c)
    $0A: col := c // cols
    $0B: row := c // rows
    $0C: color := c & 7
  flag := 0

PRI print(c)

  displayb[row * cols + col] :=  + c
  if ++col == cols
    newline

PRI printcursor(c)

  displayb[row * cols + col] :=  + c
  'if ++col == cols
   ' newline


PRI newline | i

  col := 0
  if ++row == rows
    row--
    wordmove(@displayb, @displayb[cols], lastrow)   'scroll lines
    wordfill(@displayb[lastrow], $00, cols)      'clear new line
    

PUB str(stringptr)

'' Print a zero-terminated string

  repeat strsize(stringptr)
    out(byte[stringptr++])


PUB dec(value) | i

'' Print a decimal number

  if value < 0
    -value
    out("-")

  i := 1_000_000_000

  repeat 10
    if value => i
      out(value / i + "0")
      value //= i
      result~~
    elseif result or i == 1
      out("0")
    i /= 10


PUB hex(value, digits)

'' Print a hexadecimal number

  value <<= (8 - digits) << 2
  repeat digits
    out(lookupz((value <-= 4) & $F : "0".."9", "A".."F"))


PUB bin(value, digits)

'' Print a binary number

  value <<= 32 - digits
  repeat digits
    out((value <-= 1) & 1 + "0")
    

    
DAT
              'font definition pixels are mirror image, due to the way waitvid works.
              'Atari 8 bit international font used here

              ' Re-arranged the characters for standard ASCII translation

              ' Currently all lowercase alphas and fonts marked "Updated"
              ' are correct in ASCII at this time.
        
fonttab
           byte byte %00000000   ' '       
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00000000             
                      
           byte byte %00000000   '!'       
           byte byte %00011000             
           byte byte %00011000             
           byte byte %00011000             
           byte byte %00011000             
           byte byte %00000000             
           byte byte %00011000             
           byte byte %00000000             
                      
           byte byte %00000000   '"'       
           byte byte %01100110             
           byte byte %01100110             
           byte byte %01100110             
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00000000             
                       
           byte byte %00000000   '         
           byte byte %01100110             
           byte byte %11111111             
           byte byte %01100110             
           byte byte %01100110             
           byte byte %11111111             
           byte byte %01100110             
           byte byte %00000000             
                       
           byte byte %00011000   '$'       
           byte byte %01111100             
           byte byte %00000110             
           byte byte %00111100             
           byte byte %01100000             
           byte byte %00111110             
           byte byte %00011000             
           byte byte %00000000             
                       
           byte byte %00000000   '%'       
           byte byte %01100110             
           byte byte %00110110             
           byte byte %00011000             
           byte byte %00001100             
           byte byte %01100110             
           byte byte %01100010             
           byte byte %00000000             
                       
           byte byte %00111000   '&'       
           byte byte %01101100             
           byte byte %00111000             
           byte byte %00011100             
           byte byte %11110110             
           byte byte %01100110             
           byte byte %11011100             
           byte byte %00000000             
                       
           byte byte %00000000   '''       
           byte byte %00011000             
           byte byte %00011000             
           byte byte %00011000             
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00000000             
                       
           byte byte %00000000   '('       
           byte byte %01110000             
           byte byte %00111000             
           byte byte %00011000             
           byte byte %00011000             
           byte byte %00111000             
           byte byte %01110000             
           byte byte %00000000             
                      
           byte byte %00000000   ')'       
           byte byte %00001110             
           byte byte %00011100             
           byte byte %00011000             
           byte byte %00011000             
           byte byte %00011100             
           byte byte %00001110             
           byte byte %00000000             
                       
           byte byte %00000000   'Updated to Linefeed BLANK'       
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00000000             
                       
           byte byte %00000000   '+'       
           byte byte %00011000             
           byte byte %00011000             
           byte byte %01111110             
           byte byte %00011000             
           byte byte %00011000             
           byte byte %00000000             
           byte byte %00000000             
                       
           byte byte %00000000   ','       
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00011000             
           byte byte %00011000             
           byte byte %00001100             
                       
           byte byte %00000000   'Updated to Carriage Return BLANK'       
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00000000             
                       
           byte byte %00000000   '.'       
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00011000             
           byte byte %00011000             
           byte byte %00000000             
                       
           byte byte %00000000   '/'       
           byte byte %01100000             
           byte byte %00110000             
           byte byte %00011000             
           byte byte %00001100             
           byte byte %00000110             
           byte byte %00000010             
           byte byte %00000000             
                       
           byte byte %00000000   '0'       
           byte byte %00111100             
           byte byte %01100110             
           byte byte %01110110             
           byte byte %01101110             
           byte byte %01100110             
           byte byte %00111100             
           byte byte %00000000             
                       
           byte byte %00000000   '1'       
           byte byte %00011000             
           byte byte %00011100             
           byte byte %00011000             
           byte byte %00011000             
           byte byte %00011000             
           byte byte %01111110             
           byte byte %00000000             
                       
           byte byte %00000000   '2'       
           byte byte %00111100             
           byte byte %01100110             
           byte byte %00110000             
           byte byte %00011000             
           byte byte %00001100             
           byte byte %01111110             
           byte byte %00000000             
                       
           byte byte %00000000   '3'       
           byte byte %01111110             
           byte byte %00110000             
           byte byte %00011000             
           byte byte %00110000             
           byte byte %01100110             
           byte byte %00111100             
           byte byte %00000000             
                       
           byte byte %00000000   '4'       
           byte byte %00110000             
           byte byte %00111000             
           byte byte %00111100             
           byte byte %00110110             
           byte byte %01111110             
           byte byte %00110000             
           byte byte %00000000             
                       
           byte byte %00000000   '5'       
           byte byte %01111110             
           byte byte %00000110             
           byte byte %00111110             
           byte byte %01100000             
           byte byte %01100110             
           byte byte %00111100             
           byte byte %00000000             
                       
           byte byte %00000000   '6'       
           byte byte %00111100             
           byte byte %00000110             
           byte byte %00111110             
           byte byte %01100110             
           byte byte %01100110             
           byte byte %00111100             
           byte byte %00000000             
                       
           byte byte %00000000   '7'       
           byte byte %01111110             
           byte byte %01100000             
           byte byte %00110000             
           byte byte %00011000             
           byte byte %00001100             
           byte byte %00001100             
           byte byte %00000000             
                       
           byte byte %00000000   '8'       
           byte byte %00111100             
           byte byte %01100110             
           byte byte %00111100             
           byte byte %01100110             
           byte byte %01100110             
           byte byte %00111100             
           byte byte %00000000             
                       
           byte byte %00000000   '9'       
           byte byte %00111100             
           byte byte %01100110             
           byte byte %01111100             
           byte byte %01100000             
           byte byte %00110000             
           byte byte %00011100             
           byte byte %00000000             
                       
           byte byte %00000000   ':'       
           byte byte %00000000             
           byte byte %00011000             
           byte byte %00011000             
           byte byte %00000000             
           byte byte %00011000             
           byte byte %00011000             
           byte byte %00000000             
                       
           byte byte %00000000   '''       
           byte byte %00000000             
           byte byte %00011000             
           byte byte %00011000             
           byte byte %00000000             
           byte byte %00011000             
           byte byte %00011000             
           byte byte %00001100             
                       
           byte byte %01100000   '<'       
           byte byte %00110000             
           byte byte %00011000             
           byte byte %00001100             
           byte byte %00011000             
           byte byte %00110000             
           byte byte %01100000             
           byte byte %00000000             
                       
           byte byte %00000000   '='       
           byte byte %00000000             
           byte byte %01111110             
           byte byte %00000000             
           byte byte %00000000             
           byte byte %01111110             
           byte byte %00000000             
           byte byte %00000000             
                       
           byte byte %00000110   '>'       
           byte byte %00001100             
           byte byte %00011000             
           byte byte %00110000             
           byte byte %00011000             
           byte byte %00001100             
           byte byte %00000110             
           byte byte %00000000             
                       
           byte byte %00000000   '?'       
           byte byte %00111100             
           byte byte %01100110             
           byte byte %00110000             
           byte byte %00011000             
           byte byte %00000000             
           byte byte %00011000             
           byte byte %00000000             
                       
           byte byte %00000000   'Updated space '       
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00000000              
                       
           byte byte %00000000   'r1 te Updated !'       
           byte byte %00000100             
           byte byte %00000100             
           byte byte %00000100             
           byte byte %00000100             
           byte byte %00000100             
           byte byte %00000000             
           byte byte %00000100              
                       
           byte byte %00000000   'r1 te Updated "'       
           byte byte %00001010             
           byte byte %00001010             
           byte byte %00001010             
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00000000             
                       
           byte byte %00000000   'r1 te Updated #         
           byte byte %00001010             
           byte byte %00001010             
           byte byte %00011111             
           byte byte %00001010             
           byte byte %00011111             
           byte byte %00001010             
           byte byte %00001010              
                       
           byte byte %00000000   'r1 te Updated $'       
           byte byte %00000100             
           byte byte %00011110             
           byte byte %00000101             
           byte byte %00001110             
           byte byte %00010100             
           byte byte %00001111             
           byte byte %00000100             
                       
           byte byte %00000000   'r1 te Updated %'       
           byte byte %00000011             
           byte byte %00010011             
           byte byte %00001000             
           byte byte %00000100             
           byte byte %00000010             
           byte byte %00011001             
           byte byte %00011000             
                       
           byte byte %00000000   'r1 te Updated &'       
           byte byte %00000010             
           byte byte %00000101             
           byte byte %00000101             
           byte byte %00000010             
           byte byte %00010101             
           byte byte %00001001             
           byte byte %00010110             
                       
           byte byte %00000000   'r1 te Updated ''       
           byte byte %00000100             
           byte byte %00000100             
           byte byte %00000100             
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00000000             
                       
           byte byte %00000000   'r1 te Updated ('       
           byte byte %00000100             
           byte byte %00000010             
           byte byte %00000001             
           byte byte %00000001             
           byte byte %00000001            
           byte byte %00000010             
           byte byte %00000100             
                      
           byte byte %00000000   'r1 te Updated )'       
           byte byte %00000100             
           byte byte %00001000             
           byte byte %00010000             
           byte byte %00010000             
           byte byte %00010000             
           byte byte %00001000             
           byte byte %00000100             
                       
           byte byte %00000000   'r1 te Updated *'       
           byte byte %00000100             
           byte byte %00010101             
           byte byte %00001110             
           byte byte %00000100             
           byte byte %00001110             
           byte byte %00010101             
           byte byte %00000100              
                       
           byte byte %00000000   'r1 te Updated +'       
           byte byte %00000000             
           byte byte %00000100             
           byte byte %00000100             
           byte byte %00011111             
           byte byte %00000100             
           byte byte %00000100             
           byte byte %00000000             
                       
           byte byte %00000000   'r1 te Updated ,'       
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00000100             
           byte byte %00000100             
           byte byte %00000010               
                       
           byte byte %00000000   'r1 te Updated -'       
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00011111             
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00000000             
                       
           byte byte %00000000   'r1 te Updated .'       
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00000100              
                       
           byte byte %00000000   'r1 te Updated /'       
           byte byte %00000000             
           byte byte %00010000             
           byte byte %00001000             
           byte byte %00000100             
           byte byte %00000010             
           byte byte %00000001             
           byte byte %00000000             
                       
           byte byte %00000000   'r1 te Updated 0'       
           byte byte %00001110             
           byte byte %00010001             
           byte byte %00011001             
           byte byte %00010101             
           byte byte %00010011             
           byte byte %00010001             
           byte byte %00001110              
                       
           byte byte %00000000   'r1 te Updated 1'       
           byte byte %00000100             
           byte byte %00000110             
           byte byte %00000100             
           byte byte %00000100             
           byte byte %00000100             
           byte byte %00000100             
           byte byte %00001110             
                       
           byte byte %00000000   'r1 te Updated 2'       
           byte byte %00001110             
           byte byte %00010001             
           byte byte %00010000             
           byte byte %00001100             
           byte byte %00000010             
           byte byte %00000001             
           byte byte %00011111              
                       
           byte byte %00000000   'r1 te Updated 3'       
           byte byte %00011111             
           byte byte %00010000             
           byte byte %00001000             
           byte byte %00001100             
           byte byte %00010000             
           byte byte %00010001             
           byte byte %00001110             
                       
           byte byte %00000000   'r1 te Updated 4'       
           byte byte %00001000              
           byte byte %00001100             
           byte byte %00001010             
           byte byte %00001001             
           byte byte %00011111             
           byte byte %00001000             
           byte byte %00001000             
                       
           byte byte %00000000   'r1 te Updated 5'       
           byte byte %00011111             
           byte byte %00000001             
           byte byte %00001111             
           byte byte %00010000             
           byte byte %00010000             
           byte byte %00010001             
           byte byte %00001110             
                       
           byte byte %00000000   'r1 te Updated 6'       
           byte byte %00011100             
           byte byte %00000010             
           byte byte %00000001             
           byte byte %00001111             
           byte byte %00010001             
           byte byte %00010001             
           byte byte %00001110             
                       
           byte byte %00000000   'r1 te Updated 7'       
           byte byte %00011111             
           byte byte %00010000             
           byte byte %00001000             
           byte byte %00000100             
           byte byte %00000010             
           byte byte %00000010             
           byte byte %00000010             
                       
           byte byte %00000000   'r1 te Updated 8'       
           byte byte %00001110             
           byte byte %00010001             
           byte byte %00010001             
           byte byte %00001110             
           byte byte %00010001             
           byte byte %00010001             
           byte byte %00001110            
                       
           byte byte %00000000   'r1 te Updated 9'       
           byte byte %00001110             
           byte byte %00010001             
           byte byte %00010001             
           byte byte %00011110             
           byte byte %00010000             
           byte byte %00001000             
           byte byte %00000111              
                       
           byte byte %00000000   'r1 te Updated :'       
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00000100             
           byte byte %00000000             
           byte byte %00000100             
           byte byte %00000000             
           byte byte %00000000            
                       
           byte byte %00000000   'r1 te Updated ;'       
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00000100             
           byte byte %00000000             
           byte byte %00000100             
           byte byte %00000100             
           byte byte %00000010             
                       
           byte byte %00000000   'r1 te Updated <'       
           byte byte %00001000             
           byte byte %00000100             
           byte byte %00000010             
           byte byte %00000001             
           byte byte %00000010             
           byte byte %00000100             
           byte byte %00001000             
                       
           byte byte %00000000   'r1 te Updated ='       
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00011111             
           byte byte %00000000             
           byte byte %00011111             
           byte byte %00000000             
           byte byte %00000000              
                       
           byte byte %00000000   'r1 te Updated >'       
           byte byte %00000010             
           byte byte %00000100             
           byte byte %00001000             
           byte byte %00010000             
           byte byte %00001000             
           byte byte %00000100             
           byte byte %00000010            
                       
           byte byte %00000000   'r1 te Updated ?'       
           byte byte %00001110             
           byte byte %00010001             
           byte byte %00001000             
           byte byte %00000100             
           byte byte %00000100             
           byte byte %00000000             
           byte byte %00000100             
                       
           byte byte %00000000   'r1 te Updated @         
           byte byte %00001110             
           byte byte %00010001             
           byte byte %00010101             
           byte byte %00011101             
           byte byte %00001101             
           byte byte %00000001             
           byte byte %00011110               
                       
           byte byte %00000000   'r1 te Updated A'       
           byte byte %00000100             
           byte byte %00001010             
           byte byte %00010001             
           byte byte %00010001             
           byte byte %00011111             
           byte byte %00010001             
           byte byte %00010001             
                       
           byte byte %00000000   'r1 te Updated B'       
           byte byte %00001111             
           byte byte %00010001             
           byte byte %00010001             
           byte byte %00001111             
           byte byte %00010001             
           byte byte %00010001             
           byte byte %00001111             
                       
           byte byte %00000000   'r1 te Updated C'       
           byte byte %00001110             
           byte byte %00010001             
           byte byte %00000001             
           byte byte %00000001             
           byte byte %00000001             
           byte byte %00010001             
           byte byte %00001110              
                       
           byte byte %00000000   'r1 te Updated D'       
           byte byte %00001111             
           byte byte %00010001             
           byte byte %00010001             
           byte byte %00010001             
           byte byte %00010001             
           byte byte %00010001             
           byte byte %00001111               
                       
           byte byte %00000000   'r1 te Updated E'       
           byte byte %00011111             
           byte byte %00000001             
           byte byte %00000001             
           byte byte %00001111             
           byte byte %00000001             
           byte byte %00000001             
           byte byte %00011111              
                       
           byte byte %00000000   'r1 te Updated F       
           byte byte %00011111             
           byte byte %00000001             
           byte byte %00000001             
           byte byte %00001111             
           byte byte %00000001             
           byte byte %00000001             
           byte byte %00000001             
                       
           byte byte %00000000   'r1 te Updated G'       
           byte byte %00011110             
           byte byte %00000001             
           byte byte %00000001             
           byte byte %00000001             
           byte byte %00011001             
           byte byte %00010001             
           byte byte %00011110             
                       
           byte byte %00000000   'r1 te Updated H'       
           byte byte %00010001             
           byte byte %00010001             
           byte byte %00010001             
           byte byte %00011111             
           byte byte %00010001             
           byte byte %00010001             
           byte byte %00010001              
                       
           byte byte %00000000   'r1 te Updated I'       
           byte byte %00001110             
           byte byte %00000100             
           byte byte %00000100             
           byte byte %00000100             
           byte byte %00000100             
           byte byte %00000100             
           byte byte %00001110              
                       
           byte byte %00000000   'r1 te Updated J   
           byte byte %00010000          
           byte byte %00010000             
           byte byte %00010000             
           byte byte %00010000             
           byte byte %00010000             
           byte byte %00010001             
           byte byte %00001110            
                       
           byte byte %00000000   'r1 te Updated K'       
           byte byte %00010001             
           byte byte %00001001             
           byte byte %00000101             
           byte byte %00000011             
           byte byte %00000101             
           byte byte %00001001             
           byte byte %00010001             
                       
           byte byte %00000000   'r1 te Updated L'       
           byte byte %00000001             
           byte byte %00000001             
           byte byte %00000001             
           byte byte %00000001             
           byte byte %00000001             
           byte byte %00000001             
           byte byte %00011111             
                       
           byte byte %00000000   'r1 te Updated M'       
           byte byte %00010001             
           byte byte %00011011             
           byte byte %00010101             
           byte byte %00010101             
           byte byte %00010001            
           byte byte %00010001             
           byte byte %00010001             
                       
           byte byte %00000000   'r1 te Updated N'       
           byte byte %00010001             
           byte byte %00010001             
           byte byte %00010011             
           byte byte %00010101             
           byte byte %00011001             
           byte byte %00010001             
           byte byte %00010001             
                       
           byte byte %00000000   'r1 te Updated O'       
           byte byte %00001110             
           byte byte %00010001             
           byte byte %00010001             
           byte byte %00010001             
           byte byte %00010001             
           byte byte %00010001             
           byte byte %00001110             
                       
           byte byte %00000000   'r1 te Updated P'       
           byte byte %00001111             
           byte byte %00010001             
           byte byte %00010001             
           byte byte %00001111             
           byte byte %00000001             
           byte byte %00000001             
           byte byte %00000001             
                       
           byte byte %00000000   'r1 te Updated Q'       
           byte byte %00001110             
           byte byte %00010001             
           byte byte %00010001             
           byte byte %00010001             
           byte byte %00010101             
           byte byte %00001001             
           byte byte %00010110             
                       
           byte byte %00000000   'r1 te Updated R'       
           byte byte %00001111             
           byte byte %00010001             
           byte byte %00010001             
           byte byte %00001111             
           byte byte %00000101             
           byte byte %00001001             
           byte byte %00010001             
                       
           byte byte %00000000   'r1 te Updated S'       
           byte byte %00001110             
           byte byte %00010001             
           byte byte %00000001             
           byte byte %00001110             
           byte byte %00010000             
           byte byte %00010001             
           byte byte %00001110             
                       
           byte byte %00000000   'r1 se Updated T'       
           byte byte %00011111             
           byte byte %00000100             
           byte byte %00000100             
           byte byte %00000100             
           byte byte %00000100             
           byte byte %00000100             
           byte byte %00000100             
                       
           byte byte %00000000   'r1 se Updated U'       
           byte byte %00010001             
           byte byte %00010001             
           byte byte %00010001             
           byte byte %00010001             
           byte byte %00010001             
           byte byte %00010001             
           byte byte %00001110             
                       
           byte byte %00000000   'r1 te Updated V'       
           byte byte %00010001             
           byte byte %00010001             
           byte byte %00010001             
           byte byte %00010001             
           byte byte %00010001             
           byte byte %00001010             
           byte byte %00000100             
                       
           byte byte %00000000   'r1 te Updated W'       
           byte byte %00010001             
           byte byte %00010001             
           byte byte %00010001             
           byte byte %00010101             
           byte byte %00010101             
           byte byte %00011011             
           byte byte %00010001             
                       
           byte byte %00000000   'r1 te Updated X'       
           byte byte %00010001             
           byte byte %00010001             
           byte byte %00001010             
           byte byte %00000100             
           byte byte %00001010             
           byte byte %00010001             
           byte byte %00010001             
                       
           byte byte %00000000   'r1 te Updated Y'       
           byte byte %00010001             
           byte byte %00010001             
           byte byte %00001010             
           byte byte %00000100             
           byte byte %00000100             
           byte byte %00000100             
           byte byte %00000100             
                       
           byte byte %00000000   'r1 te Updated Z'       
           byte byte %00011111             
           byte byte %00010000             
           byte byte %00001000             
           byte byte %00000100             
           byte byte %00000010             
           byte byte %00000001             
           byte byte %00011111             
                       
           byte byte %00000000   'r1 te Updated ['       
           byte byte %00011111             
           byte byte %00000011             
           byte byte %00000011             
           byte byte %00000011             
           byte byte %00000011             
           byte byte %00000011             
           byte byte %00011111             
                       
           byte byte %00000000   'r1 te Updated \'       
           byte byte %00000000             
           byte byte %00000001             
           byte byte %00000010             
           byte byte %00000100             
           byte byte %00001000             
           byte byte %00010000             
           byte byte %00000000             
                       
           byte byte %00000000   'r1 te Updated ]'       
           byte byte %00011111             
           byte byte %00011000             
           byte byte %00011000             
           byte byte %00011000             
           byte byte %00011000             
           byte byte %00011000             
           byte byte %00011111             
                       
           byte byte %00000000   'r1 te Updated ^'       
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00000100             
           byte byte %00001010             
           byte byte %00010001             
           byte byte %00000000             
           byte byte %00000000              
                       
           byte byte %00000000   'Updated _'       
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00011111              
                       
           byte byte %00000000    'r1 te Updated ~         
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00000000             
           byte byte %00000000             
                       
           byte byte %00000000   'a'       
           byte byte %00000000             
           byte byte %00111100             
           byte byte %01100000             
           byte byte %01111100             
           byte byte %01100110             
           byte byte %01111100             
           byte byte %00000000             
                       
           byte byte %00000000   'b'       
           byte byte %00000110             
           byte byte %00000110             
           byte byte %00111110             
           byte byte %01100110             
           byte byte %01100110             
           byte byte %00111110             
           byte byte %00000000             
                       
           byte byte %00000000   'c'       
           byte byte %00000000             
           byte byte %00111100             
           byte byte %00000110             
           byte byte %00000110             
           byte byte %00000110             
           byte byte %00111100             
           byte byte %00000000             
                       
           byte byte %00000000   'd'       
           byte byte %01100000             
           byte byte %01100000             
           byte byte %01111100             
           byte byte %01100110             
           byte byte %01100110             
           byte byte %01111100             
           byte byte %00000000             
                       
           byte byte %00000000   'e'       
           byte byte %00000000             
           byte byte %00111100             
           byte byte %01100110             
           byte byte %01111110             
           byte byte %00000110             
           byte byte %00111100             
           byte byte %00000000             
                       
           byte byte %00000000   'f'       
           byte byte %01110000             
           byte byte %00011000             
           byte byte %01111100             
           byte byte %00011000             
           byte byte %00011000             
           byte byte %00011000             
           byte byte %00000000             
                       
           byte byte %00000000   'g'       
           byte byte %00000000             
           byte byte %01111100             
           byte byte %01100110             
           byte byte %01100110             
           byte byte %01111100             
           byte byte %01100000             
           byte byte %00111110             
                       
           byte byte %00000000   'h'       
           byte byte %00000110             
           byte byte %00000110             
           byte byte %00111110             
           byte byte %01100110             
           byte byte %01100110             
           byte byte %01100110             
           byte byte %00000000             
                       
           byte byte %00000000   'i'       
           byte byte %00011000             
           byte byte %00000000             
           byte byte %00011100             
           byte byte %00011000             
           byte byte %00011000             
           byte byte %00111100             
           byte byte %00000000             
                       
           byte byte %00000000   'j'       
           byte byte %01100000             
           byte byte %00000000             
           byte byte %01100000             
           byte byte %01100000             
           byte byte %01100000             
           byte byte %01100000             
           byte byte %00111100             
                       
           byte byte %00000000   'k'       
           byte byte %00000110             
           byte byte %00000110             
           byte byte %00110110             
           byte byte %00011110             
           byte byte %00110110             
           byte byte %01100110             
           byte byte %00000000             
                       
           byte byte %00000000   'l'       
           byte byte %00011100             
           byte byte %00011000             
           byte byte %00011000             
           byte byte %00011000             
           byte byte %00011000             
           byte byte %00111100             
           byte byte %00000000             
                       
           byte byte %00000000   'm'       
           byte byte %00000000             
           byte byte %01100110             
           byte byte %11111110             
           byte byte %11111110             
           byte byte %11010110             
           byte byte %11000110             
           byte byte %00000000             
                       
           byte byte %00000000   'n'       
           byte byte %00000000             
           byte byte %00111110             
           byte byte %01100110             
           byte byte %01100110             
           byte byte %01100110             
           byte byte %01100110             
           byte byte %00000000             
                       
           byte byte %00000000   'o'       
           byte byte %00000000             
           byte byte %00111100             
           byte byte %01100110             
           byte byte %01100110             
           byte byte %01100110             
           byte byte %00111100             
           byte byte %00000000             
                       
           byte byte %00000000   'p'       
           byte byte %00000000             
           byte byte %00111110             
           byte byte %01100110             
           byte byte %01100110             
           byte byte %00111110             
           byte byte %00000110             
           byte byte %00000110             
                       
           byte byte %00000000   'q'       
           byte byte %00000000             
           byte byte %01111100             
           byte byte %01100110             
           byte byte %01100110             
           byte byte %01111100             
           byte byte %01100000             
           byte byte %01100000             
                       
           byte byte %00000000   'r'       
           byte byte %00000000             
           byte byte %00111110             
           byte byte %01100110             
           byte byte %00000110             
           byte byte %00000110             
           byte byte %00000110             
           byte byte %00000000             
                       
           byte byte %00000000   's'       
           byte byte %00000000             
           byte byte %01111100             
           byte byte %00000110             
           byte byte %00111100             
           byte byte %01100000             
           byte byte %00111110             
           byte byte %00000000             
                       
           byte byte %00000000   't'       
           byte byte %00011000             
           byte byte %01111110             
           byte byte %00011000             
           byte byte %00011000             
           byte byte %00011000             
           byte byte %01110000             
           byte byte %00000000             
                       
           byte byte %00000000   'u'       
           byte byte %00000000             
           byte byte %01100110             
           byte byte %01100110             
           byte byte %01100110             
           byte byte %01100110             
           byte byte %01111100             
           byte byte %00000000             
                       
           byte byte %00000000   'v'       
           byte byte %00000000             
           byte byte %01100110             
           byte byte %01100110             
           byte byte %01100110             
           byte byte %00111100             
           byte byte %00011000             
           byte byte %00000000             
                       
           byte byte %00000000   'w'       
           byte byte %00000000             
           byte byte %11000110             
           byte byte %11010110             
           byte byte %11111110             
           byte byte %01111100             
           byte byte %01101100             
           byte byte %00000000             
                       
           byte byte %00000000   'x'       
           byte byte %00000000             
           byte byte %01100110             
           byte byte %00111100             
           byte byte %00011000             
           byte byte %00111100             
           byte byte %01100110             
           byte byte %00000000             
                       
           byte byte %00000000   'y'       
           byte byte %00000000             
           byte byte %01100110             
           byte byte %01100110             
           byte byte %01100110             
           byte byte %01111100             
           byte byte %00110000             
           byte byte %00011110             
                       
           byte byte %00000000   'z'       
           byte byte %00000000             
           byte byte %01111110             
           byte byte %00110000             
           byte byte %00011000             
           byte byte %00001100             
           byte byte %01111110             
           byte byte %00000000             
                       
           byte byte %01100110             
           byte byte %01100110             
           byte byte %00011000             
           byte byte %00111100             
           byte byte %01100110             
           byte byte %01111110             
           byte byte %01100110             
           byte byte %00000000             
                       
           byte byte %00011000   '|'       
           byte byte %00011000             
           byte byte %00011000             
           byte byte %00011000             
           byte byte %00011000             
           byte byte %00011000             
           byte byte %00011000             
           byte byte %00011000             
                       
           byte byte %00000000             
           byte byte %01111110             
           byte byte %00011110             
           byte byte %00111110             
           byte byte %01110110             
           byte byte %01100110             
           byte byte %01100000             
           byte byte %00000000             
                       
           byte byte %00010000             
           byte byte %00011000             
           byte byte %00011100             
           byte byte %00011110             
           byte byte %00011100             
           byte byte %00011000             
           byte byte %00010000             
           byte byte %00000000             
                       
           byte byte %00001000             
           byte byte %00011000             
           byte byte %00111000             
           byte byte %01111000             
           byte byte %00111000             
           byte byte %00011000             
           byte byte %00001000             
           byte byte %00000000             
                                           
                                           