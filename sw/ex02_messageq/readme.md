# MessageQ Example


## Description

This example comes from TI RTOS SDK and has been updated be built outside of the RTOS make structure

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
* server_dsp2.xe66 - DSP2 firmware (C66x)
* server_ipu1.xem4 - IPU1 firmware (Cortex-M4) 
* server_ipu2.xem4 - IPU2 firmware (Cortex-M4) 

## Running the demo

These steps will now be run on the AM57x and expect that the 5 binaries generated in the build step are copied to */home/root* of the SD card.

NOTE: IPU1 is used for multimedia processing in linux and will already be used in this demo.

### Prep

Load the firmware into DSP1, DSP2, and IPU2:
```
# DSP1
# Create a symbolic link from the DSP1 firmware to remoteproc dsp1 firmware location
ln -sf /home/root/server_dsp1.xe66 /lib/firmware/dra7-dsp1-fw.xe66
# Stop DSP1
echo 40800000.dsp > /sys/bus/platform/drivers/omap-rproc/unbind
# Load the new firmware and start DSP1
echo 40800000.dsp > /sys/bus/platform/drivers/omap-rproc/bind

# DSP2
# Create a symbolic link from the DSP2 firmware to remoteproc dsp2 firmware location
ln -sf /home/root/server_dsp2.xe66 /lib/firmware/dra7-dsp2-fw.xe66
# Stop DSP2
echo 41000000.dsp > /sys/bus/platform/drivers/omap-rproc/unbind
# Load the new firmware and start DSP2
echo 41000000.dsp > /sys/bus/platform/drivers/omap-rproc/bind

# IPU2
# Create a symbolic link from the IPU2 firmware to remoteproc ipu2 firmware location
ln -sf /home/root/server_ipu2.xem4 /lib/firmware/dra7-ipu2-fw.xem4
# Stop IPU2
echo 55020000.ipu > /sys/bus/platform/drivers/omap-rproc/unbind
# Load the new firmware and start IPU2
echo 55020000.ipu > /sys/bus/platform/drivers/omap-rproc/bind
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

To specify which processor linux will exchange messages with use the following command line arguments: DSP1, DSP2, IPU1, or IPU2

NOTE: IPU1 is used for multimedia processing in linux and will already be used in this demo.

```
# Communicate with DSP1
./app_host DSP1

# Communicate with DSP2
./app_host DSP2

# Communicate with IPU2
./app_host IPU2
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
App_exec: sending message 1
App_exec: sending message 2
App_exec: sending message 3
App_exec: message received, sending message 4
App_exec: message received, sending message 5
App_exec: message received, sending message 6
App_exec: message received, sending message 7
App_exec: message received, sending message 8
App_exec: message received, sending message 9
App_exec: message received, sending message 10
App_exec: message received, sending message 11
App_exec: message received, sending message 12
App_exec: message received, sending message 13
App_exec: message received, sending message 14
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

You can also print out the log information from remote process by using the cat command on the following files:
* /sys/kernel/debug/remoteproc/remoteproc2/trace0 (DSP1 Log)
* /sys/kernel/debug/remoteproc/remoteproc3/trace0 (DSP2 Log)
* /sys/kernel/debug/remoteproc/remoteproc0/trace0 (IPU1 Log)
* /sys/kernel/debug/remoteproc/remoteproc1/trace0 (IPU2 Log)

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

