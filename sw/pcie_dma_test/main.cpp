
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

#include <chrono>



#define FPGA_PCIE_DMA_VER_REG_OFFSET (0)
#define FPGA_PCIE_DMA_CTRL_REG_OFFSET (1)

#define FPGA_PCIE_DMA_TX_TLP_MAX_WORDS_REG_OFFSET (2)

#define FPGA_PCIE_DMA_RX_TLP_DATA_LO_LO_REG_OFFSET (4)
#define FPGA_PCIE_DMA_RX_TLP_DATA_LO_HI_REG_OFFSET (5)
#define FPGA_PCIE_DMA_RX_TLP_DATA_HI_LO_REG_OFFSET (6)
#define FPGA_PCIE_DMA_RX_TLP_DATA_HI_HI_REG_OFFSET (7)

#define FPGA_PCIE_DMA_RX_TLP_CTNR_REG_OFFSET (8)

#define DGB_DATA_IN_CNTR_LO_REG_OFFSET (10)
#define DGB_DATA_IN_CNTR_HI_REG_OFFSET (11)

#define DGB_DATA_DOUT_CNTR_LO_REG_OFFSET (12)
#define DGB_DATA_DOUT_CNTR_HI_REG_OFFSET (13)

#define DGB_PCIE_ADDR_LO_REG_OFFSET (14)
#define DGB_PCIE_ADDR_HI_REG_OFFSET (15)

#define DGB_DATA_LEN_LO_REG_OFFSET (16)
#define DGB_DATA_LEN_HI_REG_OFFSET (17)

#define DBG_TX_RD_REQ_CLOCK0_STATE_DBG_CNTR_REG_OFFSET (18)
#define DBG_TX_TLP_CLOCK1_STATE_DBG_CNTR_REG_OFFSET (19)


class tcFpgaPcieDma {
public:
	/**
	 * Constructor.
	 *
  	 * \param baseOffset Offset into memory space for FPGA cores where
	 *  this particular core is located (e.g. 0x00000080, 0x00000100).
	 */
	tcFpgaPcieDma(uint32_t fpgaRegsBaseAddr, uint32_t coreBaseOffset);

	~tcFpgaPcieDma();

	void reset(bool en);

	uint16_t dbgGetState();

	void setTxTlpMaxWords(uint16_t maxNumWords);
	uint16_t getTxTlpMaxWords();

	uint64_t getLastRxTlpWord();

	uint16_t getRxTlpCnt();

	uint32_t getDbgDataInCntr();
	uint32_t getDbgDataOutCntr();
	uint32_t getDbgPcieAddr();
	uint32_t getDbgDataLen();
	uint16_t getDbgState();
	uint16_t getDbgRdRqStateCntr();
	uint16_t getDbgTxRqStateCntr();

private:
	static const size_t REG_MEM_SIZE = 0x1000;

	void* regMem;

	volatile uint16_t* regs;
};

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


uint16_t tcFpgaPcieDma::dbgGetState() {
	uint16_t val = regs[FPGA_PCIE_DMA_CTRL_REG_OFFSET];	
	return (val & 0xFF00);
}

void tcFpgaPcieDma::setTxTlpMaxWords(uint16_t maxNumWords) {
	regs[FPGA_PCIE_DMA_TX_TLP_MAX_WORDS_REG_OFFSET] = maxNumWords;
}

uint16_t tcFpgaPcieDma::getTxTlpMaxWords() {
	return regs[FPGA_PCIE_DMA_TX_TLP_MAX_WORDS_REG_OFFSET];
}

uint64_t tcFpgaPcieDma::getLastRxTlpWord() {
	volatile uint64_t* val_ptr= (volatile uint64_t*)&regs[FPGA_PCIE_DMA_RX_TLP_DATA_LO_LO_REG_OFFSET];
	return *val_ptr;
}

uint32_t tcFpgaPcieDma::getDbgDataInCntr() {
	volatile uint32_t* val_ptr= (volatile uint32_t*)&regs[DGB_DATA_IN_CNTR_LO_REG_OFFSET];
	return *val_ptr;
}

uint16_t tcFpgaPcieDma::getRxTlpCnt() {
	return regs[FPGA_PCIE_DMA_RX_TLP_CTNR_REG_OFFSET];
}

uint32_t tcFpgaPcieDma::getDbgDataOutCntr() {
	volatile uint32_t* val_ptr= (volatile uint32_t*)&regs[DGB_DATA_DOUT_CNTR_LO_REG_OFFSET];
	return *val_ptr;
}

uint32_t tcFpgaPcieDma::getDbgPcieAddr() {
	volatile uint32_t* val_ptr= (volatile uint32_t*)&regs[DGB_PCIE_ADDR_LO_REG_OFFSET];
	return *val_ptr;
}

uint32_t tcFpgaPcieDma::getDbgDataLen() {
	volatile uint32_t* val_ptr= (volatile uint32_t*)&regs[DGB_DATA_LEN_LO_REG_OFFSET];
	return *val_ptr;
}

uint16_t tcFpgaPcieDma::getDbgState() {
	return regs[FPGA_PCIE_DMA_CTRL_REG_OFFSET];
}

uint16_t tcFpgaPcieDma::getDbgRdRqStateCntr() {
	return regs[DBG_TX_RD_REQ_CLOCK0_STATE_DBG_CNTR_REG_OFFSET];
}

uint16_t tcFpgaPcieDma::getDbgTxRqStateCntr() {
	return regs[DBG_TX_TLP_CLOCK1_STATE_DBG_CNTR_REG_OFFSET];
}




#define TP_STREAM_VER_REG_OFFSET (0)
#define TP_STREAM_CTRL_REG_OFFSET (1)

#define TP_STREAM_ISR_REG_OFFSET (2)

#define TP_STREAM_AM57_WADDR_LO_REG_OFFSET (4)
#define TP_STREAM_AM57_WADDR_HI_REG_OFFSET (5)

#define TP_STREAM_BRAM_WADDR_REG_OFFSET (6)

#define TP_STREAM_BRAM_DATA_REG_OFFSET (8)

#define TP_STREAM_PACKET_SIZE_LO_REG_OFFSET (10)
#define TP_STREAM_PACKET_SIZE_HI_REG_OFFSET (11)

#define TP_STREAM_BRAM_START_ADDR_REG_OFFSET (12)

class tcTestPatternStream {
public:
	/**
	 * Constructor.
	 *
  	 * \param baseOffset Offset into memory space for FPGA cores where
	 *  this particular core is located (e.g. 0x00000080, 0x00000100).
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


void checkDmaMem(uint32_t addr, uint32_t num16bWords, uint32_t startVal) {
	int dev_mem_fd = open("/dev/mem", O_RDWR);                              
        if (dev_mem_fd < 0)                                                     
        {                                                                       
                printf("%s: open('/dev/mem') failed. %s", __func__,             
                        strerror(errno));                                       
		return;
        }                                                                       
                                                                                
        uint16_t* dma_mem = (uint16_t*)mmap(NULL, num16bWords*2, PROT_WRITE | 
		PROT_READ, MAP_SHARED, dev_mem_fd, addr);

	close(dev_mem_fd);                                                      
                                                                                
        if (MAP_FAILED == dma_mem) {                                           
                printf("%s: mmap(0x%08x) failed. %s\n", __func__, addr,         
                        strerror(errno));                                       
		return;
        }         


	for (uint32_t idx = 0 ; idx < num16bWords; idx++) {
		if (dma_mem[idx] != idx + startVal) {
			printf("!!!	ERROR: dma_mem[%d] = 0x%08x. Expected val = 0x%08x	!!!\n",
				idx, dma_mem[idx], idx + startVal);
		}
	}
	
	munmap(dma_mem, num16bWords*2);
}

int main(int argc, char*argv[]) {
	if (argc < 2) {
		printf("usage pcie_dma_test start_addr num_words\n");
		printf("ex: ./pcie_dma_test 0xC0000000 0xFFF\n");
		return -1;
	}

	uint32_t start_addr = strtoul(argv[1], NULL, 0);
	// Number of 16 bit words
	uint32_t num_words = strtoul(argv[2], NULL, 0);

	const int VER = 0x0DAB;
	
	printf("Welcome to the FPGA to AM57 PCIe DMA Test Application Ver 0x%0x4!\n", VER);
	printf("\n");
	
	printf("Constructing DMA class.\n");
	tcFpgaPcieDma dma(0x01000000, 0x180);

	dma.setTxTlpMaxWords(32);

	printf("Constructing Test Pattern Stream class.\n");
	tcTestPatternStream tp_stream(0x01000000, 0x200);
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
	for (int cnt = 0; cnt < num_words; cnt++) {
		tp_stream.writeBramData(pattern_start_val + cnt);
	}

	tp_stream.setDmaSize(num_words/4);
	tp_stream.setBramRaddr(0);

	printf("Start Pattern Val = 0x%04x\n", pattern_start_val);
	printf("\n");

	printf("Starting DMAs.\n");
	printf("\n");
	
	std::chrono::steady_clock::time_point begin = std::chrono::steady_clock::now();

	tp_stream.reset(false);

	sleep(1);
	printf("data in = %d\n", dma.getDbgDataInCntr());
	printf("data out  = %d\n", dma.getDbgDataOutCntr());
	printf("pcie addr = 0x%08x\n", dma.getDbgPcieAddr());
	printf("data len = %d\n", dma.getDbgDataLen());
	printf("state = 0x%04x\n", dma.getDbgState());
	printf("RX TLP Count %d\n", dma.getRxTlpCnt());
	printf("RX TLP Word 0x%016X\n", dma.getLastRxTlpWord());
	printf("RdRqStateCntr = %d\n", dma.getDbgRdRqStateCntr());
	printf("TxRqStateCntr = %d\n", dma.getDbgTxRqStateCntr());
	printf("\n");

	tp_stream.waitForInt();

	std::chrono::steady_clock::time_point end = std::chrono::steady_clock::now();

	float dur_us = std::chrono::duration_cast<std::chrono::microseconds>(end - begin).count();

	int num_mbytes_total = num_words * sizeof(uint16_t);

	printf("DMAs complete %lf MB in %lf us (%lf MB/s).\n", num_mbytes_total, 
		dur_us, num_mbytes_total/(dur_us / 1000000.0));
	printf("\n");

	checkDmaMem(start_addr, num_words, pattern_start_val);

	printf("DMA state = 0x%04x\n", dma.dbgGetState());
	printf("Max TLP Words = %d\n", dma.getTxTlpMaxWords());
	printf("RX TLP Count %d\n", dma.getRxTlpCnt());
	printf("RX TLP Word 0x%016X\n", dma.getLastRxTlpWord());

	printf("BOSSANUVA!\n");

	return 0;
}

