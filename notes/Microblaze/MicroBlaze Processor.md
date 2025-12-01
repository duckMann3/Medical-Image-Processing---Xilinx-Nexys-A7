MicroBlaze is AMD 32-bit RISC Harvard Architecture soft-core processor that's optimized for embedded applications.
## Why do we need MicroBlaze in our Project?

Since we want to read files from an SD card, control hardware accelerators via AXI, and send data to VGA we need something that will continuously run C code with our Otsu algorithm which is what MicroBlaze will do for us. It essentially acts as an operating system. This makes it easier for us since we don't have to write drivers for the VGA and SD card interfaces, instead it connects through AXI in a block module where we just specify clock frequency and pixels-per-clock cycle.
## Resources

- https://www.amd.com/en/products/software/adaptive-socs-and-fpgas/microblaze.html
- https://www.youtube.com/watch?v=ooWp8SscTxM
- https://docs.amd.com/r/en-US/ug984-vivado-microblaze-ref?tocId=TgJTXF9qLhuPO_9p3XVnZQ
- https://www.geeksforgeeks.org/computer-organization-architecture/harvard-architecture/