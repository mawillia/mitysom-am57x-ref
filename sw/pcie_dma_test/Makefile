# Makefile for DMA test program
# Critical Link, LLC 2022

SOURCES=main.cpp TestPatternStream.cpp FpgaPcieDma.cpp
OBJS=$(SOURCES:.cpp=.o)

.cpp.o:
	$(CXX) $(CFLAGS) -c $< -o $@

pcie_dma_test: $(OBJS)
	$(CXX) $(CFLAGS) $(OBJS) -lticmem -o $@

clean:
	rm -f $(OBJS) pcie_dma_test uboot.scr

# uboot script requires mkimage, apt-get install u-boot-tools
uboot.scr: uboot_script.sh
	mkimage -T script -d uboot_script.sh -n boot_script uboot.scr

all: pcie_dma_test uboot.scr