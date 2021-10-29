# MessageQ with FPGA reading Example

## Description

This example comes from TI RTOS SDK and has been updated be built outside of the RTOS make structure.
This example will also read the FPGA base core version information.

Program Logic:
This is a MessageQ example using the client/server pattern. It is a two
processor example - messages are only sent between the host processor (client)
and the selected slave core (server).

The slave creates a message to pass data around. The host sends a message to
the slave core with a dummy payload. The slave then sends the message back to
the host. This process is repeated 14 times. Then the host a shutdown message
to the slave. The slave returns the message, shuts itself down and
reinitializes itself for future runs.

Power management is enabled on all slave cores in their corresponding
BIOS configuration files.

## Build

### Linux
#### Prerequisite

For Ubuntu machines you will need to add support to run 32 bit applictions, which can be done with the following commands:
```
sudo dpkg --add-architecture i386
sudo apt-get update
sudo apt-get install libc6:i386 libncurses5:i386 libstdc++6:i386
```

Next, you will need both the *TI Processor SDK for Linux* and *TI RTOS Processor SDK* in order 
to build this example. Both can be downloaded from ti: https://www.ti.com/tool/PROCESSOR-SDK-AM57X

The steps in this readme expect you to install both in your home directory and to be owned by you (not root).

Install:
```
# Download both Linux and RTOS SDK
wget https://software-dl.ti.com/processor-sdk-linux/esd/AM57X/06_03_00_106/exports/ti-processor-sdk-linux-am57xx-evm-06.03.00.106-Linux-x86-Install.bin
wget https://software-dl.ti.com/processor-sdk-rtos/esd/AM57X/06_03_02_08/exports/processor_sdk_rtos_am57xx_06_03_02_08-linux-x64-installer.run
# Make sure both installers have the permissions set for running
chmod a+x *.bin *.run
# Install the Linux SDK (In GUI make sure to install to $HOME/ti-processor-sdk-linux-am57xx-evm-06.03.00.106)
./ti-processor-sdk-linux-am57xx-evm-06.03.00.106-Linux-x86-Install.bin
# Install the RTOS SDK (In GUI make sure to install to $HOME/ti)
./processor_sdk_rtos_am57xx_06_03_02_08-linux-x64-installer.run 
```

#### Building the applications

All the pathing to the SDKs and toolchains are handled by *products.mak* and should be already setup correctly as long as both were installed into 
your home directory.

Build:
```
make
make install
```

This will create 2 binaries in *install/binaries/release*:
* app_host - Linux application (Cortex-A15)
* server_dsp1.xe66 - DSP1 firmware (C66x)

## Running the demo

These steps will now be run on the AM57x and expect that the 2 binaries generated in the build step are copied to */home/root* of the SD card.

### Prep

Load the firmware into DSP1
```
# DSP1
# Create a symbolic link from the DSP1 firmware to remoteproc dsp1 firmware location
ln -sf /home/root/server_dsp1.xe66 /lib/firmware/dra7-dsp1-fw.xe66
# Stop DSP1
echo 40800000.dsp > /sys/bus/platform/drivers/omap-rproc/unbind
# Load the new firmware and start DSP1
echo 40800000.dsp > /sys/bus/platform/drivers/omap-rproc/bind
```

You will also need to disable the openCL daemon in order to use this demo, which can be done with the following command:
```
systemctl disable ti-mct-daemon.service
```

The daemon will now remain disabled even after a reboot. To reenable it use the following command:
```
systemctl enable ti-mct-daemon.service
```

### Running

To specify which processor linux will exchange messages with use the following command line argument: DSP1

```
# Communicate with DSP1
./app_host DSP1
```

Example output:
```
root@mitysom-am57x:~# ./app_host DSP1
--> main:
[  218.490982] omap-iommu 55082000.mmu: 55082000.mmu: version 2.1
[  218.529068] omap-iommu 41501000.mmu: 41501000.mmu: version 3.0
[  218.536919] omap-iommu 41502000.mmu: 41502000.mmu: version 3.0
[  218.545191] omap-iommu 40d01000.mmu: 40d01000.mmu: version 3.0
[  218.551081] omap-iommu 40d02000.mmu: 40d02000.mmu: version 3.0
--> Main_main:
--> App_create:
App_create: Host is ready
<-- App_create:
--> App_exec:
App_exec: sending message 1
App_exec: sending message 2
App_exec: sending message 3
App_exec: message payload, FPGA base core version1 0xc000, version2 0x0, version3 0x5410, version4 0x5410
App_exec: message payload, FPGA base core id 1, major version 0, minor version 0, date 4-16-0
App_exec: message received, sending message 4
App_exec: message payload, FPGA base core version1 0x0, version2 0x5410, version3 0x8103, version4 0xc000
App_exec: message payload, FPGA base core id 0, major version 1, minor version 0, date 1-3-20
App_exec: message received, sending message 5
App_exec: message payload, FPGA base core version1 0x0, version2 0x5410, version3 0x5410, version4 0x8103
App_exec: message payload, FPGA base core id 0, major version 1, minor version 0, date 4-16-20
App_exec: message received, sending message 6
App_exec: message payload, FPGA base core version1 0x0, version2 0x5410, version3 0x8103, version4 0xc000
App_exec: message payload, FPGA base core id 0, major version 1, minor version 0, date 1-3-20
App_exec: message received, sending message 7
App_exec: message payload, FPGA base core version1 0xc000, version2 0x0, version3 0x0, version4 0x5410
App_exec: message payload, FPGA base core id 1, major version 0, minor version 0, date 0-0-0
App_exec: message received, sending message 8
App_exec: message payload, FPGA base core version1 0x0, version2 0x5410, version3 0x8103, version4 0xc000
App_exec: message payload, FPGA base core id 0, major version 1, minor version 0, date 1-3-20
App_exec: message received, sending message 9
App_exec: message payload, FPGA base core version1 0x0, version2 0x5410, version3 0x8103, version4 0xc000
App_exec: message payload, FPGA base core id 0, major version 1, minor version 0, date 1-3-20
App_exec: message received, sending message 10
App_exec: message payload, FPGA base core version1 0x0, version2 0x5410, version3 0x8103, version4 0x8103
App_exec: message payload, FPGA base core id 0, major version 1, minor version 0, date 1-3-20
App_exec: message received, sending message 11
App_exec: message payload, FPGA base core version1 0x0, version2 0x5410, version3 0x8103, version4 0x8103
App_exec: message payload, FPGA base core id 0, major version 1, minor version 0, date 1-3-20
App_exec: message received, sending message 12
App_exec: message payload, FPGA base core version1 0x0, version2 0x5410, version3 0x8103, version4 0xc000
App_exec: message payload, FPGA base core id 0, major version 1, minor version 0, date 1-3-20
App_exec: message received, sending message 13
App_exec: message payload, FPGA base core version1 0x0, version2 0x5410, version3 0x8103, version4 0x8103
App_exec: message payload, FPGA base core id 0, major version 1, minor version 0, date 1-3-20
App_exec: message received, sending message 14
App_exec: message payload, FPGA base core version1 0x0, version2 0x5410, version3 0x8103, version4 0x8103
App_exec: message payload, FPGA base core id 0, major version 1, minor version 0, date 1-3-20
App_exec: message received, sending message 15
App_exec: message received
App_exec: message received
App_exec: message received
<-- App_exec: 0
--> App_delete:
<-- App_delete:
<-- Main_main:
<-- main:

```

*NOTE: there is currently an issue with the FPGA register updating reliably, which is being working on. The correct output is as follows:*
```
App_exec: message payload, FPGA base core version1 0x0, version2 0x5410, version3 0x8103, version4 0x8103
App_exec: message payload, FPGA base core id 0, major version 1, minor version 0, date 1-3-20
```


You can also print out the log information from remote process by using the cat command on the following files:
* /sys/kernel/debug/remoteproc/remoteproc2/trace0 (DSP1 Log)
