### clk_wiz_0 (Clocking Wizard)

This is a block that generates a clock signal at a certain timing (in our case 100 Mhz) to make sure that all of our peripherals are on the same clock signal.
### mig_7series_0 (Memory Interface Generator)

The Memory Interface Generator IP is a core that simplifies connecting FPGAs to our DDR2 memory. You can choose settings like memory speed (in our case DDR2), and data width (ours is handled automatically), and frequency (it's 200 Mhz, but it works fine with the reference clock).
### axi_interconnect_0 (AXI Interconnect)

This is the AXI interconnect which is a module that allows for the system to route data between multiple master and slave interfaces. We use this to connect and stream data through all of our peripherals.
### axi_vdma_0 (AXI Video Direct Memory Access)

This is also called a VDMA block. This is an IP Core that provides high-bandwidth data transfer between system memory and an AXI4-Stream video interface. 

The AXI DMA distinguishes between 2 different channels called MM2S (memory-mapped to stream) which transports DDR memory to the FPGA. And S2MM (stream to memory-mapped) which transports data stream to DDR memory.

### v_tc_0 (Video Timing Controller)

The Video Timing Controller is an IP that is a general purpose video timing detector and generator, which detects blanking and active data timing based on horizontal and vertical synchronization pulses. The core is usually used with AXI4-Stream to Video Out IP (what we are using) to detect the format and timing of incoming video data and generate outgoing video timing for down

### v_axi4s_vid_out_0 (AXI4-Stream to Video Out)

This is the IP component that takes input from both the Video Timing Controller and the VDMA IP to generate output signals for video data. This will be used with our VGA to output video for the images.

### axi_gpio_0 (AXI GPIO)

This is an IP that provides general purpose input/output interface to the AXI interface. This is going to be used with our switches which will interact with the AXI Interrupt controller that will allow us to switch between different images.
### axi_intc_0 (AXI Interrupt Controller)

This is an IP that receives multiple inputs from different peripherals and interrupts to a single output to the MicroBlaze processor.

For our core the IP wasn't able to receive multiple inputs from different peripherals so our workaround was through primitive block modules like the concatenation block which takes 4 inputs and outputs a single 4-bit bus. And the Utility Reduced Logic block which takes the 4-bit bus input and utilizes an OR gate to switch between the 4 inputs and output to the AXI Interrupt Controller.

### axi_quad_spi_0 (AXI Quad SPI)

This is an IP core that connects the AXI4 interface to slave devices that use SPI (a.k.a. our SD card readings). There are 3 modes within this core which are standard SPI, Dual SPI mode, and Quad SPI. We are just going to be using regular SPI mode for our SD card readings.

### axi_uartlite_0 (AXI Uartlite)

This is an IP core that uses a UART to control the data transmission using the AXI4 interface to our VGA.

## Resources

- (MIG 7 Series) https://www.ic-components.com/blog/Understanding-Xilinx-MIG-DDR3-Complete-Details.jsp
- (MIG 7 Series) https://fpgaemu.readthedocs.io/en/latest/mig.html
- (Clocking Wizard) https://www.amd.com/en/products/adaptive-socs-and-fpgas/intellectual-property/clocking_wizard.html
- (AXI Interconnects) https://www.amd.com/en/products/adaptive-socs-and-fpgas/intellectual-property/axi_interconnect.html
- (AXI Interconnects) https://www.allaboutcircuits.com/technical-articles/what-are-axi-interconnects-tutorial-master-slave-digital-logic/
- (AXI VDMA) https://lauri.võsandi.com/hdl/zynq/xilinx-dma.html
- (Video Timing Controller) https://www.amd.com/en/products/adaptive-socs-and-fpgas/intellectual-property/ef-di-vid-timing.html
- (AXI4-Stream to Video Out) https://docs.amd.com/r/en-US/ug934_axi_videoIP/AXI4-Stream-to-Video-Out
- (AXI GPIO) https://www.amd.com/en/products/adaptive-socs-and-fpgas/intellectual-property/axi_gpio.html
- (AXI GPIO) https://pynq.readthedocs.io/en/v2.0/pynq_libraries/axigpio.html
- (AXI Interrupt Controller) https://www.amd.com/en/products/adaptive-socs-and-fpgas/intellectual-property/axi_intc.html
- (AXI Quad SPI) https://www.amd.com/en/products/adaptive-socs-and-fpgas/intellectual-property/axi_quadspi.html
- (AXI Uartlite) https://www.amd.com/en/products/adaptive-socs-and-fpgas/intellectual-property/axi_uartlite.html
