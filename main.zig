const std = @import("std");

export fn myinit() void {
  asm volatile ("addi t0, t0, 23");
}
