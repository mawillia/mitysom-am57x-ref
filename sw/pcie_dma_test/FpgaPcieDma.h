/**
 * @file FpgaPcieDma.h
 * @author Greg Gluszek (greg@criticallink.com)
 * @brief definition of PCIE DMA control class.
 * @version 0.1
 * @date 2022-03-17
 * 
 * @copyright Copyright (c) 2022 Critical Link, LLC
 * 
 */
#ifndef FPGA_PCIE_DMA_H
#define FPGA_PCIE_DMA_H

#include <stdint.h>

/**
 * @brief simple C++ control class for PCIE DMA streamer for MitySOM-AM57X
 * 
 */
class tcFpgaPcieDma {
public:
	/**
	 * Constructor.
	 *
  	 * \param fpgaRegsBaseAddr Offset into memory space for FPGA cores
     * \param coreBaseOffset Offset from fpgaRegsBaseAddr where this core is located.
	 */
	tcFpgaPcieDma(uint32_t fpgaRegsBaseAddr, uint32_t coreBaseOffset);

	~tcFpgaPcieDma();

	void reset(bool en);

	void setTxTlpMaxWords(uint16_t maxNumWords);
	uint16_t getTxTlpMaxWords();

private:
	static const size_t REG_MEM_SIZE = 0x1000;

	void* regMem;

	volatile uint16_t* regs;
};

#endif