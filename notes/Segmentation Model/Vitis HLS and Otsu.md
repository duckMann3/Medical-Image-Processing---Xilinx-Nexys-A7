
## What is Vitis HLS?

Vitis HLS is a tool that allows users to easily create complex FPGA algorithms by synthesizing a C/C++ functions into RTL. You can apply specific directives within your C code to create the RTL specific to a desired implementation.
### C-to-RTL Conversion

The Vitis HLS tool synthesizes different parts of C code differently. The top-level function arguments of the C/C++ code are synthesized into RTL I/O ports and are automatically implemented with an interface synthesis hardware protocol.
### IP Export

The output of the Vitis HLS tools is an RTL implementation that can be either packaged into a compiled object file (.xo) or exported to an RTL IP:

- Compiled object files (.xo) is used to create hardware acceleration functions for use in the Vitis application development flow.
- IP can be added using the Vivado IP integrator tool

## Otsu Thresholding in Vitis Vision Library

Otsu method is used to find the threshold which can minimize the intra class variance which separates two classes defined by weighted sum of variances of two classes

$$\sigma_w^2(t) = w_1\sigma_1^2(t) + w_2\sigma_2^2(t)$$
Where, $w_1$ is the class probability computed from the histogram
### API Syntax

```template<int SRC_T, int ROWS, int COLS,int NPC=1, int XFCVDEPTH_IN = _XFCVDEPTH_DEFAULT>  OtsuThreshold(xf::cv::Mat<SRC_T, ROWS, COLS, NPC, XFCVDEPTH_IN> & _src_mat, uint8_t &_thresh)```

### Parameters and their Descriptions

SRC_T: Input pixel typ. Only 8-bit, unsigned, 1 channel is supported (XF_8UC1)
ROWS: Maximum height of input and output image.
COLS: Maximum width of input and output image (must be a multiple of 8, for 8-pixel operation)
- We are using 256x256 images for our operations
NPC: Number of pixels to be processed per cycle; possible options are XF_NPPC1 and XF_NPPC8 for 1 pixel and 8 pixel operations respectively.
- We can try 8 pixel operations initially, if it's too much, just go back to 1 pixel.
XFCVDEPTH_IN: Depth of the input image.
XFCVDEPTH_OUT: Depths of the output image
_src_ma t: Input Image
_thresh: Output threshold value after the computation
## Resources

- https://www.amd.com/en/products/software/adaptive-socs-and-fpgas/vitis/vitis-hls.html
- https://www.amd.com/en/products/software/adaptive-socs-and-fpgas/vitis/vitis-libraries/vitis-vision.html
- https://docs.amd.com/r/en-US/Vitis_Libraries/vision/api-reference.html_1_80
- https://scikit-image.org/docs/0.23.x/auto_examples/segmentation/plot_thresholding.html
- https://www.youtube.com/watch?v=jUUkMaNuHP8