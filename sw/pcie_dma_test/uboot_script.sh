setenv fpgafile pcie_dma_example.bin
size ${devtype} 0 ${fpgafile}
setenv loadfpga "echo Loading fpga file: ${fpgafile}; load ${devtype} 0 ${loadaddr} ${fpgafile}; fpga load 0 ${loadaddr} ${filesize};"
