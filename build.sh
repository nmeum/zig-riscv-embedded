#!/bin/sh
zig build-exe main.zig \
	-target riscv32-freestanding-none \
	--linker-script fe310_g000.ld \
	--c-source start.S \
	--c-source irq.S
