
## Big Picture/Staging

1. Load one 8-bit greyscale image
2. Resize to 640 x 480 (what VGA should show)
3. Run a pipeline of stages, in order:
	1. LUT
	2. Gaussian (3x3) Denoising
	3. Unsharp
	4. Sobel
	5. Otsu
	6. Morphology
	7. (optional) NN segmentation
4. Overlay the results (edges, masks, segmentation colors) on top of the original greyscale so you can see what changed
5. Display the frame; repeat for the next image, optionally pace to ~60hz to feel "real-time"

## LUT Mapping

**What**: A Look-Up Table maps input gray 0...255 --> output 0...255 with a precomputed table
**Why**: Instant, cheap brightness/contrast shaping - matches what you'd do in a fixed-point FPGA

Modes we include:
- identity - do nothing
- gamma - curve: output = (input  / 255)^ x 255; y < 1 brightens shadows, y > 1 darkens.
- CLAHE - "adaptive histogram equalization": locally stretches contrast without blowing out noise too much.

## Gaussian Blur 3x3 (Denoising)

A tiny blur using a 3x3 kernel (weights approximate a Gaussian)

Reduces small, isolated noise so later stages (unsharp, Sobel, Otsu) are more stable.

FPGA Analogy: 3 line buffers feed a 3x3 window; multiple-accumulate; normalize.

## Unsharp Masking (sharpening by adding detail)

1. Blur the image.
2. Compute detail = original - blur
3. Sharpened = original + amount x detail;

Enhances edges and fine structure (bones, boundaries)

The amount sets "how much extra detail"

FPGA analogy: another 3x3 blur + subtract + scale + add, all in fixed-point

## Sobel Edges (where intensity changes fast)

Two 3x3 filters: Gx (horizonal) and Gy (vertical). Edge strength ~ srqt(Gx^2 + Gy^2)

Highlights boundaries. Good QA check: Sobel should aling with anatomical edges

FPGA Analogy: classic 3x3 convolution with line buffers and adders.

## Otsu Threshold (auto binary mask)

Automatically picks a threshold T that best splits the histogram into two classes (foreground/background)

It searches for T that maximizes between class variance - best separability

No manual threshold tuning; robust for many frames of images

A binary mask (0 or 255) showing "bright-ish structures"

It's a globel per-frame threshold, not per-pixel

## 3x3 Morphology

Small shape operation on binary masks:

- Open = erode then dilate - removes tiny specks/noise.
- Close = dilate then erode - fills tiny holes/gaps.

Otsu can leave salt-and-pepper noise; morphology cleans it quickly

FPGA Analogy: Windowed min/max over a 3x3 neighborhood.

## Segmentation

A tiny U-Net takes the grascale image and predicts a label per pixel (class IDs)

Classical steps (Otsu, Sobel) are fast but limited. A learned model can separate tissues/regions

We colorize the predicted IDs and alpha-blend onto grayscale



