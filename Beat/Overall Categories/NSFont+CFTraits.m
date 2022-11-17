/**
 
 \category  NSFont(CFTraits)
 
 \author    Eric Methot
 \date      2012-04-10
 
 \copyright Copyleft 2012 Eric Methot.
 
 */

#import "NSFont+CFTraits.h"
#import <objc/runtime.h>

/// Some traits are cached globally by fontName.
static NSMutableDictionary *gNSFontCachedCustomTraits = nil;

/// Some traits are 
const uint64_t kNUFontTraitInFamilyExistsInBold   = 0x0000000100000000ULL;
const uint64_t kNUFontTraitInFamilyExistsInItalic = 0x0000000200000000ULL;

@implementation NSFont (CFTraits)


- (BOOL) checkForCachedFontTrait:(NSUInteger)trait
{
    // We use the cached traits if we have them.
    NSNumber *cachedTraits = [gNSFontCachedCustomTraits objectForKey:self.fontName];
    
    if (cachedTraits == nil) {
    
        // We use the traits in the fontDescriptor
        NSFontSymbolicTraits traits = self.fontDescriptor.symbolicTraits;
        
        // Then we look at the other members of that font family to see if there are any bold or italic variations.
        NSArray *members = [[NSFontManager sharedFontManager] availableMembersOfFontFamily:self.familyName];
        
        uint64_t customTraits = traits;
        
        for (NSArray *member in members) {
            
            int memberTrait = [[member objectAtIndex:3] intValue];
            
            if (memberTrait & NSBoldFontMask)
                customTraits |= kNUFontTraitInFamilyExistsInBold;
            
            if (memberTrait & NSItalicFontMask)
                customTraits |= kNUFontTraitInFamilyExistsInItalic;
        }

        cachedTraits = @(customTraits);
        
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            gNSFontCachedCustomTraits = [NSMutableDictionary dictionaryWithCapacity:512];
        });
        
        @synchronized(gNSFontCachedCustomTraits) {
            [gNSFontCachedCustomTraits setObject:cachedTraits forKey:self.fontName];
        }
    }
    
    uint64_t flag = cachedTraits.unsignedIntegerValue & trait;
    
    return (BOOL)(flag != 0);
}


- (BOOL) fontInFamilyExistsInBold
{
    return [self checkForCachedFontTrait:kNUFontTraitInFamilyExistsInBold];
}

- (BOOL) fontInFamilyExistsInItalic
{
    return [self checkForCachedFontTrait:kNUFontTraitInFamilyExistsInItalic];
}

- (BOOL) isBold
{
    return [self checkForCachedFontTrait:NSFontBoldTrait];
}

- (BOOL) isItalic
{
    return [self checkForCachedFontTrait:NSFontItalicTrait];
}

- (BOOL) isCondensed
{
    return [self checkForCachedFontTrait:NSFontCondensedTrait];
}

- (BOOL) isExpanded
{
    return [self checkForCachedFontTrait:NSFontExpandedTrait];
}

- (BOOL) isMonospaced
{
    return [self checkForCachedFontTrait:NSFontMonoSpaceTrait];
}

//- (BOOL) isVertical
//{
//    return [self checkForCachedFontTrait:NSFontVerticalTrait];
//}

- (BOOL) isUIOptimized
{
    return [self checkForCachedFontTrait:NSFontUIOptimizedTrait];
}

- (float) fontSize
{
    return [[self.fontDescriptor objectForKey:NSFontSizeAttribute] floatValue];
}

- (NSFont*) fontVariationWithTraits:(NSFontTraitMask)traitMask
{
    NSFontManager *fontManager = [NSFontManager sharedFontManager];
    return [fontManager convertFont:self toHaveTrait:traitMask];
}


- (NSFont*) fontVariationBold
{
    return [self fontVariationWithTraits:NSBoldFontMask];
}

- (NSFont*) fontVariationItalic
{
    return [self fontVariationWithTraits:NSItalicFontMask];
}

- (NSFont*) fontVariationBoldItalic
{
    return [self fontVariationWithTraits:NSBoldFontMask | NSItalicFontMask];
}

- (NSFont*) fontVariationRegular
{
    return [self fontVariationWithTraits:NSUnboldFontMask | NSUnitalicFontMask];
}

- (NSFont*) fontVariationOfSize:(double)size
{
    return [NSFont fontWithName:self.fontName size:size];
}

- (double) spacing
{
    NSString *descr = self.description;
    NSRange range = [descr rangeOfString:@"spc="];
    return [descr substringFromIndex:range.location + range.length].doubleValue;
}

@end
