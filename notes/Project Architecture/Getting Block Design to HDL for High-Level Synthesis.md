The method that we are going to use to get our block design into high-level synthesis is called HDL Wrapping. Our IP integrator block design can be integrated into high-level design through the creations of a top-level HDL wrapper that wraps around our block design. This will allows us to synthesize and generate the bitstream of the block module which will produce an XSA file that will be exported into our Vitis project.

## Step 1: Instantiate HDL Wrapper

To instantiate our HDL wrapper we have to right-click on our block design and select Create HDL Wrapper. From there it'll prompt us to either 

## Step 2: Create the bitstream for the Block Design

To create the bitstream for the block design we need to run synthesis and implementation. We make sure that there are no timing violations, critical warnings, or errors for the design. Then we run the create bitstream which creates a .bit file for us.

## Step 3: Export Hardware to Vitis

You then have to export an XSA file for Vitis so that it knows our hardware layout.

You have to click on file, then export, and then export hardware. From there you can check include bitstream and then save the .XSA file.
## Resources:

- https://docs.amd.com/r/en-US/ug994-vivado-ip-subsystems/Resource-Estimation-in-Block-Design
- https://docs.amd.com/r/en-US/ug1400-vitis-embedded/Creating-a-Hardware-Design-XSA-File
- https://xilinx.github.io/Vitis-Tutorials/2021-1/build/html/docs/Vitis_Platform_Creation/Introduction/02-Edge-AI-ZCU104/step1.html
- https://www.youtube.com/watch?v=-6HNWWiOs3E