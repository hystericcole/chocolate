# chocolate
CHCLT color model with example interface


# Overview

Chocolate, or CHCLT, is a color space with some of the intuitive properties and usability of HSL or HSV, mixed with some of the perceptual properties of HCL or LCH.  HSL and HSV provide a one to one mapping to the RGB space, but make no attempt at perceptual uniformity.  HCL or LCH provide perceptual uniformity, but half the color space is outside the representable RGB range so it is largely unusable.  Chocolate provides uniform luminance, but the chromaticity or saturation is stretched to also provide a full mapping to and from the RGB space.

The natural shape of the Chocolate color space is a bicone, similar to HSL, but each cross section of the bicone has uniform luminance.  One point of the bicone is white and the other is black, with medium colors through the center disc.

HSL and HSV use the mathematically simple hexagonal model of hue.  Chocolate uses a radial model, calculating the angle between a given color and pure red by taking the dot product.  Chocolate allows for negative saturation to generate an inverse color with the same luminance, and the radial model of hue is consistent with negative saturation.

To desaturate a color in a linear color space, calculate the gray with equal luminance to the color and interpolate towards that gray.  Interpolating away from that gray will increase saturation.  A color becomes over saturated when a component exceeds the RGB range.  The chromaticity component in CHCLT colors is a ratio between a color and the maximum amount it could be saturated.  That ratio is not perceptually uniform, making some colors appear more vibrant than others with equal luminance.  The effect is subtle and the benefit is a more usable color space.

The luminance is calculated the same was as other color spaces like BT.709, using an inverse transfer function to convert to a linear RGB space then taking the dot product of the linear RGB color with luminance coefficients.  Any transfer function and luminance coefficients could be used, and a simplified BT.709 is the default.

Chocolate introduces a new measure of the contrast of a color.  Contrast measures the distance from medium, so both black and white have a contrast of one, and any medium color has a contrast of zero.  Use contrast to generate contrasting colors that are both legible and aesthetic.

Chocolate is focused on relative colors and preserving luminance.  It is easier to apply a new luma, chroma, or contrast to a color than it is to generate a new color from hue.  Changing the hue or chroma of a color will preserve the luma, but changing the luma may also change the hue and chroma.
