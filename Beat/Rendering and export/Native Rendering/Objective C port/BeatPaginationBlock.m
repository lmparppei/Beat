//
//  BeatPaginationBlock.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 12.12.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatPaginationBlock.h"
#import "BeatPagination.h"
#import <BeatParsing/BeatParsing.h>
#import "Beat-Swift.h"

@interface BeatPaginationBlock ()
@property (nonatomic) bool dualDialogueElement;
@property (nonatomic) bool dualDialogueContainer;
@property (nonatomic) NSAttributedString* renderedString;
@property (nonatomic) CGFloat calculatedHeight;

// Dual dialogue blocks
@property (nonatomic) NSMutableAttributedString* leftColumn;
@property (nonatomic) NSMutableAttributedString* rightColumn;

@property (nonatomic) BeatPaginationBlock* leftColumnBlock;
@property (nonatomic) BeatPaginationBlock* rightColumnBlock;

@property (nonatomic) id<BeatPageDelegate> delegate;

@property (nonatomic) NSMutableDictionary<NSUUID*, NSNumber*>* lineHeights;

@end

@implementation BeatPaginationBlock

+ (BeatPaginationBlock*)withLines:(NSArray<Line*>*)lines delegate:(id<BeatPageDelegate>)delegate {
	return [BeatPaginationBlock.alloc initWithLines:lines delegate:delegate isDualDialogueElement:false];
}
+ (BeatPaginationBlock*)withLines:(NSArray<Line*>*)lines delegate:(id<BeatPageDelegate>)delegate isDualDialogueElement:(bool)dualDialogueElement {
	return [BeatPaginationBlock.alloc initWithLines:lines delegate:delegate isDualDialogueElement:dualDialogueElement];
}

- (instancetype)initWithLines:(NSArray<Line*>*)lines delegate:(id<BeatPageDelegate>)delegate isDualDialogueElement:(bool)dualDialogueElement {
	self = [super init];
	if (self) {
		_delegate = delegate;
		
		_calculatedHeight = -1.0;
		
		_lines = lines;
		_dualDialogueElement = dualDialogueElement;
		
		if (!_dualDialogueElement) {
			Line *firstLine = _lines.firstObject;
			if (firstLine.nextElementIsDualDialogue) {
				_dualDialogueContainer = true;
			}
		}
	}
	return self;
}

- (LineType)type {
	return self.lines.firstObject.type;
}

- (CGFloat)height {
	if (_calculatedHeight > 0) return _calculatedHeight;
	
	CGFloat height = 0.0;
	if (self.dualDialogueContainer) {
		CGFloat leftHeight = self.leftColumnBlock.height;
		CGFloat rightHeight = self.rightColumnBlock.height;
		
		if (leftHeight >= rightHeight) height = leftHeight;
		else height = rightHeight;
	} else {
		for (Line* line in self.lines) {
			height += [self heightForLine:line];
		}
	}
	
	return height;
}

- (CGFloat)heightForLine:(Line*)line {
	if (self.lineHeights == nil) self.lineHeights = NSMutableDictionary.new;
	if (self.lineHeights[line.uuid] != nil) return self.lineHeights[line.uuid].floatValue;
	
	CGFloat height = 0.0;
	
	NSMutableParagraphStyle* pStyle = NSMutableParagraphStyle.new;
	pStyle.maximumLineHeight = BeatPagination.lineHeight;
	
	NSAttributedString* string = [NSMutableAttributedString.alloc initWithString:line.stripFormatting attributes:@{
		NSFontAttributeName: _delegate.fonts.courier,
		NSParagraphStyleAttributeName: pStyle
	}];
	
	RenderStyle *style = [self.delegate.styles forElement:line.typeName];
	CGFloat width = (_delegate.settings.paperSize == BeatA4) ? style.widthA4 : style.widthLetter;
	
	height = [string heightWithContainerWidth:width] + style.marginTop;
	
	self.lineHeights[line.uuid] = [NSNumber numberWithFloat:height];
	return height;
}

- (NSAttributedString*)attributedString {
	if (_renderedString == nil) {
		if (self.dualDialogueContainer) {
			//
			NSLog(@"## DUAL DIALOGUE RENDERING MISSING");
		}
		
		NSMutableAttributedString *attrStr = NSMutableAttributedString.new;
		for (Line* line in self.lines) { @autoreleasepool {
			NSAttributedString *lineStr = [self renderLine:line];
			[attrStr appendAttributedString:lineStr];
			
			_renderedString = attrStr;
		} }
	}
	
	return _renderedString;
}

/// Create and render the individual line elements
- (NSAttributedString*)renderLine:(Line*)line {
	return [self renderLine:line firstElementOnPage:false];
}

- (NSAttributedString*)renderLine:(Line*)line firstElementOnPage:(bool)firstElementOnPage {
	self.leftColumn = nil;
	self.rightColumn = nil;
	
	NSMutableAttributedString *attributedString = NSMutableAttributedString.new;
	
	return attributedString;
}

- (Line*)lineAt:(CGFloat)y {
	CGFloat height = 0.0;
	
	for (Line* line in self.lines) {
		height += [self heightForLine:line];
		if (height >= y) return line;
	}
	
	return nil;
}

- (CGFloat)heightUntil:(Line*)lineToFind {
	CGFloat height = 0.0;
	
	for (Line* line in self.lines) {
		if (line == lineToFind) {
			return height;
		}
		
		height += [self heightForLine:line];
	}
	
	return 0.0;
}

- (Line*)findSpillerAt:(CGFloat)remainingSpace {
	CGFloat height = 0.0;
	
	for (Line* line in self.lines) {
		height += [self heightForLine:line];
		
		if (height >= remainingSpace) {
			return line;
		}
	}
	
	return nil;
}




@end
