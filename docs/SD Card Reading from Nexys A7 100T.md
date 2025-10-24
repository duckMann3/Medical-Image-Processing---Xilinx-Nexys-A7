# SD Card Reading From Nexys A7 100T

The goal is to read a 512-byte block from the Nexys A7-100T microSD slot using SPI mode in Verilog.
## Serial Peripheral Interface (SPI)

SPI is a serial communication protocol used between microcontrollers and peripherals. It uses 4 main signals:

- MOSI - Master Out, Slave In
- MISO - Master In, Slave Out
- SCK - Serial Clock
- SS (or CS) - Slave Select / Chip Select
## SPI Modes (0-3)

SPI has four modes, which define how data is sampled relative to the clock. We want mode 0 for our board because we want for our clock to be low during our idle state. We also want for the data to be samples on the rising edge of the clock and then to be changed on the falling edge of the clock.
### Chip Select Line:
- Low - the selected slave listens and communicates.
- High - the slave ignores the bus.

When SPI is described as byte-synchronous, it means:

- The communication is organized in byte units (8 bits)
- The SPI master asserts and de-asserts the chip-select signal in sync with each byte transfer, meaning that it pulls the select line low, performs the 8-bit transfer, and then pulls it high again.
- The slave expects data in 8-bit frames - so every 8 clock pulses correspond to one byte of transmitted data.