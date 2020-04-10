// Based on https://github.com/agra-uni-bremen/riscv-vp/blob/f6e95b370cb6eab7024f1be26a2b8a8ae2c916be/sw/simple-sensor/bootstrap.S
//
// Copyright © 2017-2018, Group of Computer Architecture, University of Bremen
//
// Permission is hereby granted, free of charge, to any person obtaining a
// copy of this software and associated documentation files (the
// "Software"), to deal in the Software without restriction, including
// without limitation the rights to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject to
// the following conditions:
//
// The above copyright notice and this permission notice shall be included
// in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
// OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
// IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
// CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
// TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
// SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

.globl register_handler
.globl lvl0_handler

lvl0_handler:
    # Store all register values on the stack
    addi sp, sp, -4 * 32
    sw x1, 0x0(sp)
    sw x4, 3 * 4(sp)
    sw x5, 4 * 4(sp)
    sw x6, 5 * 4(sp)
    sw x7, 6 * 4(sp)
    sw x10, 9 * 4(sp)
    sw x11, 10 * 4(sp)
    sw x12, 11 * 4(sp)
    sw x13, 12 * 4(sp)
    sw x14, 13 * 4(sp)
    sw x15, 14 * 4(sp)
    sw x16, 15 * 4(sp)
    sw x17, 16 * 4(sp)
    sw x28, 27 * 4(sp)
    sw x29, 28 * 4(sp)
    sw x30, 29 * 4(sp)
    sw x31, 30 * 4(sp)

    # Jump to the level 1 trap handler written in Zig
    jal lvl1_handler

    # Set the return address to the next instruction
    csrr t0, mepc
    addi t0, t0, 4
    csrw mepc, t0

    # Load all register values from the stack and return
    lw x1, 0x0(sp)
    lw x4, 3 * 4(sp)
    lw x5, 4 * 4(sp)
    lw x6, 5 * 4(sp)
    lw x7, 6 * 4(sp)
    lw x10, 9 * 4(sp)
    lw x11, 10 * 4(sp)
    lw x12, 11 * 4(sp)
    lw x13, 12 * 4(sp)
    lw x14, 13 * 4(sp)
    lw x15, 14 * 4(sp)
    lw x16, 15 * 4(sp)
    lw x17, 16 * 4(sp)
    lw x28, 27 * 4(sp)
    lw x29, 28 * 4(sp)
    lw x30, 29 * 4(sp)
    lw x31, 30 * 4(sp)
    addi sp, sp, 4 * 32
    mret

register_handler:
    # Use lvl0_handler as the trap handler
    la t0, lvl0_handler
    csrw mtvec, t0

    # Enable machine external interrupts (MIE bit)
    li t1, 0x800
    csrw mie, t1

    # Globally enable machine mode interrupts (MIE bit)
    li t1, 0x8
    csrw mstatus, t1

    # Return
    ret
