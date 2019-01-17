# Heavy work in progress !
# ahcal-axidmatcp
This is supposed to be a generic Zynq 7020 TCP server, that receives data from the axi4-stream infrastructure in the FPGA part and uses the TCP stack on Linux running on the ARM core of the Zynq. The FPGA part also provides a packet generation engine, which packs stream of successive 32-bit numbers to packets of various size (depends on Switches). Alternatively, a feedback loop can be used. 

Strongly optimized for outgoing direction (S2MM -> TCP), almost no traffic opposite direction. The project consist of following parts:
1. VHDL code, that was used as testing environment. It can work either as an echo mode (mm2s->s2mm), or a packet generation mode. PSwitches have a special meaning
   * SW0: data production generation enabled
   * SW1-4: packet size ("0000" = random size <4 kB, "0001" = 256 Bytes, "0010" = 512 bytes, ... "1101" = 1MBytes)
   * SW5: mode of operation ("1" = packet generation, "0" = feadback mode)
   * SW6-7: LED status switch
2. Linux kernel module, that presents 2 character node in the /dev folder (for reading and writing)
3. xldas: a TCP server, that reads from the character device (and writes to)
4. TCP receiving application , that checks for the missing data / data corruption checker
# Usage
VHDL part has to be synthesized via Vivado (version 2018.2 used)
Petalinux needs following changes:
  * cma=256 parameter to be passed as bootargs. In petalinux: petalinux-config, → DTG Settings → Kernel Bootargs → unset generate boot args automatically, set user set kernel bootargs to "console=ttyPS0,115200 earlyprintk cma=256M"
  * create the module: petalinux-create -t modules -n axidmachar --enable
  * remove the xilinx dma module: petalinux-config -c kernel #takes a while to start. unset → Device Drivers → DMA Engine support → Xilinx AXI DMAS Engine
# Performance
 * pseudorandom <4kB packets can be received with 72 MBytes/s (555-605 Mbits/s)
 * 1MB packets packets can be received with 78 MBytes/s (605-650 Mbits/s)

