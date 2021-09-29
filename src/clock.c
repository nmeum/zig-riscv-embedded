/* Copied from https://wiki.osdev.org/HiFive-1_Bare_Bones#The_kernel_source_code */
/* Should eventually be rewritten in Zig with proper abstraction for the PRCI. */

#include <stdint.h>

#define PRCI_CTRL_ADDR 0x10008000UL
#define PRCI_HFROSCCFG (0x0000)
#define PRCI_PLLCFG (0x0008)
#define ROSC_EN(x) (((x) & 0x1) << 30)
#define PLL_REFSEL(x) (((x) & 0x1) << 17)
#define PLL_BYPASS(x) (((x) & 0x1) << 18)
#define PLL_SEL(x) (((x) & 0x1) << 16)

static inline uint32_t
mmio_read_u32(unsigned long reg, unsigned int offset)
{
	return (*(volatile uint32_t *) ((reg) + (offset)));
}

static inline void
mmio_write_u32(unsigned long reg, unsigned int offset, uint32_t val)
{
	(*(volatile uint32_t *) ((reg) + (offset))) = val;
}

void
clock_init(void)
{
	/* Make sure the HFROSC is on */
	mmio_write_u32(PRCI_CTRL_ADDR, PRCI_HFROSCCFG,
			mmio_read_u32(PRCI_CTRL_ADDR, PRCI_HFROSCCFG)
			| ROSC_EN(1));

	/* Run off 16 MHz Crystal for accuracy */
	mmio_write_u32(PRCI_CTRL_ADDR, PRCI_PLLCFG,
			mmio_read_u32(PRCI_CTRL_ADDR, PRCI_PLLCFG)
			| (PLL_REFSEL(1) | PLL_BYPASS(1)));
	mmio_write_u32(PRCI_CTRL_ADDR, PRCI_PLLCFG,
			mmio_read_u32(PRCI_CTRL_ADDR, PRCI_PLLCFG)
			| (PLL_SEL(1)));

	/* Turn off HFROSC to save power */
	mmio_write_u32(PRCI_CTRL_ADDR, PRCI_HFROSCCFG,
			mmio_read_u32(PRCI_CTRL_ADDR, PRCI_HFROSCCFG)
			& ~(ROSC_EN(1)));
}
