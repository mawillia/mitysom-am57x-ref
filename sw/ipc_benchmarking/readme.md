# IPC Benchmark Example


## Description

This example comes from TI RTOS SDK and has been updated be built outside of the RTOS make structure

Program Logic:
This example shows multiple cores running RTOS communicating with each other through the IPC MessageQ API. 
The example measures and displays the round trip delay numbers for the IPC. 
Note the main example sends multiple messages from each of the cores, with all the cores sending messages simultaneously.

## Build

### Linux
#### Prerequisite

You will need both the *TI Processor SDK for Linux* and *TI RTOS Processor SDK* in order 
to build this example. Both can be downloaded from ti: https://www.ti.com/tool/PROCESSOR-SDK-AM57X

The steps in this readme expect you to install both in your home directory and to be owned by you (not root).

Install:
```
# Download both Linux and RTOS SDK
wget https://software-dl.ti.com/processor-sdk-linux/esd/AM57X/latest/exports/ti-processor-sdk-linux-am57xx-evm-06.03.00.106-Linux-x86-Install.bin
wget https://software-dl.ti.com/processor-sdk-rtos/esd/AM57X/latest/exports/ti-processor-sdk-rtos-am57xx-evm-06.03.00.106-Linux-x86-Install.bin
# Make sure both installers have the permissions set for running
chmod a+x ti*.bin
# Install the Linux SDK (In GUI make sure to install to $HOME/ti-processor-sdk-linux-am57xx-evm-06.03.00.106)
./ti-processor-sdk-linux-am57xx-evm-06.03.00.106-Linux-x86-Install.bin
# Install the RTOS SDK
./ti-processor-sdk-rtos-am57xx-evm-06.03.00.106-Linux-x86-Install.bin --prefix $HOME/ti-processor-sdk-rtos-am57xx-evm-06.03.00.106
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

Load the firmware into DSP1:
```
# DSP1
# Create a symbolic link from the DSP1 firmware to remoteproc dsp1 firmware location
ln -sf /home/root/server_dsp1.xe66 /lib/firmware/dra7-dsp1-fw.xe66
# Stop DSP1
echo 40800000.dsp > /sys/bus/platform/drivers/omap-rproc/unbind
# Load the new firmware and start DSP1
echo 40800000.dsp > /sys/bus/platform/drivers/omap-rproc/bind
```

### Running

To specify which processor linux will exchange messages with use the following command line arguments: DSP1

```
# Communicate with DSP1
./app_host DSP1
```

Example output:
```
root@mitysom-am57x:~# ./app_host DSP1
--> main:
--> Main_main:
--> App_create:
App_create: Host is ready
<-- App_create:
--> App_exec:
App_exec: sending message 827347780
time: 37051.884000
Packets per second: 34546.151553
Size of message: 496
Number of packets transferred: 1280000
<-- App_exec: 0
--> App_delete:
<-- App_delete:
<-- Main_main:
<-- main:
```

You can also print out the log information from remote process by using the cat command on the following files:
* /sys/kernel/debug/remoteproc/remoteproc2/trace0 (DSP1 Log)

Example of DSP1 log:
```
cat /sys/kernel/debug/remoteproc/remoteproc2/trace0 
[      0.000 ] Watchdog enabled: TimerBase = 0x48086000 Freq = 19200000
[      0.000 ] Watchdog_restore registered as a resume callback
[      0.000 ] 17 Resource entries at 0x95000000
[      0.000 ] registering rpmsg-proto:rpmsg-proto service on 61 with HOST
```
