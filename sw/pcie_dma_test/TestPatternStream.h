/**
 * @file TestPatternStream.h
 * @author Greg Gluszek (greg@criticallink.com)
 * @brief definition for Test Pattern Streaming FPGA control class.
 * @version 0.1
 * @date 2022-03-17
 * 
 * @copyright Copyright (c) 2022
 * 
 */
#ifndef TEST_PATTERN_STREAM_H
#define TEST_PATTERN_STREAM_H

#include <stdint.h>
#include <stdlib.h>

/**
 * @brief a simple user space C++ control class for FPGA Test Pattern Generator.
 * 
 */
class tcTestPatternStream {
public:
	/**
	 * Constructor.
	 *
	 * \param fpgaRegsBaseAddr Offset into memory space for FPGA cores
	* \param coreBaseOffset Offset from fpgaRegsBaseAddr where this core is located.
		*/
	tcTestPatternStream(uint32_t fpgaRegsBaseAddr, uint32_t coreBaseOffset);

	~tcTestPatternStream();

	void reset(bool en);

	// TODO: add options for using inerrupts and specifying which interrupt to wait for?
	void waitForInt();

	void setAM57WAddr(uint32_t addr);

	void setBramWaddr(uint16_t addr);

	void writeBramData(uint16_t data);

	void setDmaSize(uint32_t num64bWords);

	void setBramRaddr(uint16_t addr);

private:
	static const size_t REG_MEM_SIZE = 0x1000;

	void* regMem;

	volatile uint16_t* regs;
};

#endif
