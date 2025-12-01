
## What is AXI?

AXI, which means Advanced Extensible Interface, is an interface protocol defined by ARM as part of the AMBA (Advanced Microcontroller Bus Architecture) standard.

There are 3 types of AXI4-Interfaces:
- AXI4: For high-performance memory-mapped requirements
- AXI4-Lite: For simple, low-throughput memory-mapped communication
- AXI4-Stream: For high-speed streaming data

## AXI Read and Write Channels

The AXI protocol defines 5 channels:

- 2 are used for Read transactions
	- Read address
	- Read data
- 3 are used for Write transactions
	- Write address
	- Write data
	- Write response

A channels is an independent collection of AXI signals associated with the VALID and READY signals.

A piece of data transmitted on a single channels is called a transfer. A transfer happens when both the VALID and READY signal are high while there is a rising edge of the clock.

## AXI Read Transactions

An AXI Read transaction requires multiple transfers on the 2 Read channels

First, the Address Read channel is sent from the master to the slave to set the address and some control signals.

Then the data for this address is transmitted from the slave to the master on the Read data channel

There can be multiple data transfers per address, this type of transaction is called a burst.

## AXI Write Transactions

An AXI Write transactions requires multiple transfers on the 3 Write channels.

First, the Address Write channel is sent Master to the Slave to set the address and some control signals

Then the data for this address is transmitted Master to the Slave on the Write data channel.

Finally the write response is sent from the Slave to the Master on the Write Response channel to indicate if the transfer was successful.

The possible response values on the Write Response Channel are:

- OKAY(0b00): Normal access success. Indicates that a normal access has been successful
- EXOKAY(0x01): Exclusive access okay.
- SLVERR(0x10): Slave Error. The slave was reached successfully but the slave wishes to return an error condition to the originating master (for example, data read not valid)
- DECERR(0x11): Decode error. Generated, typically by an interconnect component, to indicate that there is no slave at the transaction address.

## AXI4 Interface Requirements

- When a VALID signal is asserted, it must remain asserted until the rising clock edge after the slave asserts the READY signal
- The VALID signal of the AXI interface sending information must not be dependent on the READY signal of the AXI interface receiving that information
	- However, the state of the READY signal can depend on the VALID signal
- A write response must always follow the last write transfer in the write transaction of which it is a part
- Read data must always follow the address to which the data relates
- A slave must wait for both ARVALID and ARREADY to be asserted before it asserts RVALID to indicate that valid data is available.

## Resources

- https://adaptivesupport.amd.com/s/question/0D52E00006hpNlRSAU/what-is-different-between-axi-master-and-slave-in-laymans-term?language=en_US
- https://adaptivesupport.amd.com/s/article/1053914?language=en_US