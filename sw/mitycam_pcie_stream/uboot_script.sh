setenv fdtfile am57xx-mitysom-devkit-mitycam.dtb
setenv fpgafile mitycam_pcie_stream_top.bin
size ${devtype} 0 ${fpgafile}
setenv loadfpga "echo Loading fpga file: ${fpgafile}; load ${devtype} 0 ${loadaddr} ${fpgafile}; fpga load 0 ${loadaddr} ${filesize};"
