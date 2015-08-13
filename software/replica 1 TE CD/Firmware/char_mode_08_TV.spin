{

40 x 24 text display driver TV portion    Rev 01

Right now, two text sizes are possible.  320 pixels will yield 40x24 text
                                         160 pixels will yield 20x24 text

                                         change the CHOOSE_horizontal_pixels value below

                                         Vertical size and color phase work in progress....

Doug Dingus 09/07



            ********************************************************
            ** IMPORTANT NOTE:  This version of "char_mode_08_TV" **
            ** is configured for demoboard/protoboard video       **
            ** settings.  Obtain a copy of the original zip for   **
            ** Hydra compatibility  --JEFF--                      **
            ********************************************************

}



CON
 
  
PUB start(tvpointer) | i, j, k

  cognew(@entry,tvpointer)
  

DAT                     org
entry                   jmp     #initialization         'Jump past the constants



CON  NTSC_color_frequency       =     3_579_545
DAT  NTSC_color_freq            long  NTSC_color_frequency


CON  NTSC_hsync_clocks          =               624
DAT  NTSC_hsync_VSCL              long  160368
DAT  NTSC_control_signal_palette long  $00_00_02_8a
DAT  NTSC_hsync_pixels          long  %%11_0000_1_2222222_11


'***************************************************
'* Blank lines                                     *
'***************************************************
CON  NTSC_active_video_clocks   =     3008
DAT  NTSC_active_video_VSCL     long  NTSC_active_video_clocks



'***************************************************
'* User graphics lines                             *
'***************************************************
' The important lines at last.  You can edit CHOOSE_horizontal_pixels (40, 80, 160, 256, 320)
' You can also edit CHOOSE_vertical_pixel_height.  (0 - 1)  
CON CHOOSE_horizontal_pixels  =  320  'or 320
CON CHOOSE_vertical_pixel_height = 0   '0 or 1, depending on vertical resolution (96, 192)
CON CHOOSE_clocks_per_gfx_pixel = 2560 / CHOOSE_horizontal_pixels
CON CALC_bytes_per_line = CHOOSE_horizontal_pixels / 8
CON CALC_waitvids = CALC_bytes_per_line



CON CALC_clocks_per_gfx_frame   =  CHOOSE_clocks_per_gfx_pixel*8



'DAT CALC_user_data_VSCL         long  (CHOOSE_clocks_per_gfx_pixel * 32 * 8) + CALC_clocks_per_gfx_frame

DAT CALC_user_data_VSCL         long  (CHOOSE_clocks_per_gfx_pixel) << 12 +  CALC_clocks_per_gfx_frame

CON CALC_frames_per_gfx_line    = CHOOSE_horizontal_pixels / 8

CON CALC_overscan = 448 

CON CHOOSE_horizontal_offset    = 00

CON CALC_backporch = 208 + CHOOSE_horizontal_offset    'this must be a multiple of the total
                                                       'pixel clock 16 clocks in this case.
                                                       'only important if one is artifacting
                                                       'for high-color.  Do what you want
                                                       'here that makes sense otherwise.
CON CALC_frontporch = (CALC_overscan - CALC_backporch)

DAT

' Video hardware setup



initialization          'set up VCFG

                        ' VCFG: setup Video Configuration register and 3-bit tv DAC pins to output
                        movs    VCFG, #%0111_0000       ' VCFG'S = pinmask (pin31: 0000_0111 : pin24)
                        movd    VCFG, #1                ' VCFG'D = pingroup (grp. 3 i.e. pins 24-31)

                        movi    VCFG, #%0_11_111_000
                                

                                                        ' baseband video on bottom nibble, 2-bit color, enable chroma on broadcast & baseband
                                                        ' %0_xx_x_x_x_xxx : Not used
                                                        ' %x_10_x_x_x_xxx : Composite video to top nibble, broadcast to bottom nibble
                                                        ' %x_xx_1_x_x_xxx : 4 color mode
                                                        ' %x_xx_x_1_x_xxx : Enable chroma on broadcast
                                                        ' %x_xx_x_x_1_xxx : Enable chroma on baseband
                                                        ' %x_xx_x_x_x_000 : Broadcast Aural FM bits (don't care)

                        or      DIRA, tvport_mask       ' set DAC pins to output

                        ' 
                        'or      DIRA, #1                ' enable debug LED
                        'mov     OUTA, #1                ' light up debug LED

                        ' CTRA: setup Frequency to Drive Video
                        movi    CTRA,#%00001_111        ' pll internal routed to Video, PHSx+=FRQx (mode 1) + pll(16x)
                        mov     r1, NTSC_color_freq     ' r1: Color frequency in Hz (3.579_545MHz)
                        rdlong  v_clkfreq, #0           ' copy clk frequency. (80Mhz)
                        mov     r2, v_clkfreq           ' r2: CLKFREQ (80MHz)
                        call    #dividefract            ' perform r3 = 2^32 * r1 / r2
                        mov     v_freq, r3              ' v_freq now contains frqa.       (191)
                        mov     FRQA, r3                ' set frequency for counter


'get parameters from parameter block, and pass them to COG code here

                        mov     C, PAR                 ' get parameter block address
                        rdlong  A, C                   ' get screen address
                        mov     bmp, A                 ' store another copy
                        
                        add     C, #4                  'index to fonttab address
                        rdlong  fonttab, C             'store it 

                        add     C, #4                   'index to mode value
                        rdlong  pixel_mode, C           'store it 

                        add     C, #4                  'index to colors value
                        rdlong  colors, C              'store them...
                        mov     fat_mode, colors       'set 16 bit mode        

'-----------------------------------------------------------------------------
                        'vertical overscan (26 blank lines)
frame_loop                                                            
                        mov     line_loop, #26          '(26 so far)

:vert_back_porch        mov     VSCL, NTSC_hsync_VSCL
                        waitvid NTSC_control_signal_palette, hsync
                        
                        
                        mov     VSCL, NTSC_active_video_VSCL
                        waitvid brown_border_in_color0, #0      'draw blank line
                        djnz    line_loop, #:vert_back_porch
'-----------------------------------------------------------------------------


                        mov     line_loop, #192    'setup number of display lines
                        mov     fontline, #0       'set font scan offset to 0


                        
user_graphics_lines     mov     VSCL, NTSC_hsync_VSCL
                        waitvid NTSC_control_signal_palette, hsync    'hsync
                                                             
                        mov     VSCL,#CALC_backporch
                        waitvid green_border_in_color0, #0   'left overscan
                        
 
                        mov     VSCL, CALC_user_data_VSCL  'set VSCL for 8 pixel blocks                         
                        movi    VCFG, #%0_11_011_000   'two color mode
                        mov     r1, #CALC_waitvids  'number of horiz pixels / 8

                        mov     fontsum, fonttab         'pre add these to save instruction time
                        add     fontsum, fontline        'in waitvid later on


                        tjz     fat_mode, #fat_bit_mode     '16 bit mode yes?   




:draw_pixels            rdbyte  B, A        'get a character from screen memory (A)
                        shl     B, #3           'multiply by 8, for char offset
                        add     B, fontsum    'add current scanline offset
                        rdbyte  C, B            'read actual font pixels into (C)

                        waitvid colors, C  'draw them to screen
                        
                        add     A, #1    'point to next set of chars
                        djnz    r1, #:draw_pixels  'line done?

                        jmp    #end_of_flag_line
                        
                        'little endian design makes byte order different (rdlong)


fat_bit_mode            rdlong  B, A            'get a character and colors from screen memory (A)
                        mov     colors, B       'set up colors
                        shr     B, #24
                        shl     B, #3
                        add     B, fontsum
                        rdbyte  C, B
                        and     colors, color_mask

                        waitvid colors, C  'draw them to screen
                        
                        add     A, #4    'point to next set of chars and colors
                        djnz    r1, #fat_bit_mode  'line done?




                        
'===============================================================================================
  
end_of_flag_line        mov    VSCL,#CALC_frontporch
                        waitvid blue_border_in_color0 , border 'overscan to the right...
                        movi    VCFG, #%0_11_111_000    '4 color mode

                        tjz     fat_mode, #fat_offset     '16 bit mode yes?

                        'deal with scanline offset

                        add        fontline, #1
                        and        fontline, #%0111     wz
                if_nz   sub        A, #CALC_bytes_per_line    

                        jmp       #frame_draw

                                                                            
fat_offset              add        fontline, #1
                        and        fontline, #%0111  wz
                if_nz   sub        A, #CALC_bytes_per_line*4                        
                       

                        
                        
frame_draw             djnz    line_loop, #user_graphics_lines   'done with visible screen?


                        
                        mov     A, bmp          'reset screen memory pointer for next frame
'-----------------------------------------------------------------------------
                        'Overscan at the bottom of screen.  
                        mov     line_loop, #26          '(244)
                        'hsync
vert_front_porch        mov     VSCL, NTSC_hsync_VSCL
                        waitvid NTSC_control_signal_palette, hsync
                        mov     VSCL, NTSC_active_video_VSCL
                        waitvid magenta_border_in_color0, #0
                        djnz    line_loop, #vert_front_porch
'-----------------------------------------------------------------------------
                        'This is the vertical sync.  It consists of 3 sections of 6 lines each.
                        mov     line_loop, #6           '(250)
:vsync_higha            mov     VSCL, NTSC_hsync_VSCL
                        waitvid NTSC_control_signal_palette, vsync_high_1
                        mov     VSCL, NTSC_active_video_VSCL
                        waitvid NTSC_control_signal_palette, vsync_high_2
                        djnz    line_loop, #:vsync_higha
'-----------------------------------------------------------------------------
                        mov     line_loop, #6           '(256)
:vsync_low              mov     VSCL, NTSC_hsync_VSCL
                        waitvid NTSC_control_signal_palette, vsync_low_1
                        mov     VSCL, NTSC_active_video_VSCL
                        waitvid NTSC_control_signal_palette, vsync_low_2
                        djnz    line_loop, #:vsync_low
'-----------------------------------------------------------------------------
                        mov     line_loop, #6           '(250)
:vsync_highb            mov     VSCL, NTSC_hsync_VSCL
                        waitvid NTSC_control_signal_palette, vsync_high_1
                        mov     VSCL, NTSC_active_video_VSCL
                        waitvid NTSC_control_signal_palette, vsync_high_2
                        djnz    line_loop, #:vsync_highb
'-----------------------------------------------------------------------------
                        

                        jmp     #frame_loop

' General Purpose Registers
r0                      long                    $0    ' should typically equal 0
r1                      long                    $0
r2                      long                    $0
r3                      long                    $0

A                       long                    $0  'coupla more general purpose registers
B                       long                    $0
C                       long                    $0  

bmp                     long                    $0  'tvpointer ends up here 


pixel_mode              long                    $0  'unimplemented...
'the plan here is upper word being vertical height, lower being horizontal pixels per line



colors                  long                    $0000ddda     'default, if not set by calling program
chars                   long                    $0 
fontline                long                    $0   'scanline counter
fonttab                 long                    $0   'HUB memory address of font table
fat_mode                long                    $1   'two color by default

fontsum                long                    $0   'this is fontline + fonttab

color_mask              long                    $0000ffff


' Video (TV) Registers
tvport_mask             long                    %0000_1111<<12

v_freq                  long                    0

' Graphics related vars.
v_coffset               long                    $02020202  ' color offset (every color is added by $02)
v_clkfreq               long                    $0

' /////////////////////////////////////////////////////////////////////////////
' dividefract:
' Perform 2^32 * r1/r2, result stored in r3 (useful for TV calc)
' This is taken from the tv driver.
' NOTE: It divides a bottom heavy fraction e.g. 1/2 and gives the result as a 32-bit fraction.
' /////////////////////////////////////////////////////////////////////////////
dividefract                                     
                        mov     r0,#32+1
:loop                   cmpsub  r1,r2           wc
                        rcl     r3,#1
                        shl     r1,#1
                        djnz    r0,#:loop

dividefract_ret         ret                             '+140


'Pixel streams
'  These are shifted out of the VSU to the right, so lowest bits are actioned first.
'
hsync                   long    %%11_0000_1_2222222_11  ' Used with NTSC_control_signal_palette so:
                                                        '      0 = blanking level
                                                        '      1 = Black
                                                        '      2 = Color NTSC_control_signal_palette (yellow at zero value)
vsync_high_1            long    %%11111111111_222_11
vsync_high_2            long    %%1111111111111111
vsync_low_1             long    %%22222222222222_11
vsync_low_2             long    %%1_222222222222222
all_black               long    %%1111111111111111
border                  long    %%0000000000000000

' Some unimportant irrelevant constants for generating demo user display etc.
line_loop               long    0
tile_loop               long    0


' Overscan color choices --need to set these as parameters
'  These are always 4 colors (or blanking level) stored in reverse order:
'                               Color3_Color2_Color1_Color0

blue_border_in_color0    long    $03030303     'All set to grey
green_border_in_color0   long    $03030303
magenta_border_in_color0 long   $03030303
brown_border_in_color0   long    $03030303



                        