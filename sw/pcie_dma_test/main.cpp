/**
 * @file main.cpp
 * @author Greg Gluszek (greg@criticallink.com)
 * @brief sample program to test PCIE streaming example for MitySOM-AM57x
 * @version 0.1
 * @date 2022-03-17
 * 
 * @copyright Copyright (c) 2022 Critical Link LLC
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
#include <ti/cmem.h>

#include <chrono>

#include "FpgaPcieDma.h"
#include "TestPatternStream.h"

/**
 * @brief Check memory region used by DMA test pattern for correct results.
 * 
 * @param addr physical location of memory area
 * @param num16bWords number of 16 bit words streamed
 * @param startVal starting value of test pattern
 */
void checkDmaMem(uint16_t* dma_mem, uint32_t num16bWords, uint32_t startVal) {
	int errs = 0;
	int wi = 0;
	for (uint32_t idx = 0; idx < num16bWords; idx++) {
		if (dma_mem[idx] != wi + startVal) {
			printf("!!!	ERROR: dma_mem[%d] = 0x%08x. Expected val = 0x%08x	!!!\n",
				idx, dma_mem[idx], wi + startVal);
			errs++;
		}
		if (++wi >= 4096) wi -= 4096;
		if (errs > 10)
			break;
	}
	if (!errs)
		printf("Memory results (%d MB) match expected!\n",num16bWords*2/1000000);

	munmap(dma_mem, num16bWords*2);
}

/**
 * @brief Main sample program for pcie_dma_test.
 * 
 * @param argc 
 * @param argv 
 * @return int non-zero on error
 */
int main(int argc, char*argv[]) {

	if (argc < 2) {
		printf("usage pcie_dma_test num_bytes\n");
		printf("ex: ./pcie_dma_test 0x100000\n");
		return -1;
	}

	uint32_t num_bytes = strtoul(argv[1], NULL, 0);
	uint32_t tp_offset = 0x200;
	uint32_t dma_offset = 0x180;

	const int VER = 0x0DAB;
	printf("Welcome to the FPGA to AM57 PCIe DMA Test Application Ver 0x%04X!\n", VER);
	printf("\n");

	if (CMEM_init()) {
		printf("error initializing CMEM\n");
		return -1;
	}

	CMEM_AllocParams p;
	p.type = CMEM_HEAP;
	p.flags = CMEM_CACHED;
	p.alignment = 4096;
	void* cmem_memory = nullptr;
	cmem_memory = CMEM_alloc2(CMEM_CMABLOCKID, num_bytes, &p);
	if (!cmem_memory) {
		printf("Unable to allocate 0x%08X bytes of memory from CMEM\n",num_bytes);
		return -1;
	}
	uint32_t start_addr = CMEM_getPhys(cmem_memory);
	printf("CMEM allocated 0x%08X bytes at physical address 0x%08X for %p\n", num_bytes, start_addr, cmem_memory);
	
	printf("Constructing DMA class.\n");
	tcFpgaPcieDma dma(0x01000000, dma_offset);

	dma.setTxTlpMaxWords(32);

	printf("Constructing Test Pattern Stream class at offset 0x%04x.\n", tp_offset);
	tcTestPatternStream tp_stream(0x01000000, tp_offset);
	printf("\n");

	printf("Reseting DMA FPGA core.\n");
	dma.reset(true);
	dma.reset(false);
	printf("\n");

	srand(time(NULL));
	uint16_t pattern_start_val = rand();
	tp_stream.reset(true);

	tp_stream.setAM57WAddr(start_addr);
	tp_stream.setBramWaddr(0);
	// the BRAM size is a fixed 0x1000
	for (int cnt = 0; cnt < 0x1000; cnt++) {
		tp_stream.writeBramData(pattern_start_val + cnt);
	}

	tp_stream.setDmaSize(num_bytes/8);
	tp_stream.setBramRaddr(0);

	printf("Start Pattern Val = 0x%04x\n", pattern_start_val);
	printf("\n");

	printf("Starting DMAs.\n");
	printf("\n");
	
	std::chrono::steady_clock::time_point begin = std::chrono::steady_clock::now();

	tp_stream.reset(false);
	tp_stream.waitForInt();

	std::chrono::steady_clock::time_point end = std::chrono::steady_clock::now();

	float dur_us = std::chrono::duration_cast<std::chrono::microseconds>(end - begin).count();

	float num_mbytes_total = num_bytes;
	num_mbytes_total /= 1000000.0f;

	printf("DMAs complete %lf MB in %lf us (%lf MB/s).\n", num_mbytes_total, 
		dur_us, num_mbytes_total/(dur_us / 1000000.0));
	printf("\n");

	printf("Checking Results:\n");
	CMEM_cacheInv(cmem_memory, num_bytes);
	checkDmaMem((uint16_t*)cmem_memory, num_bytes/2, pattern_start_val);

	return 0;
}

