//
//  BeatLayoutManager.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 11.2.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatLayoutManager.h"
#import <BeatCore/BeatCore.h>
#import <BeatThemes/BeatThemes.h>
#import <BeatCore/BeatCore-Swift.h>
#import <BeatCore/BeatMeasure.h>
#import <BeatDynamicColor/BeatDynamicColor.h>

#import "BeatRevisions.h"

@interface BeatLayoutManager()
@property (nonatomic) NSMutableParagraphStyle* _Nullable markerStyle;
@property (nonatomic) NSMutableParagraphStyle* _Nullable sceneNumberStyle;
@property (nonatomic, weak) BXTextView* textView;
@end

#define X_OFFSET 50.0

#if TARGET_OS_IOS
    #define BXPoint CGPoint
    #define BXRectFill UIRectFill
    #define BXBezierPath UIBezierPath

    // Because of different line heights on iOS, we'll need to add an offset
    //#define Y_OFFSET -3.5
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
	}
	return self;
}

- (void)dealloc
{
    self.pageBreaks = nil;
}

#pragma mark - Draw glyphs

- (void)drawGlyphsForGlyphRange:(NSRange)glyphsToShow atPoint:(BXPoint)origin
{
	[super drawGlyphsForGlyphRange:glyphsToShow atPoint:origin];
    
    CGSize inset = [self offsetSize];
	NSRange charRange = [self characterRangeForGlyphRange:glyphsToShow actualGlyphRange:nil];
    
    // Enumerate lines in drawn range
    [self.textStorage enumerateAttribute:@"representedLine" inRange:charRange options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
        Line* line = (Line*)value;
        if (line == nil) return;
        
        // Do nothing if this line is not a marker or a heading
        if (line.markerRange.length == 0 && line.type != heading && line.beats.count == 0) return;
        
        // Get range for the first character. For headings and markers we won't need anything else.
        NSRange r = NSMakeRange(line.position, 1);
        if (self.editorDelegate.hideFountainMarkup) {
            // If the editor hides Fountain markup, there's a chance that the line is hidden (if using a formatting character, ie. ".INT. SOMETHING"
            if (line.length > 1) r.location += 1;
            else r = line.range;
        }
        
        NSRange lineRange = [self glyphRangeForCharacterRange:r actualCharacterRange:nil];
        CGRect boundingRect = [self boundingRectForGlyphRange:lineRange inTextContainer:self.textContainers.firstObject];

        // Actual rect position
        CGRect rect = CGRectMake(inset.width + boundingRect.origin.x, inset.height + boundingRect.origin.y, boundingRect.size.width, boundingRect.size.height);
        
        // Draw scene numbers
        if (line.type == heading) {
            [self drawSceneNumberForLine:line rect:rect inset:inset];
        }
        
        // Draw markers
        if (line.markerRange.length > 0) {
            [self drawMarkerForLine:line rect:rect inset:inset];
        }
                
        if (line.beats.count > 0) {
            [self drawBeat:rect inset:inset];
        }
    }];
}


#pragma mark - Draw page separators and numbers

- (void)drawPageSeparators:(const NSRange*)glyphsToShow
{
    if (!self.editorDelegate.showPageNumbers || ![BeatUserDefaults.sharedDefaults getBool:BeatSettingShowPageSeparators]) return;
    
    static BXColor* pageBreakColor;
    if (pageBreakColor == nil) pageBreakColor = [ThemeManager.sharedManager.invisibleTextColor colorWithAlphaComponent:0.3];
    
    BXColor* pageNumberColor = ThemeManager.sharedManager.pageNumberColor;
    
    CGSize inset = [self offsetSize];
    
    NSRange charRange = [self characterRangeForGlyphRange:*glyphsToShow actualGlyphRange:nil];
    for (NSValue* key in self.pageBreaks.allKeys) {
        Line* line = key.nonretainedObjectValue;
        if (NSIntersectionRange(line.range, charRange).length == 0) continue;
        
        // The dictionary value is always a two-item array with [pageNumber, pageBreakPosition]
        NSArray<NSNumber*>* values = self.pageBreaks[key];
        
        // Page number
        NSInteger pageNumber = values[0].integerValue;
        
        // Get the glyph position
        NSUInteger localIndex = values[1].unsignedIntegerValue;
        NSInteger globalIndex = line.position + localIndex;
        NSInteger glyphIndex = [self glyphIndexForCharacterAtIndex:globalIndex];
        
        // Get rect and local range
        NSRange lRange;

        CGRect r = [self lineFragmentRectForGlyphAtIndex:glyphIndex effectiveRange:&lRange];
        
        // Draw page separators if needed
        if ([BeatUserDefaults.sharedDefaults getBool:BeatSettingShowPageSeparators]) {
            NSRange cRange = [self characterRangeForGlyphRange:lRange actualGlyphRange:nil];
            
            if (globalIndex != cRange.location && globalIndex != NSMaxRange(cRange)) {
                // Page break happens mid-element. Let's draw a bezier curve here.
                CGRect actualRect = [self boundingRectForGlyphRange:NSMakeRange(glyphIndex,1) inTextContainer:self.textContainers.firstObject];
                
                BXBezierPath* lbPath = BXBezierPath.new;
                
                CGFloat baseline = r.origin.y + inset.height + actualRect.size.height;
                
                [lbPath moveToPoint:CGPointMake(0, baseline)];
                [lbPath addLineToPoint:CGPointMake(inset.width + actualRect.origin.x, baseline)];
                [lbPath addLineToPoint:CGPointMake(inset.width + actualRect.origin.x, r.origin.y + inset.height)];
                [lbPath addLineToPoint:CGPointMake(CGRectGetMaxX(r) + inset.width * 2, r.origin.y + inset.height)];
                
                [pageBreakColor setStroke];
                [lbPath stroke];
                
            } else {
                // Draw page separator
                CGRect separatorRect = CGRectMake(inset.width + r.origin.x, inset.height + r.origin.y, r.size.width, 1.0);
                
                [pageBreakColor setFill];
                BXRectFill(separatorRect);
            }
        }
        
        
        // This is how you draw the page number. We just need the page number value from text view as well.
        NSString* pNumber = [NSString stringWithFormat:@"%lu.",pageNumber];
    
        [pNumber drawInRect:NSMakeRect(CGRectGetMaxX(r) + inset.width - 60.0, inset.height + r.origin.y, 30.0, self.editorDelegate.editorLineHeight) withAttributes:@{
            NSFontAttributeName: self.editorDelegate.courier,
            NSForegroundColorAttributeName: pageNumberColor,
            NSParagraphStyleAttributeName: self.pageNumberStyle
        }];

    }
    
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
    static NSDictionary<NSString*, NSNumber*>* revisionLevels;
    static NSMutableDictionary* bgColors;
    

    if (_textView == nil) _textView = _editorDelegate.getTextView;
    
    if (revisionLevels == nil) {
        bgColors = [NSMutableDictionary dictionaryWithCapacity:10];
        revisionLevels = BeatRevisions.revisionLevels;
    }
        
    CGSize inset = [self offsetSize];
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
            if (range.location < 0 || NSMaxRange(range) <= 0) return;
            
            BeatRevisionItem* revision = attrs[BeatRevisions.attributeKey];
            BeatTag* tag = attrs[BeatTagging.attributeKey];
            BeatReviewItem *review = attrs[BeatReview.attributeKey];
                        
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
            
            if (review != nil && !review.emptyReview) {
                if (bgColors[@"review"] == nil) {
                    BXColor *reviewColor = BeatReview.reviewColor;
                    bgColors[@"review"] = [reviewColor colorWithAlphaComponent:.5];
                }
                BXColor *color = bgColors[@"review"];
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
            }
            
            if (tag != nil && showTags) {
                if (bgColors[tag.typeAsString] == nil) {
                    bgColors[tag.typeAsString] = [[BeatTagging colorFor:tag.type] colorWithAlphaComponent:0.5];
                }

                BXColor *tagColor = bgColors[tag.typeAsString];
                [tagColor setFill];
                
                BXRectFill(aRect);
            }
            
            // Make note if this line has a revision
            if (revision.colorName != nil && (revision.type == RevisionAddition || revision.type == RevisionCharacterRemoved)) {
                NSInteger r = revisionLevels[revision.colorName].integerValue;
                if (r > revisionLevel) revisionLevel = r;
            }
            
            // Draw revision backgrounds last, so the underlines go on top of other stuff.
            if (revision.type == RevisionAddition && showRevisions && rRange.length > 0) {
                CGRect revisionRect = aRect;
                
                if (bgColors[revision.colorName] == nil) {
                    bgColors[revision.colorName] = [[BeatColors color:revision.colorName] colorWithAlphaComponent:.3];
                }
                [bgColors[revision.colorName] setFill];
                
                revisionRect.origin.y += revisionRect.size.height - 1.0;
                revisionRect.size.height = 2.0;
                
                BXRectFill(revisionRect);
            }
        }];
        
        // If we found a revision, let's draw a marker for it
        if (revisionLevel >= 0) {
            // Calculate rect for the marker position
            CGRect rect = CGRectMake(inset.width + documentWidth - 30 - X_OFFSET,
                                     inset.height + usedRect.origin.y - Y_OFFSET,
                                     22,
                                     usedRect.size.height + 1.0);
            
            NSString* revision = BeatRevisions.revisionColors[revisionLevel];
            NSAttributedString* symbol = [self markerFor:revision];
            
            [symbol drawInRect:rect];
        }
    }];
    
    [super drawBackgroundForGlyphRange:glyphsToShow atPoint:origin];
}

-(NSArray*)rectsForGlyphRange:(NSRange)glyphsToShow
{
    NSMutableArray *rects = NSMutableArray.new;
    NSTextContainer *tc = self.textContainers.firstObject;
    
    [self enumerateLineFragmentsForGlyphRange:glyphsToShow usingBlock:^(CGRect rect, CGRect usedRect, NSTextContainer * _Nonnull textContainer, NSRange glyphRange, BOOL * _Nonnull stop) {
        CGRect lfRect = [self boundingRectForGlyphRange:NSIntersectionRange(glyphsToShow, glyphRange) inTextContainer:tc];
        [rects addObject:@(lfRect)];
    }];
    
    return rects;
}

#pragma mark - Draw page separators




#pragma mark - Draw scene numbers

/// Draws the scene number for given line in a pre-defined rect
- (void)drawSceneNumberForLine:(Line*)line rect:(CGRect)rect inset:(CGSize)inset
{
    CGFloat yOffset = 0.0;
    #if TARGET_OS_IOS
        yOffset = 1.0;
    #endif
    
    
    // Scene number drawing is off, return
    if (!self.editorDelegate.showSceneNumberLabels) return;
    
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
        NSFontAttributeName: self.editorDelegate.courier,
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
			NSFontAttributeName: self.editorDelegate.courier,
			NSForegroundColorAttributeName: color,
			NSParagraphStyleAttributeName: self.sceneNumberStyle
		}];
	}];
}


#pragma mark - Draw markers

- (void)drawMarkerForLine:(Line*)line rect:(CGRect)rect inset:(CGSize)inset {
    
    CGRect r = CGRectMake(inset.width + X_OFFSET, rect.origin.y, 12, rect.size.height);
    
    BXColor* color;
    if (line.marker.length > 0) color = [BeatColors color:line.marker];
    if (color == nil) color = BeatColors.colors[@"orange"];
    [color setFill];
    
    BXBezierPath* path = [self markerPath:r];
    [path fill];
}

- (BXBezierPath*)markerPath:(CGRect)rect {
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
    
    [path closePath];
    return path;
}

-(NSAttributedString*)markerFor:(NSString*)revisionColor {
    if (revisionColor == nil) return NSAttributedString.new;
    
    static BXColor* markerColor;
    static NSCache* markers;
    
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
    
    NSAttributedString* marker = [markers objectForKey:revisionColor];
    if (marker == nil) {
        // Draw string
        NSString* symbol = BeatRevisions.revisionMarkers[revisionColor];
        marker = [NSAttributedString.alloc initWithString:symbol attributes:@{
            NSFontAttributeName: self.editorDelegate.courier,
            NSForegroundColorAttributeName: markerColor,
            NSParagraphStyleAttributeName: _markerStyle
        }];
        
        [markers setObject:marker forKey:revisionColor];
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


#pragma mark - Draw disclosure triangle

/// This is just a concept for now
/*
- (void)drawDisclosureForRange:(NSRange)glyphRange charRange:(NSRange)charRange
{
    BXTextView* textView = self.editorDelegate.getTextView;
#if TARGET_OS_IOS
    CGSize inset = CGSizeMake(textView.textContainerInset.left, textView.textContainerInset.top);
#else
    CGSize inset = textView.textContainerInset;
#endif
    
    NSInteger i = [self.editorDelegate.parser lineIndexAtPosition:charRange.location];
    ContinuousFountainParser* parser = self.editorDelegate.parser;
    
    NSMutableArray<Line*>* lines = NSMutableArray.new;
    for (; i < parser.lines.count; i++) {
        Line* l = parser.lines[i];
        if (!NSLocationInRange(l.position, charRange)) break;
        
        if (l.type == section) [lines addObject:l];
    }
    
    for (Line* l in lines) {
        NSRange sectionGlyphRange = [self glyphRangeForCharacterRange:NSMakeRange(l.position, 1) actualCharacterRange:nil];
        CGRect r = [self boundingRectForGlyphRange:sectionGlyphRange inTextContainer:self.textContainers.firstObject];
        
        CGRect triangle = CGRectMake(inset.width, r.origin.y + inset.height + r.size.height - 15, 12, 12);
        [BXColor.redColor setFill];
        
        BXRectFill(triangle);
    }
}
 */


#pragma mark - Crossplatform helpers

-(void)saveGraphicsState {
#if !TARGET_OS_IOS
        [NSGraphicsContext saveGraphicsState];
#endif
}
-(void)restoreGraphicsState {
#if !TARGET_OS_IOS
        [NSGraphicsContext restoreGraphicsState];
#endif
}
-(CGSize)offsetSize {
#if TARGET_OS_IOS
    CGSize offset = CGSizeMake(_editorDelegate.getTextView.textContainerInset.left, _editorDelegate.getTextView.textContainerInset.top);
#else
    CGSize offset = _editorDelegate.getTextView.textContainerInset;
#endif
    return offset;
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
