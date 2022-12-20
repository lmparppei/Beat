//
//  BeatRendering.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 19.12.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//
/**
 
 This class renders paginated content to `NSAttributedString`.
 Only works with macOS.
 
 */

#import "BeatRendering.h"
#import "BeatPagination.h"
#import "BeatPaginationBlock.h"
#import "Beat-Swift.h"

@interface BeatRendering()
@property (nonatomic) BeatExportSettings* settings;
//@property (nonatomic) id<BeatPageDelegate> delegate;
@property (nonatomic) Styles* styles;
@property (nonatomic) BeatFonts* fonts;
@end

@implementation BeatRendering

- (instancetype)initWithSettings:(BeatExportSettings*)settings {
	self = [super init];
	if (self) {
		_settings = settings;
		_fonts = BeatFonts.sharedFonts;
		
		// If we have received custom styles, use those
		if ([settings.styles isKindOfClass:Styles.class]) {
			_styles = settings.styles;
		} else {
			_styles = Styles.shared;
		}
	}
	return self;
}

/// Returns a long attributed string, rather than paginated content. Not compatible with iOS.
- (NSAttributedString*)renderContent:(NSArray<BeatPaginationPage*>*)pages {
	NSMutableAttributedString* attrStr = NSMutableAttributedString.new;
	for (BeatPaginationPage* page in pages) {
		for (BeatPaginationBlock* block in page.blocks) {
			NSAttributedString* renderedBlock = [self renderBlock:block dualDialogueElement:false firstElementOnPage:false];
			[attrStr appendAttributedString:renderedBlock];
		}
	}
	
	return attrStr;
}

/// Returns pages rendered as `NSAttributedString` objects. Not compatible with iOS.
- (NSArray<NSAttributedString*>*)renderPages:(NSArray<BeatPaginationPage*>*)pages {
	NSMutableArray<NSAttributedString*>* renderedPages = NSMutableArray.new;
	
	for (BeatPaginationPage* page in pages) {
		NSAttributedString* renderedPage = [self renderPage:page];
		[renderedPages addObject:renderedPage];
	}
	
	return renderedPages;
}

- (NSAttributedString*)renderPage:(BeatPaginationPage*)page {
	NSMutableAttributedString* attrStr = NSMutableAttributedString.new;
	
	for (BeatPaginationBlock* block in page.blocks) {
		bool firstElement = (block == page.blocks.firstObject) ? true : false;
		
		NSAttributedString* blockString = [self renderBlock:block dualDialogueElement:false firstElementOnPage:firstElement];
		[attrStr appendAttributedString:blockString];
	}
	
	return attrStr;
}

- (NSAttributedString*)renderBlock:(BeatPaginationBlock*)block dualDialogueElement:(bool)dualDialogueElement firstElementOnPage:(bool)firstElementOnPage {
	NSMutableAttributedString* string = NSMutableAttributedString.new;
	
	
	
	return string;
}

/// Renders a single line
- (NSAttributedString*)renderLine:(Line*)line ofBlock:(BeatPaginationBlock*)block dualDialogueElement:(bool)dualDialogueElement firstElementOnPage:(bool)firstElementOnPage {
	NSDictionary* attrs = [self.delegate attributesForLine:line dualDialogue:block.dualDialogueElement];
	NSString* string = [NSString stringWithFormat:@"%@\n", line.string]; // Add a line break
	
	NSMutableAttributedString *attributedString = [NSMutableAttributedString.alloc initWithString:string attributes:attrs];
	
	// Remove top margin for first elements on a page
	if (firstElementOnPage) {
		NSMutableParagraphStyle* pStyle = attrs[NSParagraphStyleAttributeName];
		pStyle = pStyle.mutableCopy;
		pStyle.paragraphSpacingBefore = 0.0;
	}
	
	// Inline stylization
	if (!line.noFormatting) {
		NSAttributedString* inlineAttrs = line.attributedStringForFDX;
		[inlineAttrs enumerateAttribute:@"Style" inRange:NSMakeRange(0, inlineAttrs.length) options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
			NSString* styleStr = (NSString*)value;
			if (styleStr.length == 0) return;
			
			NSArray* styleNames = [styleStr componentsSeparatedByString:@","];
			NSFontTraitMask traits = 0;
			
			if ([styleNames containsObject:@"Bold"]) traits |= NSBoldFontMask;
			if ([styleNames containsObject:@"Italic"]) traits |= NSItalicFontMask;
			[attributedString applyFontTraits:traits range:range];
			
			// Apply underline if needed
			if ([styleNames containsObject:@"Underline"]) {
				[attributedString addAttribute:NSUnderlineStyleAttributeName value:@(1) range:range];
				[attributedString addAttribute:NSUnderlineColorAttributeName value:BXColor.blackColor range:range];
			}
		}];
	}
	
	bool multiline = [attributedString.string containsString:@"\n"];
	if (multiline) {
		NSMutableParagraphStyle* pStyle = attrs[NSParagraphStyleAttributeName];
		NSMutableParagraphStyle* fixedStyle = pStyle.mutableCopy;
		fixedStyle.paragraphSpacingBefore = 0.0;
		
		NSInteger i = [attributedString.string rangeOfString:@"\n"].location;
		[attributedString addAttribute:NSParagraphStyleAttributeName value:fixedStyle range:NSMakeRange(0, attributedString.length)];
		[attributedString addAttribute:NSParagraphStyleAttributeName value:pStyle range:NSMakeRange(0, i)];
	}
	
	// Strip invisible stuff
	NSMutableIndexSet* contentRanges = [NSMutableIndexSet.alloc initWithIndexSet:line.contentRanges];
	[contentRanges addIndex:attributedString.length - 1]; // Add the last index to include our newly-added line break
	NSMutableAttributedString *result = NSMutableAttributedString.new;
	
	[contentRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		if (range.length == 0) return;
		
		NSAttributedString* content = [attributedString attributedSubstringFromRange:range];
		[result appendAttributedString:content];
	}];
	
	// For headings, add some extra formatting (wrap them in a table and insert scene numbers)
	if (line.type == heading) {
		result = [self renderHeading:line content:result firstElementOnPage:firstElementOnPage];
	}
	
	return result;
}

/// Adds scene numbers to a heading block
- (NSMutableAttributedString*)renderHeading:(Line*)line content:(NSMutableAttributedString*)content firstElementOnPage:(bool)firstElementOnPage {
	// Get render settings
	bool printSceneNumbers = _settings.printSceneNumbers;
	CGFloat contentPadding = _styles.page.contentPadding;
	CGFloat width = [self widthFor:line];
	RenderStyle* style = [_styles forElement:line.typeName];
	
	// Initialize result
	NSMutableAttributedString* attrStr = NSMutableAttributedString.new;
	
	// Create a table with three cells:
	// [scene number] [INT. SCENE HEADING] [scene number]
	
	NSTextTable* table = NSTextTable.new;
	table.collapsesBorders = true;
	table.numberOfColumns = 3;

	NSTextTableBlock* leftCell = [NSTextTableBlock.alloc initWithTable:table startingRow:0 rowSpan:1 startingColumn:0 columnSpan:1];
	NSTextTableBlock* contentCell = [NSTextTableBlock.alloc initWithTable:table startingRow:0 rowSpan:1 startingColumn:1 columnSpan:1];
	NSTextTableBlock* rightCell = [NSTextTableBlock.alloc initWithTable:table startingRow:0 rowSpan:1 startingColumn:2 columnSpan:1];
	
	[leftCell setContentWidth:contentPadding type:NSTextBlockAbsoluteValueType];
	[contentCell setContentWidth:width type:NSTextBlockAbsoluteValueType];
	[rightCell setContentWidth:contentPadding - 10.0 type:NSTextBlockAbsoluteValueType];
	
	// Stylize the actual heading part.
	// Make a copy of the style just in case.
	NSMutableParagraphStyle* contentStyle = [content attribute:NSParagraphStyleAttributeName atIndex:0 effectiveRange:nil];
	contentStyle = contentStyle.mutableCopy;
	BXFont* font = [content attribute:NSFontAttributeName atIndex:0 effectiveRange:nil];
	
	// Set margins and indents to zero (as we're inside a cell)
	contentStyle.headIndent = 0;
	contentStyle.firstLineHeadIndent = 0;
	contentStyle.textBlocks = @[contentCell];
	if (firstElementOnPage) contentStyle.paragraphSpacingBefore = 0.0;
	
	// Replace paragraph attributes in the content style
	[content addAttribute:NSParagraphStyleAttributeName value:contentStyle range:NSMakeRange(0, content.length)];
		
	NSMutableParagraphStyle* leftStyle = contentStyle.mutableCopy;
	leftStyle.textBlocks = @[leftCell];
	leftStyle.paragraphSpacingBefore = contentStyle.paragraphSpacingBefore;
	leftStyle.firstLineHeadIndent = 6.0;
	
	NSMutableParagraphStyle* rightStyle = leftStyle.mutableCopy;
	rightStyle.textBlocks = @[rightCell];
	rightStyle.alignment = NSTextAlignmentRight;
	
	// Create scene number string
	NSString* sceneNumber = (printSceneNumbers) ? [NSString stringWithFormat:@"%@\n", line.sceneNumber] : @" \n";

	// Create left/right scene numbers
	NSMutableAttributedString* sceneNumberLeft = [NSMutableAttributedString.alloc initWithString:sceneNumber attributes: @{
												  NSFontAttributeName: font,
												  NSForegroundColorAttributeName: BXColor.blackColor,
												  NSParagraphStyleAttributeName: leftStyle
	}];
	
	NSMutableAttributedString* sceneNumberRight = [NSMutableAttributedString.alloc initWithString:sceneNumber attributes: @{
												  NSFontAttributeName: font,
												  NSForegroundColorAttributeName: BXColor.blackColor,
												  NSParagraphStyleAttributeName: rightStyle
	}];

	// Combine the parts
	[attrStr appendAttributedString:sceneNumberLeft];
	[attrStr appendAttributedString:content];
	[attrStr appendAttributedString:sceneNumberRight];
	
	return attrStr;
}

- (NSAttributedString*)pageNumberBlockForPage:(BeatPaginationPage*)page {
	NSInteger index = [self.delegate.pages indexOfObject:page];
	if (index == NSNotFound) index = self.delegate.pages.count;
	
	return [self pageNumberBlockForPageNumber:index + 1];
}

- (NSAttributedString*)pageNumberBlockForPageNumber:(NSInteger)pageNumber {
	// First page does not have a page number
	NSString* pageNumberString = (pageNumber > 1) ? [NSString stringWithFormat:@"%lu.\n", pageNumber] : @" \n";
	
	NSTextTable* table = NSTextTable.new;
	NSTextTableBlock* leftCell = [NSTextTableBlock.alloc initWithTable:table startingRow:0 rowSpan:1 startingColumn:0 columnSpan:1];
	NSTextTableBlock* headerCell = [NSTextTableBlock.alloc initWithTable:table startingRow:0 rowSpan:1 startingColumn:1 columnSpan:1];
	NSTextTableBlock* rightCell = [NSTextTableBlock.alloc initWithTable:table startingRow:0 rowSpan:1 startingColumn:2 columnSpan:1];
	
	[leftCell setContentWidth:15 type:NSTextBlockPercentageValueType];
	[headerCell setContentWidth:70 type:NSTextBlockPercentageValueType];
	[rightCell setContentWidth:15 type:NSTextBlockPercentageValueType];
	
	NSMutableParagraphStyle* leftStyle = NSMutableParagraphStyle.new;
	leftStyle.textBlocks = @[leftCell];
	
	NSMutableParagraphStyle* headerStyle = NSMutableParagraphStyle.new;
	headerStyle.textBlocks = @[headerCell];
	headerStyle.alignment = NSTextAlignmentCenter;
	headerStyle.maximumLineHeight = BeatPagination.lineHeight;
	
	NSMutableParagraphStyle* rightStyle = NSMutableParagraphStyle.new;
	rightStyle.textBlocks = @[rightCell];
	rightStyle.alignment = NSTextAlignmentRight;
	rightStyle.maximumLineHeight = BeatPagination.lineHeight;
	rightStyle.paragraphSpacing = BeatPagination.lineHeight;
	
	// Left cell is just empty, no additional styles needed
	NSMutableAttributedString* leftContent = [NSMutableAttributedString.alloc initWithString:@" \n" attributes:@{
		NSParagraphStyleAttributeName: leftStyle
	}];
	// Header content (centered at the top of page)
	NSMutableAttributedString* headerContent = [NSMutableAttributedString.alloc initWithString:self.settings.header attributes:@{
		NSParagraphStyleAttributeName: headerStyle,
		NSFontAttributeName: _fonts.courier,
		NSForegroundColorAttributeName: NSColor.blackColor
	}];
	// Actual page number goes in right corner
	NSMutableAttributedString* rightContent = [NSMutableAttributedString.alloc initWithString:pageNumberString attributes:@{
		NSParagraphStyleAttributeName: rightStyle,
		NSFontAttributeName: _fonts.courier,
		NSForegroundColorAttributeName: NSColor.blackColor
	}];
	
	NSMutableAttributedString* pageNumberBlock = NSMutableAttributedString.new;
	[pageNumberBlock appendAttributedString:leftContent];
	[pageNumberBlock appendAttributedString:headerContent];
	[pageNumberBlock appendAttributedString:rightContent];
	
	return pageNumberBlock;
}


#pragma mark - Convenience methods

- (CGFloat)widthFor:(Line*)line {
	RenderStyle* style = [_styles forElement:line.typeName];
	CGFloat width = (_settings.paperSize == BeatA4) ? style.widthA4 : style.widthLetter;
	return width;
}

@end
