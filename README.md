# zig-riscv-embedded

Toy project using [Zig][zig website] on the [HiFive1][hifive1 website] RISC-V board.

## Status

This repository is intended to provide a simple sample application for
experimenting with the Zig programming language on freestanding RISC-V.
The application targets the [SiFive FE310-G000][fe310 manual] or more
specifically the [HiFive 1][hifive1 website]. While possible to run the
application on "real hardware", it can also be run using QEMU.

## CoAP over Serial

To experiment with external dependencies in Zig, this application
provides a very bare bone implementation of the [Constrained Application Protocol][rfc7252]
using [zoap][zoap github]. Since implementing an entire UDP/IP stack
from scratch is out-of-scope, this repository transports raw CoAP packets
directly over [SLIP][rfc1055]. For this purpose, this repository abuses
the CoAP framing format from [draft-bormann-t2trg-slipmux-03][slipmux]
(Slipmux). A proxy for converting CoAP packets, as received over UDP, to this
framing format is available in the `./coap-slip` subdirectory.

## Dependencies

* Zig `0.7.1`
* [Go][golang web] for compiling the `coap-slip` proxy
* QEMU (`qemu-system-riscv32`) for emulating a HiFive1
* A CoAP client, e.g. `coap-client(1)` from [libcoap][libcoap github]

For flashing to real hardware, the following software is required:

* [riscv-openocd][riscv-openocd]
* [GDB][gdb web] with 32-bit RISC-V support

## Building

The Zig build system is used for building the application, the
configuration is available in `build.zig`. To build the application run:

	$ zig build

This will create a freestanding RISC-V ELF binary `zig-cache/bin/main`.
If the image should be booted on real hardware, building in the
`ReleaseSmall` [build mode][zig build modes] may be desirable:

	$ zig build -Drelease-small

## Usage

The generated ELF binary can be flashed on the HiFive1 and it can also
be booted using the [qemu][qemu website] `sifive_e` machine as follows:

	$ mkfifo /tmp/input
	$ qemu-system-riscv32 -M sifive_e -nographic -kernel zig-cache/bin/main \
		-serial file:/tmp/out -serial pipe:/tmp/input

This will create an output file for UART0 in `/tmp/out` which can be
read using `tail -f /tmp/out`. Additionally, it will create a named pipe
in `/tmp/input`. Slipmux CoAP frames can be written to this named pipe
and will afterwards be parsed by the Zig application code. For
converting CoAP packets to Slipmux frames, a proxy is available in the
`./coap-slip` subdirectory. The proxy is written in Go and can be compiled
as follows:

	$ cd coap-slip && go build -trimpath

After compiling this proxy, it can be started as follows:

	$ ./coap-slip :2342 >> /tmp/input

Afterwards, CoAP packets can be written to `localhost:2342` and will
then be forwarded in the Slipmux CoAP framing format to the Zig code.
For example, using `coap-client(1)` from [libcoap][libcoap github]:

	$ coap-client -N -m put coap://[::1]:2342/panic

## Real Hardware

**Disclaimer:** The code is presently a bit flaky on real hardware and
difficult to debug as I did not anticipate that the QFN48 package of the
FE310-G000 (used by the HiFive1) does not actually support UART1. As
such, it would be desirable to properly implement
[raft-bormann-t2trg-slipmux-03][slipmux] to multiplex diagnostic debug
messages and CoAP frames over the same UART.

The binary can be flashed to real hardware using OpenOCD and gdb. For
this purpose, a shell script is provided. In order to flash a compiled
binary run the following command:

	$ ./flash

To debug errors on real hardware start OpenOCD using `openocd -f
openocd.cfg`. In a separate terminal start gdb as follows:

	$ gdb-multiarch -ex 'target extended-remote :3333' zig-cache/bin/main

## Development

A pre-commit git hook for checking if files are properly formated is
provided in `.githooks`. It can be activated using:

	$ git config --local core.hooksPath .githooks

## License

The application uses slightly modified linker scripts and assembler
startup code copied from the [RIOT][riot fe310] operating system. Unless
otherwise noted code written by myself is licensed under
`GPL-3.0-or-later`. Refer to the license headers of the different files
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
