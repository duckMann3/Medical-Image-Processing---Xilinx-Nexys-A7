
Contrast Limited Adaptive Histogram Equalization (CLAHE) is used to improve the contrast of images. In traditional methods, the whole image changes, but CLAHE works by dividing the image into smaller parts and adjusting the contrast separately. This helps in avoiding the image getting too bright or too dark in some areas.

When applying CLAHE there are two parameters to remember:

- **clipLimit**: This parameter sets the threshold for contrast limiting. By default the value is 40.
- **tileGridSize**: It is used to divide the image into gr4ids for applying CLAHE. It sets the number of rows and columns. By default this is 8x8.

Our clip limit should be around 2.0 to avoid noise over-amplification of our image. Also instead of all this, we want to return a 3x3 Gaussian filter to reduce the noise of the image. 

Example implementation:

```   
import cv2 
import numpy as np 
import os 
def display_image(title, image):     
	try:         
		from google.colab.patches import cv2_imshow          
		cv2_imshow(image)     
	except ImportError:         
		cv2.imshow(title, image)         
		cv2.waitKey(0)         
		cv2.destroyAllWindows() 
image_path = "image.jpg" 
image = cv2.imread(image_path) 
image_resized = cv2.resize(image, (500, 600)) 
image_bw = cv2.cvtColor(image_resized, cv2.COLOR_BGR2GRAY) 
clahe = cv2.createCLAHE(clipLimit=5) 
clahe_img = np.clip(clahe.apply(image_bw) + 30, 0, 255).astype(np.uint8) _, threshold_img = cv2.threshold(image_bw, 155, 255, cv2.THRESH_BINARY) display_image("Ordinary Threshold", threshold_img) 
display_image("CLAHE Image", clahe_img)
```

Resources:

- https://www.geeksforgeeks.org/python/clahe-histogram-eqalization-opencv/
- https://learnopencv.com/otsu-thresholding-with-opencv/