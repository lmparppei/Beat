//
//  BeatRendering.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 19.12.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//
/**
 
 This class renders paginated content to `NSAttributedString` on **macOS**.
 Can be used both stand-alone and as hooked up to `BeatPaginationManager` or `BeatPagination`.
 
 */

#import "BeatRendering.h"
#import <BeatPagination2/BeatPagination2.h>
#import "Beat-Swift.h"

@interface BeatRendering()
//@property (nonatomic) id<BeatPageDelegate> delegate;
@property (nonatomic) BeatRenderStyles* styles;
@property (nonatomic, weak) BeatFonts* fonts;
@property (nonatomic) NSMutableDictionary<NSNumber*, NSMutableDictionary<NSNumber*, NSDictionary*>*>* lineTypeAttributes;

@end

@implementation BeatRendering

- (instancetype)initWithSettings:(BeatExportSettings*)settings  {
	self = [super init];
	if (self) {
		_settings = settings;
		[self setup];
	}
	return self;
}

- (void)setup {
	_fonts = BeatFonts.sharedFonts;
	_lineTypeAttributes = NSMutableDictionary.new;
}

- (BeatExportSettings*)settings {
	if (self.pagination != nil) {
		return self.pagination.settings;
	} else {
		return _settings;
	}
}

- (void)reloadStyles {
	[BeatRenderStyles.shared reload];
	self.lineTypeAttributes = NSMutableDictionary.new;
}

- (BeatRenderStyles*)styles {
	if ([self.settings.styles isKindOfClass:BeatRenderStyles.class] && self.settings.styles != nil) {
		return self.settings.styles;
	} else {
		return BeatRenderStyles.shared;
	}
}

/// Returns a long attributed string, rather than paginated content. Not compatible with iOS.
- (NSAttributedString*)renderContent:(NSArray<BeatPaginationPage*>*)pages {
	NSMutableAttributedString* attrStr = NSMutableAttributedString.new;
	for (BeatPaginationPage* page in pages) {
		for (BeatPaginationBlock* block in page.blocks) {
			NSAttributedString* renderedBlock = [self renderBlock:block firstElementOnPage:false];
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
		
		NSAttributedString* blockString = [self renderBlock:block firstElementOnPage:firstElement];
		[attrStr appendAttributedString:blockString];
	}
	
	return attrStr;
}


- (NSAttributedString*)renderBlock:(BeatPaginationBlock*)block firstElementOnPage:(bool)firstElementOnPage {
	if (block.renderedString == nil) {
		if (block.dualDialogueContainer) {
			// Render dual dialogue block (enter kind of recursion)
			block.renderedString = [self renderDualDialogueContainer:block];
			
		} else {
			NSMutableAttributedString *attrStr = NSMutableAttributedString.new;
			
			for (Line* line in block.lines) { @autoreleasepool {
				NSAttributedString *lineStr;
				
				// Render the element without top margin if it's the first line on page.
				if (firstElementOnPage && line == block.lines.firstObject) {
					lineStr = [self renderLine:line ofBlock:block dualDialogueElement:block.dualDialogueElement firstElementOnPage:true];
				} else {
					lineStr = [self renderLine:line ofBlock:block dualDialogueElement:block.dualDialogueElement firstElementOnPage:false];
				}
				
				[attrStr appendAttributedString:lineStr];
			} }
			
			block.renderedString = attrStr;
		}
	}
	
	return block.renderedString;
}

/// Renders a single line, probably outside of screenplay context
- (NSAttributedString*)renderLine:(Line*)line {
	return [self renderLine:line ofBlock:nil dualDialogueElement:false firstElementOnPage:false];
}

/// Renders a single line
- (NSAttributedString*)renderLine:(Line*)line ofBlock:(BeatPaginationBlock* __nullable)block dualDialogueElement:(bool)dualDialogueElement firstElementOnPage:(bool)firstElementOnPage {
	// Page breaks are just empty lines
	if (line.type == pageBreak) return NSAttributedString.new;
		
	RenderStyle* style = [self styleForType:line.type];
	
	// Get string content and apply transforms if needed
	NSString* string = [NSString stringWithFormat:@"%@\n", line.string]; // Add a line break
	if (style.uppercase) string = string.uppercaseString;
	
	// Create attributed string with attributes for current style
	NSDictionary* attrs = [self attributesForLine:line dualDialogue:(block != nil) ? block.dualDialogueElement : false];
	NSMutableAttributedString *attributedString = [NSMutableAttributedString.alloc initWithString:string attributes:attrs];
	
	// Underlining
	if (style.underline) {
		[attributedString addAttribute:NSUnderlineStyleAttributeName value:@(NSUnderlineStyleSingle) range:NSMakeRange(0, attributedString.length)];
		[attributedString addAttribute:NSUnderlineColorAttributeName value:BXColor.blackColor range:NSMakeRange(0, attributedString.length)];
	}
	
	// Remove top margin for first elements on a page
	if (firstElementOnPage) {
		NSMutableParagraphStyle* pStyle = attrs[NSParagraphStyleAttributeName];
		pStyle = pStyle.mutableCopy;
		pStyle.paragraphSpacingBefore = 0.0;
		[attributedString addAttribute:NSParagraphStyleAttributeName value:pStyle range:NSMakeRange(0, attributedString.length)];
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
	
	// Emoji replacement
	if (line.hasEmojis) {
		for (NSValue* value in line.emojiRanges) {
			NSRange r = value.rangeValue;
			if (r.location == NSNotFound || NSMaxRange(r) > line.length) continue;
			
			[attributedString addAttribute:NSFontAttributeName value:_fonts.emojis range:r];
		}
	}
	
	// Apply revisions.
	if (line.revisedRanges.count) {
		// By default, we'll display revisions defined in export settings,
		// but if no revisions were supplied (the value is nil), let's render all of them.
		NSArray* revisionColors = self.settings.revisions;
		if (revisionColors == nil) revisionColors = BeatRevisions.revisionColors;
		
		for (NSString* color in revisionColors) {
			if (line.revisedRanges[color] == nil) continue;
			
			NSIndexSet* revisions = line.revisedRanges[color];
			[revisions enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {

				if (NSMaxRange(range) > attributedString.length) range.length = attributedString.length - NSMaxRange(range);
				if (range.length <= 0 || range.length > attributedString.length) return;

				[attributedString addAttribute:BeatRevisions.attributeKey value:color range:range];
			}];
		}
	}
	
	// Colors for notes
	if (line.noteRanges.count) {
		[line.noteRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
			RenderStyle* noteStyle = [self.styles forElement:@"note"];
			NSColor* c = [BeatColors color:noteStyle.color];
			[attributedString addAttribute:NSForegroundColorAttributeName value:(c) ? c : NSColor.grayColor range:range];
		}];
	}
	
	// If the block has line breaks in it, we need to remove margin spacing.
	// This *shouldn't* happen, but this is here mostly for backwards-compatibility.
	bool multiline = [line.string containsString:@"\n"];
	if (multiline) {
		
		NSMutableParagraphStyle* topStyle = ((NSMutableParagraphStyle*)attrs[NSParagraphStyleAttributeName]).mutableCopy;
		NSMutableParagraphStyle* bottomStyle = ((NSMutableParagraphStyle*)attrs[NSParagraphStyleAttributeName]).mutableCopy;
		NSMutableParagraphStyle* noSpacingStyle = ((NSMutableParagraphStyle*)attrs[NSParagraphStyleAttributeName]).mutableCopy;
		
		// No bottom spacing for topmost style
		topStyle.paragraphSpacing = 0.0;
		
		// No spacing for lines in the middle
		noSpacingStyle.paragraphSpacingBefore = 0.0;
		noSpacingStyle.paragraphSpacing = 0.0;
		
		// No top spacing for bottom style
		bottomStyle.paragraphSpacingBefore = 0.0;
		
		NSArray<NSString*>* lines = [attributedString.string componentsSeparatedByString:@"\n"];
		if (lines.lastObject.length == 0 && lines.count > 2) lines = [lines subarrayWithRange:NSMakeRange(0, lines.count - 1)];
		
		NSInteger idx = 0;
		for (NSString* l in lines) {
			if (l == lines.firstObject) {
				// Top style for first line
				[attributedString addAttribute:NSParagraphStyleAttributeName value:topStyle range:NSMakeRange(idx, l.length + 1)];
			}
			else if (l == lines.lastObject) {
				// Bottom style for last line
				[attributedString addAttribute:NSParagraphStyleAttributeName value:bottomStyle range:NSMakeRange(idx, l.length)];
			}
			else {
				[attributedString addAttribute:NSParagraphStyleAttributeName value:noSpacingStyle range:NSMakeRange(idx, l.length + 1)];
			}
			
			idx += l.length + 1;
			if (l == lines.lastObject) idx -= 1; // No line break for last item

		}
	}
			
	// Strip invisible stuff
	
	// We might include notes, sections and synopsis lines
	NSMutableIndexSet* includedRanges = NSMutableIndexSet.new;
	if (self.settings.printNotes) {
		[includedRanges addIndexes:line.noteRanges];
	}
	// Let's include markup characters (#, =) in section and synopsis lines.
	if (line.type == section || line.type == synopse) {
		[includedRanges addIndexesInRange:NSMakeRange(0, line.numberOfPrecedingFormattingCharacters)];
	}
	
	// Create actual content ranges
	NSMutableIndexSet* contentRanges = [line contentRangesIncluding:includedRanges].mutableCopy;
	
	[contentRanges addIndex:attributedString.length - 1]; // Add the last index to include our newly-added line break
	NSMutableAttributedString *result = NSMutableAttributedString.new;

	// Enumerate visible ranges and build up the resulting string
	[contentRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		if (range.length == 0) return;
		
		NSAttributedString* content = [attributedString attributedSubstringFromRange:range];
		[result appendAttributedString:content];
	}];
	
	// Add hyperlink for the represented line
	if (!line.isTitlePage && self.settings.operation != ForQuickLook) {
		[result addAttribute:NSLinkAttributeName value:line range:NSMakeRange(0, result.length - 1)];
	}
		
	// For headings, add some extra formatting (wrap them in a table and insert scene numbers)
	if (line.type == heading) {
		result = [self renderHeading:line content:result firstElementOnPage:firstElementOnPage];
	}
	
	return result;
}

/// Adds scene numbers to a heading block
- (NSMutableAttributedString*)renderHeading:(Line*)line content:(NSMutableAttributedString*)content firstElementOnPage:(bool)firstElementOnPage {
	// Get render settings
	bool printSceneNumbers = self.settings.printSceneNumbers;
	CGFloat contentPadding = self.styles.page.contentPadding;
	CGFloat width = [self widthFor:line];
	
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
	[contentCell setContentWidth:width - 5.0 type:NSTextBlockAbsoluteValueType];
	[rightCell setContentWidth:contentPadding - 5.0 type:NSTextBlockAbsoluteValueType];
		
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
	leftStyle.firstLineHeadIndent = 0.0;
	
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

/// Render a block with left/right columns. This block will know the contents of both columns.
- (NSAttributedString*)renderDualDialogueContainer:(BeatPaginationBlock*)dualDialogueBlock {
	// Create table
	CGFloat width = (self.settings.paperSize == BeatA4) ? self.styles.page.defaultWidthA4 : self.styles.page.defaultWidthLetter;
	
	NSTextTable* table = NSTextTable.new;
	[table setContentWidth:width + self.styles.page.contentPadding type:NSTextBlockAbsoluteValueType];
	table.numberOfColumns = 2;
	
	// Create cells
	__block NSTextTableBlock* leftCell = [NSTextTableBlock.alloc initWithTable:table startingRow:0 rowSpan:1 startingColumn:0 columnSpan:1];
	__block NSTextTableBlock* rightCell = [NSTextTableBlock.alloc initWithTable:table startingRow:0 rowSpan:1 startingColumn:1 columnSpan:1];
		
	CGFloat fullWidth = (self.settings.paperSize == BeatA4) ? self.styles.page.defaultWidthA4 : self.styles.page.defaultWidthLetter;
	
	[leftCell setContentWidth:self.styles.page.contentPadding + fullWidth / 2 type:NSTextBlockAbsoluteValueType];
	[rightCell setContentWidth:fullWidth / 2 type:NSTextBlockAbsoluteValueType];
	
	// Render content for left/right cell
	NSMutableAttributedString* leftContent = [self renderBlock:dualDialogueBlock.leftColumnBlock firstElementOnPage:false].mutableCopy;
	NSMutableAttributedString* rightContent = [self renderBlock:dualDialogueBlock.rightColumnBlock firstElementOnPage:false].mutableCopy;
	
	// If there is nothing in the left column, we need to create a placeholder
	if (leftContent.length == 0) {
		NSMutableParagraphStyle* p = NSMutableParagraphStyle.new;
		leftContent = [NSMutableAttributedString.alloc initWithString:@" \n"];
		[leftContent addAttribute:NSParagraphStyleAttributeName value:p range:NSMakeRange(0, leftContent.length)];
	}
	
	// Enumerate the paragraph styles inside left/right column content, and set the cell as their text block
	[leftContent enumerateAttribute:NSParagraphStyleAttributeName inRange:NSMakeRange(0, leftContent.length) options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
		NSMutableParagraphStyle* pStyle = value;
		pStyle = pStyle.mutableCopy;
		
		pStyle.headIndent += self.styles.page.contentPadding;
		pStyle.firstLineHeadIndent += self.styles.page.contentPadding;
		pStyle.textBlocks = @[leftCell];
		
		[leftContent addAttribute:NSParagraphStyleAttributeName value:pStyle range:range];
	}];
	
	[rightContent enumerateAttribute:NSParagraphStyleAttributeName inRange:NSMakeRange(0, rightContent.length) options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
		NSMutableParagraphStyle* pStyle = value;
		pStyle = pStyle.mutableCopy;
		
		pStyle.textBlocks = @[rightCell];
		[rightContent addAttribute:NSParagraphStyleAttributeName value:pStyle range:range];
	}];
	
	// Store the rendered left/right content
	dualDialogueBlock.leftColumn = leftContent.copy;
	dualDialogueBlock.rightColumn = rightContent.copy;
	
	// Create the resulting string
	[leftContent appendAttributedString:rightContent];
	return leftContent;
}

#pragma mark - Page number block

- (NSAttributedString*)pageNumberBlockForPage:(BeatPaginationPage*)page pages:(NSArray<BeatPaginationPage*>*)pages {
	NSInteger index = [pages indexOfObject:page];
	if (index == NSNotFound) index = pages.count;
	
	return [self pageNumberBlockForPageNumber:index + 1];
}

- (NSAttributedString*)pageNumberBlockForPageNumber:(NSInteger)pageNumber {
	// First page does not have a page number
	NSString* pageNumberString = (pageNumber > 1) ? [NSString stringWithFormat:@"%lu.\n", pageNumber] : @" \n";
	
	NSTextTable* table = NSTextTable.new;
	CGFloat width = (self.settings.paperSize == BeatA4) ? self.styles.page.defaultWidthA4 : self.styles.page.defaultWidthLetter;
	width += self.styles.page.contentPadding + self.styles.page.marginLeft;
	[table setContentWidth:width type:NSTextBlockAbsoluteValueType];
	
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
	rightStyle.paragraphSpacing = BeatPagination.lineHeight * 2;
	
	// Left cell is just empty, no additional styles needed
	NSMutableAttributedString* leftContent = [NSMutableAttributedString.alloc initWithString:@" \n" attributes:@{
		NSParagraphStyleAttributeName: leftStyle
	}];
	// Header content (centered at the top of page)
	NSString* header = [NSString stringWithFormat:@"%@\n", (self.settings.header != nil) ? self.settings.header : @""];
	NSMutableAttributedString* headerContent = [NSMutableAttributedString.alloc initWithString:header attributes:@{
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


#pragma mark - Attribute management

- (RenderStyle*)styleForType:(LineType)type {
	return [self.styles forElement:[Line typeName:type]];
}

/// Returns attribute dictionary for given line. We are caching the styles.
- (NSDictionary*)attributesForLine:(Line*)line dualDialogue:(bool)isDualDialogue {
	BeatPaperSize paperSize = self.settings.paperSize;
	LineType type = line.type;
	
	if (isDualDialogue) {
		if (line.type == character) type = dualDialogueCharacter;
		else if (line.type == parenthetical) type = dualDialogueParenthetical;
		else if (line.type == dialogue) type = dualDialogue;
		else if (line.type == more) type = dualDialogueMore;
	}
	
	// A dictionary of styles for current paper size.
	NSNumber* paperSizeKey = @(paperSize);
	if (_lineTypeAttributes[paperSizeKey] == nil) _lineTypeAttributes[paperSizeKey] = NSMutableDictionary.new;
	
	// Dictionary for the actual attributes
	NSNumber* typeKey = @(type);
	
	// We'll create additional, special attributes for some rules.
	// Let's add 100 to the type to create separate keys for split-paragraph rules.
	if (!line.beginsNewParagraph && (type == action || type == lyrics || type == centered)) {
		typeKey = @(type + 100);
	}
	
	if (_lineTypeAttributes[paperSizeKey][typeKey] == nil) {
		RenderStyle *style = [self styleForType:type];
		
		BXColor* textColor = BXColor.blackColor;
		if (style.color.length > 0) {
			BXColor* c = [BeatColors color:style.color];
			if (c != nil) textColor = c;
		}
		
		NSMutableDictionary* styles = [NSMutableDictionary dictionaryWithDictionary:@{
			NSForegroundColorAttributeName: textColor,
		}];
		
		if (style.italic && style.bold) styles[NSFontAttributeName] = self.fonts.boldItalicCourier;
		else if (style.italic) 			styles[NSFontAttributeName] = self.fonts.italicCourier;
		else if (style.bold) 			styles[NSFontAttributeName] = self.fonts.boldCourier;
		else 							styles[NSFontAttributeName] = self.fonts.courier;
		
		CGFloat width 		= (paperSize == BeatA4) ? style.widthA4 : style.widthLetter;
		CGFloat blockWidth 	= width + style.marginLeft + ((paperSize == BeatA4) ? style.marginLeftA4 : style.marginLeftLetter);
		if (!isDualDialogue) blockWidth += self.styles.page.contentPadding;
		
		NSMutableParagraphStyle* pStyle = NSMutableParagraphStyle.new;
		pStyle.headIndent 				= style.marginLeft;
		pStyle.firstLineHeadIndent 		= style.marginLeft;
		
		// Add additional indent for parenthetical lines
		if (line.type == parenthetical) {
			blockWidth += 7.25;
			pStyle.headIndent += 7.25;
		}
		
		pStyle.paragraphSpacingBefore = style.marginTop;
		
		pStyle.paragraphSpacing = style.marginBottom;
		pStyle.tailIndent = -1 * style.marginRight; // Negative value;
		
		pStyle.maximumLineHeight = BeatPagination.lineHeight;
		
		if (!isDualDialogue && !line.isTitlePage) {
			// Add content padding where needed
			pStyle.firstLineHeadIndent 	+= self.styles.page.contentPadding;
			pStyle.headIndent 			+= self.styles.page.contentPadding;
		} else if (!line.isTitlePage) {
			pStyle.firstLineHeadIndent 	= style.marginLeft;
			pStyle.headIndent 			= style.marginLeft;
		}
		
		// Create text block for non-title page elements to restrict horizontal size
		if (!line.isTitlePage) {
			NSTextBlock* textBlock = NSTextBlock.new;
			[textBlock setContentWidth:blockWidth type:NSTextBlockAbsoluteValueType];
			pStyle.textBlocks = @[textBlock];
		}
		
		// Text alignment
		if ([style.textAlign isEqualToString:@"center"]) pStyle.alignment = NSTextAlignmentCenter;
		else if ([style.textAlign isEqualToString:@"right"]) pStyle.alignment = NSTextAlignmentRight;
				
		// Special rules for some blocks
		if ((type == lyrics || type == centered || type == action) && !line.beginsNewParagraph) {
			pStyle.paragraphSpacingBefore = 0;
		}
		
		styles[NSParagraphStyleAttributeName] = pStyle;
		
		// Apply to existing styles
		_lineTypeAttributes[paperSizeKey][typeKey] = [NSDictionary dictionaryWithDictionary:styles];
	}
	
	return _lineTypeAttributes[paperSizeKey][typeKey];
}


#pragma mark - Convenience methods

- (CGFloat)widthFor:(Line*)line {
	RenderStyle* style = [self.styles forElement:line.typeName];
	CGFloat width = (self.settings.paperSize == BeatA4) ? style.widthA4 : style.widthLetter;
	return width;
}

@end
