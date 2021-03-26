# chocolate

The Cole Color Model, CHCLT, pronounced "Chocolate"


# Overview

CHCLT, Cole Hue Chroma Luma Transform, is a transform on an RGB color space that defines an invertible transfer function and luminance function.  The default color space is sRGB.

Color models like HSL and HSV are intuitive and simple, but are not designed around human perception.  Color models like Lch are designed around human perception of color and are relatively intuitive, but half the colors are outside the RGB gamut so the color model cannot replace HSL and HSB in many applications.  CHCLT bridges the gap, being designed around the human perception of luminance while staying in gamut and being intuitive.

Like HSL and Lch, CHCLT is a bicone or cylindrical color model, with grays along the center axis and hues around the circumference.  Like Lch, and unlike HSL, the colors on each plane of the bicone or cylinder have equal luminance.  Like HSL, and unlike Lch, the unit circle on each plane of the bicone maps 1:1 to the RGB cube.

Hue has the same broad meaning in all these cylindrical color models, relating to the ratio of color components.  HSL and HSB use a hexagonal model of hue that evenly distributes primary and secondary colors at regular intervals.  CHCLT and Lch use angles in a plane so the distance between primary and secondary colors is not regular.  Like HSL and HSV, red is always at the start of the CHCLT hue range.  Hue is cyclic.

Chroma in CHCLT is an indicator of the intensity of a color, or of the distance from gray.  Like saturation in HSL and HSV, chroma is a measure of how intense a color is relative to how intense it could at that plane in the cylinder.  Unlike Lch, chroma is not perceptually uniform in CHCLT.  Chroma is the ratio of a color to the most saturated color with equal luma hand hue.  Light yellows and dark blues with high chroma are very saturated, where dark yellows and light blues with high chroma are desaturated.

Luma in CHCLT is, like Lch, a measure of perceptual lightness.  The luma of a color is the gray level of that color when desaturated.  The lightness value in HCL is not perceptual, so colors with the same lightness can have drastically different luminance.  Luminance in Lch is numerically linear but less intuitive than luma.  Luma is more intuitive in the sense that a color with half the luma of another will apear about half as bright.

Luminance is a measure of perceptual lightness as a gamma expanded linear value in the underlying color space.  Addition should only be applied to linear values, so operations that modify hue, chroma, or luma all depend on luminance.

Contrast is an abstract measure of luminance that treats black and white as equal, with a medium value as the opposite of both black and white.  Contrast can be used to make colors more or less prominent in a consistent way for both light and dark colors.  It is designed to simplify accessibility in color choices and generate aesthetic foreground or background colors related to an arbitrary color.

Saturation in CHCLT is closer to the chroma in Lch than the saturation in HSL.  It is the length of the color vector after luminance is factored out.  Two colors with similar saturation will have perceptually similar color intensity.  Saturation is not normalized to have an upper bound the way chroma and other attributes are, and should only be used to compare colors.

# Range

Hue has a range of 0 ... 1 and is cyclic.  Red is at zero, green is near 1/3, blue is near 2/3, and red is at one.

Chroma has a range of 0 ... 1 with gray at zero and maximum colorfulness at one.  Denormalized colors can have a chroma outside this range.  Negative chroma can be applied and generates a complementary color.  Increasing chroma 1 (or below -1) will denormalize a color.

Luma has a range of 0 ... 1 with black at zero and white at one.  Denormalized colors can have a luma outside this range.  Values outside this range are truncated when assigning luma.

Contrast has a range of 0 ... 1 with medium luma at zero and black or white at one.  Negative contrast can be applied and generated a liminal color; dark from light or light from dark.

Luminance has a range of 0 ... 1 with black at zero and white at one.  Denormalized colors can have a luminance outside this range.  Values outside this range are truncated when assigning luminance.

Saturation is zero for gray and has an upper bound near one depending on hue and color space.  Negative saturation can be applied and generates a complementary color.  Increasing saturation can denormalize a color.

Denormalized colors are colors outside the unit RGB cube.  CHCLT can normalize a color by reducing the saturation.  When targeting an extended color space, denormalized colors might still be valid.

When adjusting RGB colors using CHCLT, luma is prioritized.  Adjusting hue will preserve luma and change chroma.  Adjusting hue will only change saturation if the color would be denormalized.  Adjusting chroma will preserve luma, and preserve hue if chroma is positive.  Hue is discard at chroma zero and shifted half a turn by negative chroma.  Adjusting luma will preserve hue unless hue is discarded at black or white.  Reducing luma will preserve saturation but may reduce chroma.  Increasing luma may increase chroma and reduce saturation.

# Convert from RGB to CHCLT

RGB = vector of color components (e.g. [0.2, 0.4, 0.6])
L = chclt.linear(RGB) (e.g. RGB²)
luminance = chclt.luminance(L) (e.g. L • [0.2126, 0.7152, 0.0722])
luma = chclt.transfer(luminance) (e.g. √luminance)
contrast = |luma * 2 - 1|
C = L - luminance
chroma = max(C / (1 - luminance), C / -luminance)
hue = acos(Ĉ • Ĥ) / 2π (e.g. Ĉ • [0.9, -0.3, -0.3])
saturation = |C|

These equations are oversimplified.  Refer to the code for complete explanations.

Hue, Chroma, Luma are the core components of CHCLT.  Contrast, Luminance, and Saturation are ancillary.

# Convert from CHCLT to RGB

Refer to the code for a complete explanation.  In summary, a reference vector is rotated around an axis to calculate hue, normalized, then the luma and chroma are applied.

CHCLT can adjust an RGB color without converting to and from CHCLT coordinates.  It can be used with the hexagonal hue of HSL or start with a system or design color.  It is more efficient to adjust luma, chroma, or contrast directly on an RGB color than to convert to HCL and back.
