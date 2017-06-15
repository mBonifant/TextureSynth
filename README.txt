efrosLeung.m: an implementation of Efros & Leung's texture synthesis
algorithm as described in their paper: Texture Synthesis by Non-parametric Sampling

It takes 3 inputs, an image name (or matrix), a window size, and padding size.
It then generates a new texture from the input image, that is larger than the original by
the size of the padding in all directions, ex: an input image might be 3X4, with padding 
size 2 the output is expected to be 7X8. 

The window size determines how well the generated texture should reflect the original image,
smaller window sizes invite more randomness to the texture, while larger window sizes invite
more uniformity to the generated texture. (compare the sample outputs, floralbw.3.250, 
floralbw.9.250, and floralbw.15.250 all of which had 250 padding, but varried in their window 
size, with sizes 3, 9, and 15 respectively, note how as the window size increased, the generated
texture looked more like the original).

floralbw.png: a sample image used to test the texture synthesis algorithm

floralbw.3.250: Sample output, where the input was floralbw.png, 3, and 250
floralbw.9.250: Sample output, where the input was floralbw.png, 9, and 250
floralbw.15.250: Sample output, where the input was floralbw.png, 15, and 250

