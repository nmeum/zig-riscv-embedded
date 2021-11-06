# zig-riscv-embedded

Experimental [Zig][zig website]-based [CoAP][rfc7252] node for the [HiFive1][hifive1 website] RISC-V board.

![World's first IoT-enabled Zig-based constrained node](https://gist.github.com/nmeum/9c921cac9e28e722a8415af3ff213e8c/raw/b936f1f05d5eda07a91a87efdaf5cb1552795ad1/output-2fps-960px.gif)

## Status

This repository is intended to provide a simple sample application for
experimenting with the Zig programming language on freestanding RISC-V.
The application targets the [SiFive FE310-G000][fe310 manual] or more
specifically the [HiFive 1][hifive1 website]. While possible to run the
application on "real hardware", it can also be run using QEMU. In both
cases it is possible to toggle an LED using [CoAP][rfc7252] over
[SLIP][rfc1055].

## CoAP over SLIP

To experiment with external dependencies in Zig, this application
provides a very bare bone implementation of [CoAP][rfc7252] using
[zoap][zoap github]. Since implementing an entire UDP/IP stack from
scratch is out-of-scope, this repository transports CoAP packets
directly over [SLIP][rfc1055].

Unfortunately, the QFN48 package of the FE310-G000 (as used by the
HiFive1) does not support the UART1. For this reason, the application
multiplexes diagnostic messages and CoAP frames over the same UART
(UART0) using [Slipmux][slipmux]. For this purpose, a Go-based
multiplexer for the development system is available in the `./slipmux`
subdirectory.

## Dependencies

For building the software and the associated Slipmux tooling, the
following software is required:

* Zig `0.8.1`
* [Go][golang web] for compiling the `./slipmux` tool
* A CoAP client, e.g. `coap-client(1)` from [libcoap][libcoap github]
* QEMU (`qemu-system-riscv32`) for emulating a HiFive1 (optional)

For flashing to real hardware, the following software is required:

* [riscv-openocd][riscv-openocd]
* [GDB][gdb web] with 32-bit RISC-V support

## Building

The Zig build system is used for building the application, the
configuration is available in `build.zig`. To build the application run:

	$ zig build

This will create a freestanding RISC-V ELF binary `zig-out/bin/main`.
If the image should be booted on real hardware, building in the
`ReleaseSmall` [build mode][zig build modes] may be desirable:

	$ zig build -Drelease-small

Furthermore, the Slipmux multiplexer needs to be compiled using the
following commands in order to receive diagnostic messages from the
device and send CoAP messages to the device:

	$ cd slipmux && go build -trimpath

## Booting in QEMU

In order to simulate a serial device, which can be used with the
`./slipmux` tool, QEMU must be started as follows:

	$ qemu-system-riscv32 -M sifive_e -nographic -kernel zig-out/bin/main -serial pty

QEMU will print the allocated PTY path to standard output. In a separate
terminal the `./slipmux` tool can then be started as follows:

	$ ./slipmux/slipmux :2342 <PTY allocated by QEMU>

This will create a UDP Socket on `localhost:2342`, CoAP packets send to
this socket are converted into Slipmux CoAP frames and forwarded to the
emulated HiFive1 over the allocated PTY. CoAP packets can be send using
any CoAP client, e.g. using `coap-client(1)` from [libcoap][libcoap github]:

	$ coap-client -N -m put coap://[::1]:2342/on
	$ coap-client -N -m put coap://[::1]:2342/off

In QEMU, this will cause debug messages to appear in the terminal window
were `./slipmux` is running. On real hardware, it will also cause the
red LED to be toggled.

## Booting on real hardware

The binary can be flashed to real hardware using OpenOCD and gdb. For
this purpose, a shell script is provided. In order to flash a compiled
binary run the following command:

	$ ./flash

After flashing the device, interactions through CoAP are possible using
the instructions given for QEMU above. However, with real hardware
`./slipmux` needs to be passed the TTY device for the HiFive1 (i.e.
`/dev/ttyUSB0`).

To debug errors on real hardware start OpenOCD using `openocd -f
openocd.cfg`. In a separate terminal start a gdb version with RISC-V
support (e.g. [gdb-multiarch][gdb-multiarch alpine]) as follows:

	$ gdb-multiarch -ex 'target extended-remote :3333' zig-out/bin/main

## Development

A pre-commit git hook for checking if files are properly formated is
provided in `.githooks`. It can be activated using:

	$ git config --local core.hooksPath .githooks

## License

The application uses slightly modified linker scripts and assembler
startup code copied from the [RIOT][riot fe310] operating system. Unless
otherwise noted code written by myself is licensed under
`AGPL-3.0-or-later`. Refer to the license headers of the different files
for more information.

[zig website]: https://ziglang.org/
[zig build modes]: https://ziglang.org/documentation/master/#Build-Mode
[qemu website]: https://www.qemu.org/
[fe310 manual]: https://static.dev.sifive.com/FE310-G000.pdf
[hifive1 website]: https://www.sifive.com/boards/hifive1
[riot fe310]: https://github.com/RIOT-OS/RIOT/tree/master/cpu/fe310
[slipmux]: https://datatracker.ietf.org/doc/html/draft-bormann-t2trg-slipmux-03
[rfc7252]: https://datatracker.ietf.org/doc/html/rfc7252
[rfc1055]: https://datatracker.ietf.org/doc/html/rfc1055
[libcoap github]: https://github.com/obgm/libcoap
[golang web]: https://golang.org
[zoap github]: https://github.com/nmeum/zoap
[riscv-openocd]: https://github.com/riscv/riscv-openocd
[gdb web]: https://www.gnu.org/software/gdb/
[gdb-multiarch alpine]: https://pkgs.alpinelinux.org/package/edge/main/x86_64/gdb-multiarch
