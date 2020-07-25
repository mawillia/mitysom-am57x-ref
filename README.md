This repository contains reference FPGA and related software utilities / scripts specific
to the MitySOM-AM57X module from Critical Link.

Overview of directory structure.

mitysom-am57x-ref/
├── README.md
├── fpga
│   ├── devkit_example_a
│   │   ├── ip
│   │   │   ├── XilinxIP1
│   │   │   └── XilinxIP2
│   │   ├── scripts         
│   │   └── src
│   │       ├── constraints
│   │       └── hdl
│   ├── devkit_example_b
│   │   ├── ip
│   │   │   ├── XilinxIP1
│   │   │   └── XilinxIP2
│   │   ├── scripts
│   │   └── src
│   │       ├── constraints
│   │       └── hdl
│   └── ip                 
│       ├── gpio
│       ├── gpmc
│       └── uart
└── sw
    ├── ARM
    │   ├── library_A
    │   ├── library_B
    │   ├── scripts
    │   └── utility_A
    ├── DSP
    │   ├── library_A
    │   ├── library_B
    │   └── utility_A
    └── common

