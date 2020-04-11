# zig-riscv-embedded

Toy project using [zig][zig website] on the [hifive1][hifive1 website] RISC-V board.

## Status

This repository is intended to provide a simple sample application for
experimenting with the zig programming language on freestanding RISCV.
The application targets the [SiFive FE310-G000][fe310 manual] or more
specifically the [HiFive 1][hifive1 website]. While possible to run the
application on "real hardware", it can also be run using an emulator.

The mid-term goal is to provide somewhat usable abstractions for
interacting with the UART and the PLIC. These abstractions are currently
being developed in `uart.zig` and `plic.zig`. The `main.zig` file
combines the two to output `Hello!` indefinitely.

The application uses slightly modified linker scripts and assembler
startup code copied from the [RIOT project][riot fe310]. Refer to the
license headers of the different files for more information.

## Building

The code builds successfully with zig `0.5.0+5990929247`. The zig build
system is used for building the application, the configuration is
available in `build.zig`. To build the application run:

	$ zig build

This will create a freestanding RISC-V ELF binary `zig-cache/bin/main`.

## Booting

The generated ELF binary can be booted using `hifive-vp` from
[riscv-vp][riscv-vp GitHub]. Alternatively, the [qemu][qemu website]
`sifive_e` machine also works.

Using riscv-vp:

	$ hifive-vp zig-cache/bin/main

Using qemu:

	$ qemu-system-riscv32 -M sifive_e -nographic -kernel zig-cache/bin/main

The application should also boot successfully on the hifive1, though I
haven't gotten around to testing it yet.

[zig website]: https://ziglang.org/
[riscv-vp GitHub]: https://github.com/agra-uni-bremen/riscv-vp
[qemu website]: https://www.qemu.org/
[fe310 manual]: https://static.dev.sifive.com/FE310-G000.pdf
[hifive1 website]: https://www.sifive.com/boards/hifive1
[riot fe310]: https://github.com/RIOT-OS/RIOT/tree/master/cpu/fe310
