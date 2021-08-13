# Remote Processor to ARM Benchmarking

## Description

Application used for benchmarking the remote processor to ARM messaging. The ARM requests the DSP to send
a batch of MessageQs packets to it and measures how long it takes.

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

This will create 5 binaries in *install/binaries/release*:
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

Disable the ti-mct-daemon, which is using the cmem pool
```
systemctl disable ti-mct-daemon.service
```

### Running

Usage:
```
./app_host -h
--> main:
Usage:
    app_host [options] procName

Arguments:
    procName      : the name of the remote processor

Options:
    h   : print this help message
    l   : list the available remote names
    i [interations]   : set the number of times the transfers loop for
    p [payload]   : set the payload size
    b [batches]   : set the number of batches of messages the DSP sends per loop

Examples:
    app_host DSP
    app_host -l
    app_host -h
```

Example output:
```
./app_host -i 5 DSP1
--> main:
--> Main_main:
--> App_create:
App_create: Host is ready
<-- App_create:
--> App_exec:
Number of Loops: 5
Size of buffers: 10
Number of Buffers per loop: 100
Messages per Loop: 10
CMEM_init success
CMEM_getPool success
CMEM_allocPool success: Allocated buffer 0xaa575000, phys: a0000000
Tell DSP to initialize Ring Buffer
Starting Transfers
Bytes received: 1000, elapsed time: 1.023000 ms.
Data Rate: 0.932233 MBps
csvheader, Payload Size, Bandwidth (MB/s), Buffers Transferred, Payload Data Type Size (B), ARM Cache Inv, DSP Cache WB, Transfer Time (ms), Bytes Transferred
csv, 100, 0.932233, 10, 8, 1, 1, 1.023000, 1000
Bytes received: 2000, elapsed time: 0.762000 ms.
Data Rate: 2.503082 MBps
csvheader, Payload Size, Bandwidth (MB/s), Buffers Transferred, Payload Data Type Size (B), ARM Cache Inv, DSP Cache WB, Transfer Time (ms), Bytes Transferred
csv, 100, 2.503082, 10, 8, 1, 1, 0.762000, 2000
Bytes received: 3000, elapsed time: 0.715000 ms.
Data Rate: 4.001431 MBps
csvheader, Payload Size, Bandwidth (MB/s), Buffers Transferred, Payload Data Type Size (B), ARM Cache Inv, DSP Cache WB, Transfer Time (ms), Bytes Transferred
csv, 100, 4.001431, 10, 8, 1, 1, 0.715000, 3000
Bytes received: 4000, elapsed time: 0.688000 ms.
Data Rate: 5.544618 MBps
csvheader, Payload Size, Bandwidth (MB/s), Buffers Transferred, Payload Data Type Size (B), ARM Cache Inv, DSP Cache WB, Transfer Time (ms), Bytes Transferred
csv, 100, 5.544618, 10, 8, 1, 1, 0.688000, 4000
Bytes received: 5000, elapsed time: 0.751000 ms.
Data Rate: 6.349363 MBps
csvheader, Payload Size, Bandwidth (MB/s), Buffers Transferred, Payload Data Type Size (B), ARM Cache Inv, DSP Cache WB, Transfer Time (ms), Bytes Transferred
csv, 100, 6.349363, 10, 8, 1, 1, 0.751000, 5000
Transfers Complete
Min time: 0.688000 ms, Average Time: 0.787800 ms Max time: 1.023000 ms
Average transfer time per message: 0.000788 ms
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
[      0.000] Watchdog enabled: TimerBase = 0x48086000 Freq = 19200000
[      0.000] Watchdog_restore registered as a resume callback
[      0.000] 17 Resource entries at 0x95000000
[      0.000] [t=0x00027336] xdc.runtime.Main: --> main:
[      0.000] registering rpmsg-proto:rpmsg-proto service on 61 with HOST
[      0.000] [t=0x00047d33] xdc.runtime.Main: NameMap_sendMessage: HOST 53, port=61
[      0.000] [t=0x00059078] xdc.runtime.Main: --> smain:
[      0.000] [t=0x0006989f] Server: Server_create: server is ready
[      0.000] [t=0x0006e896] Server: <-- Server_create: 0
[      0.000] [t=0x00072bb3] Server: --> Server_exec:
[      8.397] [t=0x007af09d] Server: Server_exec: processed cmd=0x0
[      8.398] [t=0x007b9d6e] Server: Server_exec: processed cmd=0x0
[      8.398] [t=0x007c2db3] Server: Server_exec: processed cmd=0x0
[      8.398] [t=0x007d8a64] Server: Server_exec: processed cmd=0x0
[      8.398] [t=0x007e285f] Server: Server_exec: processed cmd=0x0
[      8.398] [t=0x007eb568] Server: Server_exec: processed cmd=0x0
[      8.398] [t=0x007fea81] Server: Server_exec: processed cmd=0x0
[      8.398] [t=0x008087b3] Server: Server_exec: processed cmd=0x0
[      8.399] [t=0x0081ee02] Server: Server_exec: processed cmd=0x0
[      8.399] [t=0x00828b22] Server: Server_exec: processed cmd=0x0
[      8.399] [t=0x0083180d] Server: Server_exec: processed cmd=0x0
[      8.399] [t=0x0084482c] Server: Server_exec: processed cmd=0x0
[      8.399] [t=0x0084e46b] Server: Server_exec: processed cmd=0x0
[      8.399] [t=0x00861474] Server: Server_exec: processed cmd=0x0
[      8.399] [t=0x0086b212] Server: Server_exec: processed cmd=0x2000000
[      8.399] [t=0x00874485] Server: <-- Server_exec: 0
[      8.399] [t=0x0087a5c9] Server: --> Server_delete:
[      8.400] [t=0x00883f56] Server: <-- Server_delete: 0
[      8.400] [t=0x00892aee] Server: Server_create: server is ready
[      8.400] [t=0x00899562] Server: <-- Server_create: 0
[      8.400] [t=0x0089eb7e] Server: --> Server_exec:
```
