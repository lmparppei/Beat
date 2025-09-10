//
//  BeatLayoutManager.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 11.2.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//
/**
 
 TextKit 1 layout manager for both macOS and iOS.
 Handles drawing scene numbers, revisions and reviews, as well as transforming text to uppercase and hiding Fountain markup.
 
 Because iOS and macOS APIs are *almost* similar but still incompatible, there are tons of target conditionals ahead.
 
 */

#import "BeatLayoutManager.h"
#import <BeatCore/BeatCore.h>
#import <BeatThemes/BeatThemes.h>
#import <BeatCore/BeatCore-Swift.h>
#import <BeatCore/BeatMeasure.h>
#import <BeatDynamicColor/BeatDynamicColor.h>
//#import <BeatPagination2/BeatPagination2.h>
#import <CoreText/CoreText.h>


#import "BeatRevisions.h"

@interface BeatLayoutManager()
@property (nonatomic) NSMutableParagraphStyle* _Nullable markerStyle;
@property (nonatomic) NSMutableParagraphStyle* _Nullable sceneNumberStyle;
@property (nonatomic, weak) BXTextView* textView;

@end

#if TARGET_OS_OSX
    #define X_OFFSET 50.0
#else
    #define X_OFFSET 25.0
#endif

#if TARGET_OS_IOS
    #define BXPoint CGPoint
    #define BXRectFill UIRectFill
    #define BXBezierPath UIBezierPath

    // Because of different line heights on iOS, we'll need to add an offset
    #define Y_OFFSET -1.0

    #define rectNumberValue(s) [NSValue valueWithCGRect:rect]
    #define getRectValue CGRectValue
#else
    #define BXPoint NSPoint
    #define BXRectFill NSRectFill
    #define BXBezierPath NSBezierPath

    #define Y_OFFSET 0.0

    #define rectNumberValue(s) [NSValue valueWithRect:rect]
    #define getRectValue rectValue
#endif


@implementation BeatLayoutManager

@dynamic delegate;

- (instancetype)initWithDelegate:(id<BeatEditorDelegate>)editorDelegate
{
	self = [super init];
	if (self) {
		_editorDelegate = editorDelegate;
        self.delegate = self;
	}
	return self;
}

- (void)dealloc
{
    [self.pageBreaksMap removeAllObjects];
    self.pageBreaksMap = nil;
    
    self.delegate = nil;
    self.editorDelegate = nil;
}


#pragma mark - Draw glyphs

- (void)drawGlyphsForGlyphRange:(NSRange)glyphsToShow atPoint:(BXPoint)origin
{
	[super drawGlyphsForGlyphRange:glyphsToShow atPoint:origin];
        
    CGSize inset = self.inset;
	NSRange charRange = [self characterRangeForGlyphRange:glyphsToShow actualGlyphRange:nil];
    
    BeatLineTypeSet* lineTypes = [BeatLineTypeSet.alloc initWithTypes:@[@(heading), @(section), @(pageBreak)]];
    
    // Enumerate lines in drawn range
    [self.textStorage enumerateAttribute:@"representedLine" inRange:charRange options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
        Line* line = (Line*)value;
        if (line == nil) return;
        
        // Do nothing if this line is not a marker or a heading
        if (line.versions.count == 0 && line.markerRange.length == 0 && line.beats.count == 0 && ![lineTypes contains:line.type]) return;
        
        // Get range for the first character. For headings and markers we won't need anything else.
        NSRange r = NSMakeRange(line.position, 1);
        if (self.editorDelegate.hideFountainMarkup) {
            // If the editor hides Fountain markup, there's a chance that the first glyph or the whole line is hidden (if using a formatting character, ie. ".INT. SOMETHING"
            if (line.length > 1) r.location += 1;
            else r = line.range;
        }
        
        NSRange lineRange = [self glyphRangeForCharacterRange:r actualCharacterRange:nil];
        CGRect boundingRect = [self boundingRectForGlyphRange:lineRange inTextContainer:self.textContainers.firstObject];

        // Actual rect position
        CGRect rect = CGRectMake(inset.width + boundingRect.origin.x, inset.height + boundingRect.origin.y, boundingRect.size.width, boundingRect.size.height);

        // Don't go past this point if the text is folded
        NSNumber* folded = [self.textStorage attribute:@"BeatFolded" atIndex:range.location effectiveRange:nil];
        if (folded) return;
        
        // Draw scene numbers
        if (line.type == heading) {
            [self drawSceneNumberForLine:line rect:rect inset:inset];
        }
        else if (line.type == section && line.isBoneyardSection) {
            [self drawBoneyardMarkerForLine:line];
        }
        else if (line.type == pageBreak) {
            [self drawForcedPageBreakForLine:line];
        }
#if TARGET_OS_OSX
        else if (line.type == section) {
            //[self drawSectionDividerForLine:line rect:rect inset:inset];
        }
#endif
        
        // Draw markers
        if (line.markerRange.length > 0) {
            [self drawMarkerForLine:line rect:rect inset:inset];
        }
                
        if (line.beats.count > 0) {
            [self drawBeat:rect inset:inset];
        }
        
        if (line.versions.count > 0) {
            [self drawVersion:rect line:line inset:inset];
        }
    }];
}

- (CGRect)boundingRectForLine:(Line*)line
{
    CGRect rect = [self boundingRectForGlyphRange:[self glyphRangeForCharacterRange:line.textRange actualCharacterRange:nil] inTextContainer:self.textContainers.firstObject];
    rect.origin.y += self.inset.height;
    return rect;
}


#pragma mark - Forced page break marker

- (void)drawForcedPageBreakForLine:(Line*)line
{
    CGRect rect = [self boundingRectForLine:line];
    CGSize inset = self.inset;
    
    CGFloat y = rect.origin.y + rect.size.height / 2;
    CGRect leftRect = CGRectMake(0.0, y, rect.origin.x + inset.width - 5.0, 1.0);
    
    CGRect rightRect = CGRectMake(CGRectGetMaxX(rect) + inset.width + 5.0, y , self.textContainers.firstObject.size.width - CGRectGetMaxX(rect), 1.0);
    
    BXColor* pageBreakColor = [ThemeManager.sharedManager.invisibleTextColor colorWithAlphaComponent:0.3];
    [pageBreakColor setFill];
    
    BXRectFill(leftRect);
    BXRectFill(rightRect);
}


#pragma mark - Boneyard act marker

- (void)drawBoneyardMarkerForLine:(Line*)line
{
    CGRect rect = [self boundingRectForLine:line];
    CGSize inset = self.inset;
    
    CGFloat y = rect.origin.y + rect.size.height / 2;
    
    CGRect leftRect = CGRectMake(0.0, y, rect.origin.x + inset.width - 5.0, 1.0);
    CGRect rightRect = CGRectMake(CGRectGetMaxX(rect) + inset.width + 5.0, y , self.textContainers.firstObject.size.width - CGRectGetMaxX(rect), 1.0);
    
    
    BXColor* pageBreakColor = [ThemeManager.sharedManager.invisibleTextColor colorWithAlphaComponent:0.3];
    [pageBreakColor setFill];
    
    BXRectFill(leftRect);
    BXRectFill(rightRect);
}


#pragma mark - Draw page separators and numbers

- (void)drawPageSeparators:(const NSRange*)glyphsToShow
{
    // Page number drawing is off
    if (!self.editorDelegate.showPageNumbers) return;
#if TARGET_OS_IOS
    // Page number doesn't fit on phones
    if (is_Mobile) return;
#endif

    static BXColor* pageBreakColor;
    if (pageBreakColor == nil) pageBreakColor = [ThemeManager.sharedManager.invisibleTextColor colorWithAlphaComponent:0.3];
    
    BXColor* pageNumberColor = ThemeManager.sharedManager.pageNumberColor;
    
    NSRange charRange = [self characterRangeForGlyphRange:*glyphsToShow actualGlyphRange:nil];
    CGSize inset = self.inset;
    
    // Why are we using a key enumerator here instead of a normal fast enumeration? I do not know.
    Line* line;
    
    NSEnumerator* enumerator = _pageBreaksMap.keyEnumerator;
    while ((line = enumerator.nextObject)) {
        if (NSIntersectionRange(line.range, charRange).length == 0) continue;
        
        // The dictionary value is always a two-item array with [pageNumber<String>, pageBreakPosition<Float>]
        NSArray* values = [_pageBreaksMap objectForKey:line];
        
        // Page number
        NSString* pageNumber = values[0];
        
        // Get the glyph position
        NSUInteger localIndex = ((NSNumber*)values[1]).unsignedIntegerValue;
        NSInteger globalIndex = line.position + localIndex;
        NSInteger glyphIndex = [self glyphIndexForCharacterAtIndex:globalIndex];
        
        // Get rect and local range
        NSRange lRange;

        CGRect r = [self lineFragmentRectForGlyphAtIndex:glyphIndex effectiveRange:&lRange];
        
        // Draw page numbers
        if (pageNumber > 0) {
            [pageNumber drawInRect:CGRectMake(CGRectGetMaxX(r) + inset.width - 60.0, inset.height + r.origin.y, 30.0, (CGFloat)self.editorDelegate.editorLineHeight) withAttributes:@{
                NSFontAttributeName: self.editorDelegate.fonts.regular,
                NSForegroundColorAttributeName: pageNumberColor,
                NSParagraphStyleAttributeName: self.pageNumberStyle
            }];
        }
        
        // Draw page separators if needed
        if ([BeatUserDefaults.sharedDefaults getBool:BeatSettingShowPageSeparators]) {
            NSRange cRange = [self characterRangeForGlyphRange:lRange actualGlyphRange:nil];
            
            if (globalIndex != cRange.location && globalIndex != NSMaxRange(cRange)) {
                // Page break happens mid-element. Let's draw a bezier curve here.
                [self drawMidElementPageSeparatorAtIndex:glyphIndex rect:r inset:inset color:pageBreakColor];
            } else {
                // Draw normal page separator
                CGRect separatorRect = CGRectMake(inset.width + r.origin.x, inset.height + r.origin.y, r.size.width, 1.0);
                [pageBreakColor setFill];
                BXRectFill(separatorRect);
            }
        }
    }
}

- (void)drawMidElementPageSeparatorAtIndex:(NSInteger)glyphIndex rect:(CGRect)rect inset:(CGSize)inset color:(BXColor*)pageBreakColor
{
    CGRect actualRect = [self boundingRectForGlyphRange:NSMakeRange(glyphIndex,1) inTextContainer:self.textContainers.firstObject];
    
    BXBezierPath* lbPath = BXBezierPath.new;
    
    CGFloat baseline = rect.origin.y + inset.height + actualRect.size.height;
    
    [lbPath moveToPoint:CGPointMake(0, baseline)];
    [lbPath addLineToPoint:CGPointMake(inset.width + actualRect.origin.x, baseline)];
    [lbPath addLineToPoint:CGPointMake(inset.width + actualRect.origin.x, rect.origin.y + inset.height)];
    [lbPath addLineToPoint:CGPointMake(CGRectGetMaxX(rect) + inset.width * 2, rect.origin.y + inset.height)];
    
    [pageBreakColor setStroke];
    [lbPath stroke];
}

- (NSMutableParagraphStyle*)pageNumberStyle
{
    static NSMutableParagraphStyle* pageNumberStyle;
    if (pageNumberStyle == nil) {
        pageNumberStyle = NSMutableParagraphStyle.new;
        pageNumberStyle.alignment = NSTextAlignmentRight;
        pageNumberStyle.minimumLineHeight = self.editorDelegate.editorLineHeight;
    }
    
    return pageNumberStyle;
}


#pragma mark - Draw text background

-(void)drawBackgroundForGlyphRange:(NSRange)glyphsToShow atPoint:(BXPoint)origin
{
    // Store revision names and create an array for background colors
    //static NSDictionary<NSString*, NSNumber*>* revisionLevels;
    static NSMutableDictionary<NSString*,BXColor*>* bgColors;

    if (_textView == nil) _textView = _editorDelegate.getTextView;
    
    if (bgColors == nil) {
        NSArray* revisionGenerations = BeatRevisions.revisionGenerations;
        bgColors = [NSMutableDictionary dictionaryWithCapacity:revisionGenerations.count];
    }
        
    CGSize inset = self.inset;
    CGFloat documentWidth = _editorDelegate.documentWidth;
    
    bool showTags = _editorDelegate.showTags;
    bool showRevisions = _editorDelegate.showRevisions;
    
    // Draw page separators
    [self drawPageSeparators:&glyphsToShow];
        
    // We'll enumerate line fragments to then be able to draw range-based backgrounds on each line.
    // This is somewhat unefficient if there's a lot of attributes, so you should keep track of those.
    [self enumerateLineFragmentsForGlyphRange:glyphsToShow
                                   usingBlock:^(CGRect rect,
                                                CGRect usedRect,
                                                NSTextContainer * _Nonnull textContainer, NSRange glyphRange, BOOL * _Nonnull stop) {
        // Calculate character range here already. We also get usedRect for free.
        NSRange charRange = [self characterRangeForGlyphRange:glyphRange actualGlyphRange:NULL];
        __block NSInteger revisionLevel = -1;
        
        [self.textStorage enumerateAttributesInRange:charRange options:0 usingBlock:^(NSDictionary<NSAttributedStringKey,id> * _Nonnull attrs, NSRange range, BOOL * _Nonnull stop) {
            
            BeatRevisionItem* revision = attrs[BeatRevisions.attributeKey];
            BeatTag* tag = attrs[BeatTagging.attributeKey];
            BeatReviewItem *review = attrs[BeatReview.attributeKey];
                        
            if (range.location < 0 || NSMaxRange(range) <= 0) return;
            
            // Remove line breaks from the range (begin enumeration from the end to catch them as soon as possible)
            NSRange rRange = range;
            for (NSInteger i = NSMaxRange(rRange) - 1; i >= rRange.location; i--) {
                if (i < 0) break;
                if (self.textStorage.string.length > i && [self.textStorage.string characterAtIndex:i] == '\n') {
                    rRange.length = rRange.length - 1;
                    break;
                }
            }
            
            NSRange usedRange = [self glyphRangeForCharacterRange:rRange actualCharacterRange:nil];
            CGRect aRect = [self boundingRectForGlyphRange:usedRange inTextContainer:self.textContainers.firstObject];
            aRect.origin.x += inset.width;
            aRect.origin.y += inset.height;
            /*
            if (attrs[@"BeatFolded"]) {
                CGRect openDisclosure = CGRectMake(aRect.origin.x - 40.0, aRect.origin.y, 30.0, aRect.size.height);
                [BXColor.redColor setFill];
                BXRectFill(openDisclosure);
                
                return;
            }
            */
             
            if (review != nil && !review.emptyReview) {
                if (bgColors[@"review"] == nil) {
                    BXColor *reviewColor = BeatReview.reviewColor;
                    bgColors[@"review"] = [reviewColor colorWithAlphaComponent:.4];
                    bgColors[@"reviewUnderline"] = [reviewColor colorWithAlphaComponent:.6];
                }
                BXColor *color = bgColors[@"review"];
                BXColor *underlineColor = bgColors[@"reviewUnderline"];
                [color setFill];

                NSRange fullGlyphRange = [self glyphRangeForCharacterRange:rRange actualCharacterRange:nil];
                CGRect fullRect = [self boundingRectForGlyphRange:fullGlyphRange inTextContainer:self.textContainers.firstObject];
                bool fullLine = (fullGlyphRange.length == glyphRange.length - 1);
                
                fullRect.origin.x += inset.width;
                fullRect.origin.y += inset.height;
                
                if (fullLine) {
                    CGFloat padding = self.textView.textContainer.lineFragmentPadding;
                    fullRect.origin.x = inset.width + padding;
                    fullRect.size.width = self.textView.textContainer.size.width - padding * 2;
                }
                BXRectFill(fullRect);
                
                [underlineColor setFill];
                CGRect underline = CGRectMake(fullRect.origin.x, fullRect.origin.y + fullRect.size.height - 2, fullRect.size.width, 2);
                BXRectFill(underline);
            }
            
            if (tag != nil && showTags) {
                // Store tag color
                if (bgColors[tag.typeAsString] == nil) {
                    bgColors[tag.typeAsString] = [[BeatTagging colorFor:tag.type] colorWithAlphaComponent:0.4];
                }

                BXColor *tagColor = bgColors[tag.typeAsString];
                [tagColor setFill];
                
                CGRect tagRect = aRect;
                tagRect.origin.x -= 2.0; tagRect.size.width += 2.0;
#if TARGET_OS_OSX
                BXBezierPath* path = [BXBezierPath bezierPathWithRoundedRect:tagRect xRadius:3.0 yRadius:3.0];
#else
                BXBezierPath* path = [BXBezierPath bezierPathWithRoundedRect:tagRect cornerRadius:3.0];
#endif
                [path fill];
                
                //BXRectFill(aRect);
            }
            
            // Make note if this line has a revision which is higher than current level
            if ((revision.type == RevisionAddition || revision.type == RevisionCharacterRemoved) && (revision.generationLevel > revisionLevel)) {
                revisionLevel = revision.generationLevel;
            }
            
            // Draw revision backgrounds last, so the underlines go on top of other stuff.
            if (revision.type == RevisionAddition && showRevisions && rRange.length > 0) {
                CGRect revisionRect = aRect;
                
                BeatRevisionGeneration* generation = BeatRevisions.revisionGenerations[revision.generationLevel];
                NSString* generationKey = [NSString stringWithFormat:@"revision-%lu",revision.generationLevel];
                
                if (bgColors[generationKey] == nil) {
                    bgColors[generationKey] = [[BeatColors color:generation.color] colorWithAlphaComponent:.3];
                }
                BXColor* color = bgColors[generationKey];
                [color setFill];
                
                revisionRect.origin.y += revisionRect.size.height - 1.0;
                revisionRect.size.height = 2.0;
                
                BXRectFill(revisionRect);
            }
        }];
        
        // If we found a revision, let's draw a marker for it
        if (revisionLevel >= 0) {
            CGFloat deviceOffset = 0.0;
            
#if TARGET_OS_IOS
            // Phones have a different offset
            if (is_Mobile) deviceOffset = 35.0;
#endif
            
            // Calculate rect for the marker position
            CGRect rect = CGRectMake(inset.width + documentWidth - 30 - X_OFFSET + deviceOffset,
                                     inset.height + usedRect.origin.y - Y_OFFSET,
                                     22,
                                     usedRect.size.height + 1.0);
            
            NSAttributedString* symbol = [self markerFor:BeatRevisions.revisionGenerations[revisionLevel]];
            
            [symbol drawInRect:rect];
        }
    }];
    
    [super drawBackgroundForGlyphRange:glyphsToShow atPoint:origin];
}

-(NSArray*)rectsForGlyphRange:(NSRange)glyphsToShow
{
    NSMutableArray *rects = [NSMutableArray.alloc initWithCapacity:10];
    NSTextContainer *tc = self.textContainers.firstObject;
    
    [self enumerateLineFragmentsForGlyphRange:glyphsToShow usingBlock:^(CGRect rect, CGRect usedRect, NSTextContainer * _Nonnull textContainer, NSRange glyphRange, BOOL * _Nonnull stop) {
        CGRect lfRect = [self boundingRectForGlyphRange:NSIntersectionRange(glyphsToShow, glyphRange) inTextContainer:tc];
        [rects addObject:@(lfRect)];
    }];
    
    return rects;
}


#pragma mark - Draw scene numbers

/// Draws the scene number for given line in a pre-defined rect
- (void)drawSceneNumberForLine:(Line*)line rect:(CGRect)rect inset:(CGSize)inset
{
    CGFloat yOffset = 0.0;
    #if TARGET_OS_IOS
        yOffset = 1.0;
    #endif
        
    // Scene number drawing is off, return
    if (!self.editorDelegate.showSceneNumberLabels || !self.editorDelegate.editorStyles.heading.sceneNumber) return;
    // Don't draw scene numbers when the container is too small. This mostly affects iPhones.
    else if (inset.width + X_OFFSET + line.sceneNumber.length * 7.5 > inset.width + self.textContainers.firstObject.lineFragmentPadding) return;
    
    // Create the style if needed
    if (_sceneNumberStyle == nil) {
        _sceneNumberStyle = NSMutableParagraphStyle.new;
        _sceneNumberStyle.minimumLineHeight = self.editorDelegate.editorLineHeight;
    }
    
    // Create rect for the marker position
    rect.size.width = 7.5 * line.sceneNumber.length;
    rect.size.height = rect.size.height + 1.0;
    
    CGFloat y = rect.origin.y - Y_OFFSET - yOffset;
    
    rect = CGRectMake(inset.width + X_OFFSET,
                      y,
                      7.5 * line.sceneNumber.length,
                      rect.size.height + 1.0);
        
    BXColor* color;
    if (line.color.length > 0) color = [BeatColors color:line.color];
    if (color == nil) color = ThemeManager.sharedManager.textColor.effectiveColor;
    
    NSString *sceneNumber = line.sceneNumber;

    [sceneNumber drawAtPoint:rect.origin withAttributes:@{
        NSFontAttributeName: self.editorDelegate.fonts.regular,
        NSForegroundColorAttributeName: color,
        NSParagraphStyleAttributeName: self.sceneNumberStyle
    }];
}


/**
 This is an alternative style for drawing scene numbers. It uses glyph ranges instead of `Line` objects. It requires recalculating the rect.
 */
- (void)drawSceneNumberForGlyphRange:(NSRange)glyphRange charRange:(NSRange)charRange
{
    BXTextView* textView = self.editorDelegate.getTextView;
    
    // iOS and macOS have different types of edge insets
#if TARGET_OS_IOS
    CGSize inset = CGSizeMake(textView.textContainerInset.left, textView.textContainerInset.top);
    inset.height += 0.0; // This is here to make up for weird iOS line sizing
#else
    CGSize inset = textView.textContainerInset;
#endif
    
	// Scene number drawing is off, return
	if (!self.editorDelegate.showSceneNumberLabels) return;
	
	// Create the style if needed
	if (_sceneNumberStyle == nil) {
		_sceneNumberStyle = NSMutableParagraphStyle.new;
		_sceneNumberStyle.minimumLineHeight = self.editorDelegate.editorLineHeight;
	}
		
	[self.textStorage enumerateAttribute:@"representedLine" inRange:charRange options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
		Line* line = (Line*)value;
		if (line == nil || line.type != heading) return;
		
		NSRange headingRange = NSMakeRange(line.position, 1);
		if (self.editorDelegate.hideFountainMarkup) {
			if (line.length > 1) headingRange.location += 1;
			else headingRange = line.range;
		}
		
		NSRange lineRange = [self glyphRangeForCharacterRange:headingRange actualCharacterRange:nil];
		CGRect boundingRect = [self boundingRectForGlyphRange:lineRange inTextContainer:self.textContainers.firstObject];
		
		// Calculate rect for the marker position
		CGRect rect = CGRectMake(inset.width,
								 inset.height + boundingRect.origin.y,
								 7.5 * line.sceneNumber.length,
								 boundingRect.size.height + 1.0);
		
		BXColor* color;
		if (line.color.length > 0) color = [BeatColors color:line.color];
		if (color == nil) color = ThemeManager.sharedManager.textColor.effectiveColor;
		
		NSString *sceneNumber = line.sceneNumber;
		[sceneNumber drawAtPoint:rect.origin withAttributes:@{
			NSFontAttributeName: self.editorDelegate.fonts.regular,
			NSForegroundColorAttributeName: color,
			NSParagraphStyleAttributeName: self.sceneNumberStyle
		}];
	}];
}


#pragma mark - Draw section divider

- (void)drawSectionDividerForLine:(Line*)line rect:(CGRect)rect inset:(CGSize)inset
{
    /*
    NSParagraphStyle* pStyle = [self.textStorage attribute:NSParagraphStyleAttributeName atIndex:line.position effectiveRange:nil];
            
    // Create rect for the marker position
    CGFloat lineHeight = pStyle.minimumLineHeight;
    CGFloat w = 12.0;

    CGRect circleRect = CGRectMake(inset.width + X_OFFSET,
                                   rect.origin.y + w - lineHeight / 2,
                                   w,
                                   w);
    CGPoint textPosition = CGPointMake(circleRect.origin.x + 2.5, circleRect.origin.y - 1.0);
    
    BXColor* color = ThemeManager.sharedManager.sectionTextColor;
    if (line.sectionDepth > 1) color = [color colorWithAlphaComponent:1.0 - line.sectionDepth * 0.1];
    [color setFill];
    
    BXBezierPath* path = BXBezierPath.new;
    [path appendBezierPathWithRoundedRect:circleRect xRadius:circleRect.size.width / 2 yRadius:circleRect.size.width / 2];
    [path fill];
    
    BXColor* textColor = ThemeManager.sharedManager.backgroundColor;
    NSString* string = @"#";
    [string drawAtPoint:textPosition withAttributes:@{
        NSFontAttributeName: [BXFont systemFontOfSize:11.0],
        NSForegroundColorAttributeName: textColor
    }];
     */
}


#pragma mark - Draw markers

- (void)drawMarkerForLine:(Line*)line rect:(CGRect)rect inset:(CGSize)inset {
    
    CGRect r = CGRectMake(inset.width + X_OFFSET, rect.origin.y, 12, rect.size.height);
    
    BXColor* color;
    if (line.marker.length > 0) color = [BeatColors color:line.marker];
    if (color == nil) color = BeatColors.colors[@"orange"];
    [color setFill];
    
    BXBezierPath* path = [self markerPath:r inset:inset];
    if (path != nil) [path fill];
}

- (BXBezierPath*)markerPath:(CGRect)rect inset:(CGSize)inset {
    CGFloat left = rect.origin.x;
    CGFloat right = 40.0 + rect.origin.x;
    CGFloat y = rect.origin.y + 2.0;
    CGFloat h = rect.size.height - 2.0;
    
    BXBezierPath *path = BXBezierPath.bezierPath;
    [path moveToPoint:CGPointMake(right, y)];
    
#if TARGET_OS_IOS
    [path addLineToPoint:CGPointMake(left, y)];
    [path addLineToPoint:CGPointMake(left + 10.0, y + h / 2)];
    [path addLineToPoint:CGPointMake(left, y + h)];
    [path addLineToPoint:CGPointMake(right, y + h)];
#else
    [path lineToPoint:NSMakePoint(left, y)];
    [path lineToPoint:NSMakePoint(left + 10.0, y + h / 2)];
    [path lineToPoint:NSMakePoint(left, y + h)];
    [path lineToPoint:NSMakePoint(right, y + h)];
#endif
    
    CGFloat width = path.bounds.size.width;
    if (width > self.textContainers.firstObject.lineFragmentPadding + inset.width) {
        // Marker is too wide
        return nil;
    }
    
    [path closePath];
    return path;
}

-(NSAttributedString*)markerFor:(BeatRevisionGeneration*)generation {
    if (generation == nil) return NSAttributedString.new;
    
    static BXColor* markerColor;
    static NSCache* markers;
    
    NSString* revisionKey = [NSString stringWithFormat:@"%lu", generation.level];
    
    if (markers == nil) markers = NSCache.new;
    
    // This is a clumsy, cross-platform way to check if appearance has changed.
    if (markerColor != ThemeManager.sharedManager.textColor.effectiveColor || markerColor == nil) {
        // Reset cache and set a new marker color
        markers = NSCache.new;
        markerColor = ThemeManager.sharedManager.textColor.effectiveColor;
    }
    
    if (_markerStyle == nil) {
        _markerStyle = NSMutableParagraphStyle.new;
        _markerStyle.minimumLineHeight = self.editorDelegate.editorLineHeight;
    }
    
    NSAttributedString* marker = [markers objectForKey:revisionKey];
    if (marker == nil) {
        // Draw string
        NSString* symbol = generation.marker;
        marker = [NSAttributedString.alloc initWithString:symbol attributes:@{
            NSFontAttributeName: self.editorDelegate.fonts.regular,
            NSForegroundColorAttributeName: markerColor,
            NSParagraphStyleAttributeName: _markerStyle
        }];
        
        [markers setObject:marker forKey:revisionKey];
    }
    
    return marker;
}

#pragma mark - Draw story beats

- (void)drawBeat:(CGRect)rect inset:(CGSize)inset {
    BXBezierPath* path = BXBezierPath.bezierPath;
    
    CGFloat m = 16.0;
    CGFloat x = (inset.width + _editorDelegate.documentWidth) - 45.0;

    CGFloat y = rect.origin.y + 2.0;
    CGFloat h = rect.size.height - 2.0;

    [path moveToPoint:CGPointMake(x, y + h / 2)];
#if TARGET_OS_IOS
    [path addLineToPoint:CGPointMake(x + m * .25, y + h / 2)];
    [path addLineToPoint:CGPointMake(x + m * .45, y + 1.0)];
    [path addLineToPoint:CGPointMake(x + m * .55, y + h - 1.0)];
    [path addLineToPoint:CGPointMake(x + m * .75, y + h / 2)];
    [path addLineToPoint:CGPointMake(x + m * 1.0, y + h / 2)];
    
    path.lineJoinStyle = kCGLineJoinRound;
    path.lineCapStyle = kCGLineCapRound;
#else
    [path lineToPoint:CGPointMake(x + m * .25, y + h / 2)];
    [path lineToPoint:CGPointMake(x + m * .45, y + 1.0)];
    [path lineToPoint:CGPointMake(x + m * .55, y + h - 1.0)];
    [path lineToPoint:CGPointMake(x + m * .75, y + h / 2)];
    [path lineToPoint:CGPointMake(x + m * 1.0, y + h / 2)];
    
    path.lineJoinStyle = NSLineJoinStyleRound;
    path.lineCapStyle = NSLineCapStyleRound;
#endif

    path.lineWidth = 2.0;
    
    [BeatColors.colors[@"cyan"] setStroke];
    [path stroke];
}

#pragma mark Draw version counter

- (void)drawVersion:(CGRect)rect line:(Line*)line inset:(CGSize)inset
{
    CGFloat x = _editorDelegate.documentWidth - (inset.width / 2);
    CGFloat y = rect.origin.y;
    
    NSString* str = [NSString stringWithFormat:@"%lu/%lu", line.currentVersion+1, line.versions.count];
    [str drawAtPoint:CGPointMake(x, y) withAttributes:@{
        NSFontAttributeName: [BXFont systemFontOfSize:8.0],
        NSForegroundColorAttributeName: ThemeManager.sharedManager.invisibleTextColor
    }];
}


#pragma mark - Crossplatform helpers

-(void)saveGraphicsState
{
#if !TARGET_OS_IOS
    [NSGraphicsContext saveGraphicsState];
#endif
}
-(void)restoreGraphicsState
{
#if !TARGET_OS_IOS
    [NSGraphicsContext restoreGraphicsState];
#endif
}
-(CGSize)inset
{
#if TARGET_OS_IOS
    CGSize offset = CGSizeMake(_editorDelegate.getTextView.textContainerInset.left, _editorDelegate.getTextView.textContainerInset.top);
#else
    CGSize offset = _editorDelegate.getTextView.textContainerInset;
#endif
    return offset;
}


#pragma mark - Layout manager delegate

/// Temporary attributes. We'll use every single one of them.
-(NSDictionary<NSAttributedStringKey,id> *)layoutManager:(NSLayoutManager *)layoutManager shouldUseTemporaryAttributes:(NSDictionary<NSAttributedStringKey,id> *)attrs forDrawingToScreen:(BOOL)toScreen atCharacterIndex:(NSUInteger)charIndex effectiveRange:(NSRangePointer)effectiveCharRange
{
    return attrs;
}

- (NSUInteger)foldSelectionIfNeeded:(BXFont * _Nonnull)aFont charIndexes:(const NSUInteger * _Nonnull)charIndexes glyphRange:(const NSRange *)glyphRange props:(const NSGlyphProperty * _Nonnull)props {
    NSDictionary* attrs = [self.textStorage attributesAtIndex:charIndexes[0] effectiveRange:nil];
    if (attrs[@"BeatFolded"]) {
        NSUInteger location = charIndexes[0];
        NSUInteger length = glyphRange->length;
        
        NSGlyphProperty *modifiedProps = (NSGlyphProperty *)malloc(sizeof(NSGlyphProperty) * glyphRange->length);
        CFStringRef str = (__bridge CFStringRef)[self.textStorage.string substringWithRange:(NSRange){ location, length }];
        
        // Folded text
        for (NSInteger i = 0; i < glyphRange->length; i++) {
            NSGlyphProperty prop = props[i];
            prop |= NSGlyphPropertyControlCharacter;
            modifiedProps[i] = prop;
        }
        
        // Create the new glyphs
        CGGlyph *newGlyphs = GetGlyphsForCharacters((__bridge CTFontRef)(aFont), str);
        [self setGlyphs:newGlyphs properties:modifiedProps characterIndexes:charIndexes font:aFont forGlyphRange:*glyphRange];
        
        free(newGlyphs);
        free(modifiedProps);
        //CFRelease(str);
        
        return glyphRange->length;
    }
    
    return NSNotFound;
}

/// Generate customized glyphs, includes all-caps lines for scene headings and hiding markup.
-(NSUInteger)layoutManager:(NSLayoutManager *)layoutManager shouldGenerateGlyphs:(const CGGlyph *)glyphs properties:(const NSGlyphProperty *)props characterIndexes:(const NSUInteger *)charIndexes font:(BXFont *)aFont forGlyphRange:(NSRange)glyphRange
{
    // SOME WEIRD GUARDRAILS
    NSArray<Line*>* lines = [self.editorDelegate.parser linesInRange:glyphRange];
    Line* line = lines.firstObject;
    if (lines.count > 1 || line == nil) {
        // We won't lay out more than one line with this code, because... yes, I'm very bad with core stuff.
        return 0;
    }
    
    RenderStyle* style = [_editorDelegate.editorStyles forLine:line];
    
    // Check for folded/collapsed sections
    NSInteger foldedCharacters = [self foldSelectionIfNeeded:aFont charIndexes:charIndexes glyphRange:&glyphRange props:props];
    if (foldedCharacters != NSNotFound) return foldedCharacters;
    
    LineType type = line.type;
    bool currentlyEditing = NSLocationInRange(_editorDelegate.selectedRange.location, line.range) || NSIntersectionRange(_editorDelegate.selectedRange, line.range).length > 0;
            
    // Clear formatting characters etc.
    NSMutableIndexSet *muIndices = [line formattingRangesWithGlobalRange:YES includeNotes:NO includeOmissions:NO].mutableCopy;
    [muIndices addIndexesInRange:(NSRange){ line.position + line.sceneNumberRange.location, line.sceneNumberRange.length }];
    
    // We won't hide notes, except for colors
    if (line.colorRange.length) {
        [muIndices addIndexesInRange:(NSRange){ line.position + line.colorRange.location, line.colorRange.length }];
    }
    
    // Don't remove # and = for sections and synopsis lines
    if (line.type == section || line.type == synopse) {
        [muIndices removeIndexesInRange:(NSRange){ line.position, line.numberOfPrecedingFormattingCharacters }];
    }
    
    // Marker indices
    NSIndexSet *markerIndices = [NSIndexSet indexSetWithIndexesInRange:(NSRange){ line.position + line.markerRange.location, line.markerRange.length }];
    
    // Nothing to do (TODO: To avoid extra range calculations after every change to attributes, retrieve markup ranges AFTER checking if hiding markup is on)
    if (line.macroRanges.count == 0 && muIndices.count == 0 && markerIndices.count == 0 &&
        !(type == heading || type == transitionLine || type == character) &&
        !(line.string.containsOnlyWhitespace && line.string.length > 1)
        ) return 0;
    
    // Get string reference
    NSUInteger location = charIndexes[0];
    NSUInteger length = glyphRange.length;
    CFStringRef str = (__bridge CFStringRef)[self.textStorage.string substringWithRange:(NSRange){ location, length }];
    
    // Create a mutable copy
    CFMutableStringRef modifiedStr = CFStringCreateMutable(NULL, CFStringGetLength(str));
    CFStringAppend(modifiedStr, str);
    
    // Some types get rendered in uppercase
    if (style.uppercase) {
        CFStringUppercase(modifiedStr, NULL);
    }
    
    // Modified properties
    //NSGlyphProperty *modifiedProps = (NSGlyphProperty *)malloc(sizeof(NSGlyphProperty) * glyphRange.length);
    NSGlyphProperty *modifiedProps = CopyGlyphProperties(props, glyphRange);
    
    if (line.string.containsOnlyWhitespace && line.string.length >= 2) {
        // Show bullets instead of spaces on lines which contain whitespace only
        CFStringFindAndReplace(modifiedStr, CFSTR(" "), CFSTR("•"), CFRangeMake(0, CFStringGetLength(modifiedStr)), 0);
    } else if (_editorDelegate.hideFountainMarkup && !currentlyEditing) {
        // Hide markdown characters for the line we're not currently editing
        for (NSInteger i = 0; i < glyphRange.length; i++) {
            NSUInteger index = charIndexes[i];
            NSGlyphProperty prop = props[i];
                        
            // Hide the glyph if it's in the markup index set
            if ([muIndices containsIndex:index]) prop |= NSGlyphPropertyNull;
            
            modifiedProps[i] = prop;
        }
    }
    
    CGGlyph *newGlyphs = GetGlyphsForCharacters((__bridge CTFontRef)(aFont), modifiedStr);
    [self setGlyphs:newGlyphs properties:modifiedProps characterIndexes:charIndexes font:aFont forGlyphRange:glyphRange];
    
    free(newGlyphs);
    free(modifiedProps);    
    CFRelease(modifiedStr);
    
    return glyphRange.length;
}

// Macro display for glyphs
/*
if (line.macroRanges.count > 0 && !currentlyEditing) {
    for (NSValue* v in line.resolvedMacros) {
        NSRange macroRange = v.rangeValue;
        NSString* string = line.resolvedMacros[v];
        
        if (string.length < macroRange.length) {
            for (NSInteger i=0; i<string.length; i++) {
                CFStringRef chr = (__bridge CFStringRef)[string substringWithRange:NSMakeRange(i, 1)];
                CFStringReplace(modifiedStr, CFRangeMake(macroRange.location+i, 1), chr);
                //CFRelease(chr);
            }
            
            // Hide the remaining glyphs
            for (NSInteger i = 0; i < glyphRange.length; i++) {
                NSRange actualRange = NSMakeRange(macroRange.location + line.position + macroRange.location + string.length, macroRange.length - string.length);
                NSInteger ci = charIndexes[i];
                if (NSLocationInRange(ci, actualRange)) {
                    NSGlyphProperty prop = modifiedProps[i];
                    prop |= NSGlyphPropertyNull;
                    modifiedProps[i] = prop;
                }
            }
        }
    }
}
 */

NSGlyphProperty *CopyGlyphProperties(const NSGlyphProperty *props, NSRange glyphRange) {
    NSGlyphProperty *propsCopy = (NSGlyphProperty *)malloc(sizeof(NSGlyphProperty) * glyphRange.length);
    
    // Copy the properties from the original array to the new array
    if (propsCopy != NULL) {
        memcpy(propsCopy, props, glyphRange.length * sizeof(NSGlyphProperty));
    }
    return propsCopy;
}

/// Returns glyphs in given font
CGGlyph* GetGlyphsForCharacters(CTFontRef font, CFStringRef string)
{
    // Get the string length.
    CFIndex count = CFStringGetLength(string);
    
    // Allocate our buffers for characters and glyphs.
    unichar *characters = (UniChar *)malloc(sizeof(UniChar) * count);
    CGGlyph *glyphs = (CGGlyph *)malloc(sizeof(CGGlyph) * count);
    
    // Get the characters from the string.
    CFStringGetCharacters(string, CFRangeMake(0, count), characters);
    
    // Get the glyphs for the characters.
    CTFontGetGlyphsForCharacters(font, characters, glyphs, count);
    
    free(characters);
    
    return glyphs;
}

- (BOOL)layoutManager:(NSLayoutManager *)layoutManager shouldSetLineFragmentRect:(inout CGRect *)lineFragmentRect lineFragmentUsedRect:(inout CGRect *)lineFragmentUsedRect baselineOffset:(inout CGFloat *)baselineOffset inTextContainer:(NSTextContainer *)textContainer forGlyphRange:(NSRange)glyphRange
{
    NSRange range = [self characterRangeForGlyphRange:glyphRange actualGlyphRange:nil];
    NSDictionary* attrs = [self.textStorage attributesAtIndex:range.location effectiveRange:nil];
    
    if (attrs[@"BeatFolded"]) {
        lineFragmentRect->size.height = 0.0;
    } else if (attrs[@"representedLine"]) {
        Line* line = attrs[@"representedLine"];
        RenderStyle* style = [self.editorDelegate.editorStyles forLine:line];
        if (style.lineFragmentMultiplier != 1.0) {
            lineFragmentRect->size.height *= style.lineFragmentMultiplier;
        }
    }
        
    /*
    // A pretty solid idea for quasi-WYSIWYG mode!
     
    if ([BeatUserDefaults.sharedDefaults getBool:BeatSettingShowPageSeparators]) {
        for (NSValue* key in self.pageBreaks.allKeys) {
            Line* line = key.nonretainedObjectValue;
            
            if (NSMaxRange(range) == line.position) {
                lineFragmentRect->size.height = 100.0;
                
                break;
            }
        }
    }
    */
    
    return true;
}

/*
 
 // Ideas for quasi-wysiwyg-modes

- (CGFloat)layoutManager:(NSLayoutManager *)layoutManager paragraphSpacingAfterGlyphAtIndex:(NSUInteger)glyphIndex withProposedLineFragmentRect:(NSRect)rect
{
    NSInteger i = [self characterIndexForGlyphAtIndex:glyphIndex];
        
    if ([BeatUserDefaults.sharedDefaults getBool:BeatSettingShowPageSeparators]) {
        NSDictionary<Line*,NSArray<NSNumber*>*>* pageBreaks = _pageBreaksMap.dictionaryRepresentation;
        for (Line* line in pageBreaks.allKeys) {
            if (NSLocationInRange(i, line.range)) return 20.0;
        }
    }
    
    return 0.0;
}

- (CGFloat)layoutManager:(NSLayoutManager *)layoutManager paragraphSpacingBeforeGlyphAtIndex:(NSUInteger)glyphIndex withProposedLineFragmentRect:(NSRect)rect
{
    NSInteger i = [self characterIndexForGlyphAtIndex:glyphIndex];
    
    if ([BeatUserDefaults.sharedDefaults getBool:BeatSettingShowPageSeparators]) {
        NSDictionary<Line*,NSArray<NSNumber*>*>* pageBreaks = _pageBreaksMap.dictionaryRepresentation;
        for (Line* line in pageBreaks.allKeys) {
            NSInteger globalIndex = line.position + pageBreaks[line][1].integerValue;
            if (globalIndex == i) return 20.0;
        }
    }
    
    return 0.0;
}
 
 */


#pragma mark - Ensuring page separator layout

- (void)updatePageBreaks:(NSDictionary<NSValue *,NSArray<NSNumber *> *> *)pageBreaks
{
    _pageBreaksMap = NSMapTable.weakToStrongObjectsMapTable;
    for (NSValue* key in pageBreaks.allKeys) {
        [_pageBreaksMap setObject:pageBreaks[key] forKey:key.nonretainedObjectValue];
    }
    
    /*
    // Idea for quasi-wysiwyg mode. This code won't work as it is, but yeah.
     
    // When setting page breaks, we'll need to invalidate layout for each existing page break
    // (just to be on the safe side for future changes, which might include quasi-wysiwyg capabilities)
    for (NSValue* val in self.pageBreaks.allKeys) {
        Line* line = val.nonretainedObjectValue;
        if (line == nil) continue;
        
        NSRange range = line.textRange;
        if (NSMaxRange(range) > self.textView.text.length) {
            range.length -= NSMaxRange(range) - self.textView.text.length;
        }
        
        if (range.length > 0) [self invalidateDisplayForCharacterRange:range];
    }
    
    _pageBreaks = pageBreaks;
     */
}

#pragma mark - Ensuring layout for lines

- (void)ensureLayoutForLinesInRange:(NSRange)range
{
    NSArray<Line*>* lines = [self.editorDelegate.parser linesInRange:range];
    
    for (Line* line in lines) {
        [self invalidateGlyphsForCharacterRange:line.range changeInLength:0 actualCharacterRange:nil];
    }
}


@end
/*
 
 searching for sunlight, there in your room
 trolling for one light, there in your gloom
 
 you dream of a better day
 alone with the moon
 
 all things are nothing, there in your tomb
 all things are nothing, assured is your doom
 
 you dream of a better day
 alone with the moon
 
 laughing and joking, they all end too soon
 forgotten memories, forgotten tunes
 
 you dream of a better day
 alone with the moon
 
        that day
           it's coming soon

              alone with
                 the moon
 
 */
