/**
 * @file FpgaPcieDma.cpp
 * @author Greg Gluszek (greg@criticallink.com)
 * @brief Implementation for PCIE DMA streamer control class.
 * @version 0.1
 * @date 2022-03-17
 * 
 * @copyright Copyright (c) 2022
 * 
 */
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <stdint.h>
#include <string.h>
#include <errno.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>

#include "FpgaPcieDma.h"

#define FPGA_PCIE_DMA_VER_REG_OFFSET              (0)
#define FPGA_PCIE_DMA_CTRL_REG_OFFSET             (1)
#define FPGA_PCIE_DMA_TX_TLP_MAX_WORDS_REG_OFFSET (2)

tcFpgaPcieDma::tcFpgaPcieDma(uint32_t fpgaRegsBaseAddr, uint32_t coreBaseOffset) 
: regMem(NULL)
{
	int dev_mem_fd = open("/dev/mem", O_RDWR);
	if (dev_mem_fd < 0)
	{
		printf("%s: open('/dev/mem') failed. %s", __func__,
				strerror(errno));
		return;
	}

	regMem = mmap(NULL, REG_MEM_SIZE, PROT_WRITE | PROT_READ, MAP_SHARED, 
	dev_mem_fd, fpgaRegsBaseAddr);

	close(dev_mem_fd);

	if (MAP_FAILED == regMem) {
		printf("%s: mmap(0x%08x) failed. %s\n", __func__, fpgaRegsBaseAddr,
				strerror(errno));
		regMem = NULL;
		return;
	}

	regs = (uint16_t*)((uint32_t)regMem + coreBaseOffset);

	printf("FPGA PCIe DMA Core Version = 0x%04x\n", regs[FPGA_PCIE_DMA_VER_REG_OFFSET]);
}

tcFpgaPcieDma::~tcFpgaPcieDma() {
	munmap(regMem, REG_MEM_SIZE);
}

void tcFpgaPcieDma::reset(bool en) {
	uint16_t val = regs[FPGA_PCIE_DMA_CTRL_REG_OFFSET];	
	if (en) {
		val |= 0x0001;
	} else {
		val &= 0xFFFE;
	}
	regs[FPGA_PCIE_DMA_CTRL_REG_OFFSET] = val;
}

void tcFpgaPcieDma::setTxTlpMaxWords(uint16_t maxNumWords) {
	regs[FPGA_PCIE_DMA_TX_TLP_MAX_WORDS_REG_OFFSET] = maxNumWords;
}

uint16_t tcFpgaPcieDma::getTxTlpMaxWords() {
	return regs[FPGA_PCIE_DMA_TX_TLP_MAX_WORDS_REG_OFFSET];
}
