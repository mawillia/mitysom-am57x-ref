/**
 * @file TestPatternStream.cpp
 * @author Greg Gluszek (greg@criticallink.com)
 * @brief Implementation for Test Pattern Stream generator C++ control class.
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
#include "TestPatternStream.h"

#define TP_STREAM_VER_REG_OFFSET             (0)
#define TP_STREAM_CTRL_REG_OFFSET            (1)
#define TP_STREAM_ISR_REG_OFFSET             (2)
#define TP_STREAM_AM57_WADDR_LO_REG_OFFSET   (4)
#define TP_STREAM_AM57_WADDR_HI_REG_OFFSET   (5)
#define TP_STREAM_BRAM_WADDR_REG_OFFSET      (6)
#define TP_STREAM_BRAM_DATA_REG_OFFSET       (8)
#define TP_STREAM_PACKET_SIZE_LO_REG_OFFSET  (10)
#define TP_STREAM_PACKET_SIZE_HI_REG_OFFSET  (11)
#define TP_STREAM_BRAM_START_ADDR_REG_OFFSET (12)

tcTestPatternStream::tcTestPatternStream(uint32_t fpgaRegsBaseAddr, uint32_t coreBaseOffset) 
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

	printf("%s  Core Version = 0x%04x\n", __func__, regs[TP_STREAM_VER_REG_OFFSET]);
}

tcTestPatternStream::~tcTestPatternStream() {
	munmap(regMem, REG_MEM_SIZE);
}

void tcTestPatternStream::reset(bool en) {
	uint16_t val = regs[TP_STREAM_CTRL_REG_OFFSET];	
	if (en) {
		val |= 0x0001;
	} else {
		val &= 0xFFFE;
	}
	regs[TP_STREAM_CTRL_REG_OFFSET] = val;
}

void tcTestPatternStream::waitForInt() {
	uint16_t reg_val = 0;
	while (!(reg_val = regs[TP_STREAM_ISR_REG_OFFSET])) {
	}

	printf("Interrupt detected 0x%04x\n", reg_val);

	// Clear interrupt
	regs[TP_STREAM_ISR_REG_OFFSET] = reg_val;
}

void tcTestPatternStream::setAM57WAddr(uint32_t addr) {
	volatile uint32_t* val_ptr = (volatile uint32_t*)&regs[TP_STREAM_AM57_WADDR_LO_REG_OFFSET];
	*val_ptr = addr;
}

void tcTestPatternStream::setBramWaddr(uint16_t addr) {
	regs[TP_STREAM_BRAM_WADDR_REG_OFFSET] = addr;
}

void tcTestPatternStream::writeBramData(uint16_t data) {
	regs[TP_STREAM_BRAM_DATA_REG_OFFSET] = data;
}

void tcTestPatternStream::setDmaSize(uint32_t num64bWords) {
	volatile uint32_t* val_ptr = (volatile uint32_t*)&regs[TP_STREAM_PACKET_SIZE_LO_REG_OFFSET];
	*val_ptr = num64bWords;
}

void tcTestPatternStream::setBramRaddr(uint16_t addr) {
	regs[TP_STREAM_BRAM_START_ADDR_REG_OFFSET] = addr;
}
