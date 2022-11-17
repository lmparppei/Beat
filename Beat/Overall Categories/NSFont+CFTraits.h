/**
 
 \category  NSFont(CFTraits)
 
 \brief     Adds a number of facilities to simplify working with fonts.
 
 \details   It's not always easy to get the bold or italic variant of a font
            if it even exists. This category adds properties to NSFont that
            indicate whether a font is bold, italic, condensed, monospaced
            and more. Other properties can tell you if a bold or italic variant
            exist. Finally, some methods return the bold or italic variations
            of the font.
 
 \author    Eric Methot
 \date      2012-04-10
 
 \copyright Copyleft 2012 Eric Methot.
 
 */

#import <Cocoa/Cocoa.h>

@interface NSFont (CFTraits)

/// Returns YES if this font exists in a bold variant and NO otherwise.
@property (readonly) BOOL fontInFamilyExistsInBold;

/// Returns YES if this font exists in an italic variant and NO otherwise.
@property (readonly) BOOL fontInFamilyExistsInItalic;

/// Returns YES if this font is bold.
@property (readonly) BOOL isBold;

/// Returns YES if this font is italic.
@property (readonly) BOOL isItalic;

/// Returns YES if this font is condensed.
@property (readonly) BOOL isCondensed;

/// Returns YES if this font is expanded.
@property (readonly) BOOL isExpanded;

/// Returns YES if this font is monospaced.
@property (readonly) BOOL isMonospaced;

/// Returns YES if this font is vertical.
//@property (readonly) BOOL isVertical;

/// Returns YES if this font is UI optimized.
@property (readonly) BOOL isUIOptimized;

/// Returns the font size for this font instance.
@property (readonly) float fontSize;

/// Returns the bold variation of the font or the font itself 
/// if such a variation does not exist.
@property (readonly) NSFont *fontVariationBold;

/// Returns the italic variation of the font or the font itself
/// if such a variation does not exist.
@property (readonly) NSFont *fontVariationItalic;

/// Returns the bold-italic variation of the font or the font itself
/// if such a variation does not exist.
@property (readonly) NSFont *fontVariationBoldItalic;

/// Returns the regular variation of the font or the font itself
/// if such a variation does not exist.
@property (readonly) NSFont *fontVariationRegular;

/// Returns the same font with new size.
- (NSFont*) fontVariationOfSize:(double)size;

/// Returns the value of the spc attribute in the fonts description.
@property (readonly) double spacing;

@end
