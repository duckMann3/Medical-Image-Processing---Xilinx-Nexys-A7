# U-Net Architecture for Image Segmentation

U-Net is a kind of neural network mainly used for image segmentation which means dividing an image into different parts to identify specific objects. The name "U-Net" comes from the shape of its architecture which looks like the letter "U" when drawn.

There are three key parts to the symmetric model:

1. Contracting Path (Encoder)
	- Uses small filters (3x3 pixels) to scan the image and find features.
	- Apply an activation function called ReLU to add non-linearity and help the model learn better.
	- Uses max pooling (2x2 filters) to shrink the image size while keeping important information
2. Bottleneck
	- The middle of the "U" where the most compressed and abstract information is stored.
	- It links the encoder and decoder.
3. Expansive Path (Decoder)
	- Uses up sampling to get back to the original image size.
	- Combines information from the encoder using "skip connections." These connections help the decoder get spatial details that might have been lost when shrinking the image.
	- Uses convolution layers again to clean up and refine the output.

## How U-Net Works

1. Input Image
2. Feature Extraction (Encoder)
3. Bottleneck Processing
4. Reconstruction and Localization (Decoder) 
5. Final Prediction: A 1x1 convolution at the end converts the refined feature maps into the final segmentation map where each pixel is classified into a specific class like foreground or background. The output has the same spatial resolution as the input image.

### Resources:
- https://www.geeksforgeeks.org/machine-learning/u-net-architecture-explained/