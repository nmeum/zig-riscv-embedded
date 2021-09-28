# zig-riscv-embedded

Toy project using [Zig][zig website] on the [HiFive1][hifive1 website] RISC-V board.

## Status

This repository is intended to provide a simple sample application for
experimenting with the Zig programming language on freestanding RISC-V.
The application targets the [SiFive FE310-G000][fe310 manual] or more
specifically the [HiFive 1][hifive1 website]. While possible to run the
application on "real hardware", it can also be run using an emulator.

The mid-term goal is to provide somewhat usable abstractions for
interacting with the UART and the PLIC. These abstractions are currently
being developed in `uart.zig` and `plic.zig`. Based on these
abstractions, an implementation of Zig input and output streams is being
developed in `streams.zig`. The file `main.zig` uses the aforementioned
abstractions to output `Hello, World!`.

## Building

The code builds successfully with Zig `0.7.1`. The Zig build system is
used for building the application, the configuration is available in
`build.zig`. To build the application run:

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

This will create a output file for UART1 in `/tmp/out` which can be read
using `tail -f /tmp/out`. Additionally, it will create a named pipe in
`/tmp/input`. [Slipmux] CoAP frames can be written to this named pipe
and will afterwards be parsed by the Zig application code. For this
purpose, a proxy is available in the `./coap-slip-proxy` subdirectory.
The proxy is written in [Go][golang web] and can be compiled as follows:

	$ cd coap-slip-proxy && go build -trimpath

After compiling this proxy, it can be started as follows:

	$ ./coap-slip :2342 >> /tmp/input

Afterwards, CoAP packets can be written to `localhost:2342` and will
then be forwarded in the Slipmux CoAP framing format to the Zig code.
For example, using `coap-client(1)` from [libcoap][libcoap github]:

	$ coap-client -N -m get coap://[::1]:2342/.well-known/core

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
[libcoap github]: https://github.com/obgm/libcoap
[golang web]: https://golang.org
