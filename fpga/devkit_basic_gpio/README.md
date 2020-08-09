# MitySOM-AM57X DevKit Basic GPIO Reference Project

This document describes the contents of this folder, which contains
the reference project files for the MitySOM-AM57X FPGA build supporting
the development kit.

References:

## Creating the Vivado Project (GUI / Project Mode)

To create a Vivado project to support running vivado, run the following TCL script to build the project.

vivado -mode batch -source script/gen_devkit_project.tcl

This will create a project at ./devkit/devkit.xpr, using external references for the provided
source files.

## Building the project from the Command line.

To create a bitstream running vivado in non-project mode, run the following TCL script to build the project.

vivado -mode batch -source ./script/build_devkit_bitstream_batch.tcl

This will create an output folder ./devkit_output and will place the build report files as well as a generated bitstream.

## Project overview

This project provides the following capability for the FPGA:

- block RAM connected on the PCIe endpoint to support PCIe IO
-- This is a copy of the basic PCIe demo setup from Xilinx
- the GPMC register interface, including a base module and GPIO
- GPIO connections to the FMC connector
- Video simulation to drive the AM57x video input port in 24 bit mode

Stuff remaining / TODO
- Route interrupts from FPGA to processor
- Add external interface timing constraints

### Directory Contents

The local / project specific files for the project are listed below.

In addition, common ip files (provided by Critical Link) are included from ../ip (above the devkit_basic_gpio folder).

```
.
├── ip                              // Xilinx Generated IP data
│   ├── clk_wiz_0
│   │   ├── clk_wiz_0.xci
│   │   ├── clk_wiz_0.xml
│   └── pcie_7x_0
│       ├── pcie_7x_0.xci
│       ├── pcie_7x_0.xml
├── README.md                       // This document
├── script
│   └── gen_devkit_project.tcl      // Script to build Vivado Project
└── src
    ├── constraints                 // Vivado Timing Constraints
    │   ├── devkit_top.xdc
    │   └── xilinx_pcie_7x_ep_x2g2.xdc
    └── hdl                         // Project HDL source files.
        ├── devkit_top.vhd
        ├── EP_MEM.vhd
        ├── pcie_7x_0_pipe_clock.v
        ├── pcie_7x_0_support.vhd
        ├── pcie_app_7x.vhd
        ├── PIO.vhd
        ├── PIO_EP.vhd
        ├── PIO_EP_MEM_ACCESS.vhd
        ├── PIO_RX_ENGINE.vhd
        ├── PIO_TO_CTRL.vhd
        ├── PIO_TX_ENGINE.vhd
        └── xilinx_pcie_2_1_ep_7x.vhd
```
