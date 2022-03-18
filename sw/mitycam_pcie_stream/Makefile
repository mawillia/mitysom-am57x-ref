# Note:  The main CPP application for the MityCAM_PCIE_Stream example is part of 
# the MityCAM-SDK package.  Contact Critical Link for more information.

# uboot script requires mkimage, apt-get install u-boot-tools
uboot.scr: uboot_script.sh
	mkimage -T script -d uboot_script.sh -n boot_script uboot.scr
