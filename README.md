# Doodle Jump
A simple version of doodle jump written in assembly.

## Software Requirement
[Mars](http://courses.missouristate.edu/kenvollmar/mars/download.htm) is required to play this game. Once you insall it, open the software, click "File > Open" and select doodlejump.s.

1. Click "Assemble the current file and clear breakpoints"
2. Go to "Tools > Keyboard and Display MMIO Simulator", and click "Connect to MIPS"
3. Go to "Tools > Bitmap Display", set:
    * Unit width in pixels: 8 
    * Unit height in pixels: 8
    * Display width in pixels: 256
    * Display height in pixels: 256
    * Base Address for Display: 0x10008000 ($gp)
    * Click "Connect to MIPS"
4. Click "Run the current program" and you are ready to play the game by enter the commands in "Keyboard and Display MMIO Simulator" keyboard section.

## Instructions
- Press "j" to move left
- Press "k" to move right
- Once you are dead, press "s" to restart
