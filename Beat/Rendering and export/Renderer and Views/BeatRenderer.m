//
//  BeatRenderer.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 19.12.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//
/**
 
 This class renders paginated content to `NSAttributedString` on **macOS**.
 Can be used both stand-alone and as hooked up to `BeatPaginationManager` or `BeatPagination`.
 
 */

#import "BeatRenderer.h"

#import <BeatParsing/BeatParsing.h>
#import <BeatPagination2/BeatPagination2.h>
#import <BeatPagination2/BeatPagination2-Swift.h>
#import <BeatCore/BeatCore.h>

#import "Beat-Swift.h"

@interface BeatRenderer()
//@property (nonatomic) id<BeatPageDelegate> delegate;
@property (nonatomic) BeatStylesheet* styles;
@property (nonatomic, weak) BeatFonts* fonts;
@property (nonatomic) NSMutableDictionary<NSNumber*, NSMutableDictionary<NSNumber*, NSDictionary*>*>* lineTypeAttributes;

@end

@implementation BeatRenderer

- (instancetype)initWithSettings:(BeatExportSettings*)settings  {
	self = [super init];
	if (self) {
		_settings = settings;
		_lineTypeAttributes = NSMutableDictionary.new;
	}
	return self;
}


- (BeatFonts*)fonts
{
	BeatStylesheet* stylesheet = self.settings.styles;
	if (stylesheet) return [BeatFonts forType:stylesheet.page.fontType];
	else return BeatFonts.sharedFonts;
}

- (BeatExportSettings*)settings {
	if (self.pagination != nil) return self.pagination.settings;
	else return _settings;
}

- (void)reloadStyles {
	[self.lineTypeAttributes removeAllObjects];
}

- (BeatStylesheet*)styles {
	if ([self.settings.styles isKindOfClass:BeatStylesheet.class] && self.settings.styles != nil) {
		return self.settings.styles;
	} else {
		return BeatStyles.shared.defaultStyles;
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
		
	RenderStyle* style = [self.styles forLine:line];
	
	// Create attributed string with attributes for current style
	NSDictionary* attrs = [self attributesForLine:line dualDialogue:(block != nil) ? block.dualDialogueElement : false];
	
	NSMutableAttributedString* lineAttrStr = [line attributedStringForOutputWith:self.settings].mutableCopy;
	
	// Apply transforms if needed. This is silly and super inefficient, but what can I say. We *could* do this in layout manager as well, but this is more reliable.
	if (style.uppercase) {
		[lineAttrStr.copy enumerateAttributesInRange:NSMakeRange(0, lineAttrStr.length) options:0 usingBlock:^(NSDictionary<NSAttributedStringKey,id> * _Nonnull attrs, NSRange range, BOOL * _Nonnull stop) {
			[lineAttrStr replaceCharactersInRange:range withAttributedString:[NSAttributedString.alloc initWithString:[lineAttrStr.string.uppercaseString substringWithRange:range] attributes:attrs]];
		}];
	}
	
	NSMutableAttributedString* attributedString = [NSMutableAttributedString.alloc initWithAttributedString:lineAttrStr];
	[attributedString appendAttributedString:[NSAttributedString.alloc initWithString:@"\n"]];
	[attributedString addAttributes:attrs range:NSMakeRange(0, attributedString.length)];
	
	// Underlining
	if (style.underline) {
		[attributedString addAttribute:NSUnderlineStyleAttributeName value:@(NSUnderlineStyleSingle) range:NSMakeRange(0, attributedString.length)];
		[attributedString addAttribute:NSUnderlineColorAttributeName value:BXColor.blackColor range:NSMakeRange(0, attributedString.length)];
	}
	
	// Remove top margin for first elements on a page (if this behavior isn't overridden)
	if (firstElementOnPage && !style.forcedMargin) {
		NSMutableParagraphStyle* pStyle = attrs[NSParagraphStyleAttributeName];
		pStyle = pStyle.mutableCopy;
		pStyle.paragraphSpacingBefore = 0.0;
		[attributedString addAttribute:NSParagraphStyleAttributeName value:pStyle range:NSMakeRange(0, attributedString.length)];
		
		// If this is a SPLIT ELEMENT and rules say so, we'll remove its indentation.
		if (line.unsafeForPageBreak && !style.indentSplitElements) {
			pStyle.headIndent 			-= style.indent;
			pStyle.firstLineHeadIndent 	-= style.firstLineIndent;
		}
	}
	
	[attributedString.copy enumerateAttributesInRange:NSMakeRange(0,attributedString.length) options:0 usingBlock:^(NSDictionary<NSAttributedStringKey,id> * _Nonnull attrs, NSRange range, BOOL * _Nonnull stop) {
		if (attrs[@"Style"]) {
			NSSet* styleNames = attrs[@"Style"];
			if (styleNames.count == 0) return;
			
			NSFontTraitMask traits = 0;
			
			if ([styleNames containsObject:@"Bold"]) traits |= NSBoldFontMask;
			if ([styleNames containsObject:@"Italic"]) traits |= NSItalicFontMask;
			[attributedString applyFontTraits:traits range:range];
			
			// Apply underline if needed
			if ([styleNames containsObject:@"Underline"]) {
				[attributedString addAttribute:NSUnderlineStyleAttributeName value:@(1) range:range];
				[attributedString addAttribute:NSUnderlineColorAttributeName value:BXColor.blackColor range:range];
			}
			if ([styleNames containsObject:@"Note"]) {
				RenderStyle* noteStyle = [self.styles forElement:@"note"];
				NSColor* c = [BeatColors color:noteStyle.color];
				[attributedString addAttribute:NSForegroundColorAttributeName value:(c) ? c : BXColor.grayColor range:range];
			}
		}
		
		if (attrs[BeatRevisions.attributeKey]) {
			NSString* color = attrs[BeatRevisions.attributeKey];
			if (color != nil) [attributedString addAttribute:BeatRevisions.attributeKey value:color range:range];
		}
		
	}];
	
	// Add hyperlink for the represented line
	if (!line.isTitlePage && self.settings.operation != ForQuickLook) {
		[attributedString addAttribute:NSLinkAttributeName value:line range:NSMakeRange(0, attributedString.length - 1)];
	}
	
	// And after all this, if the style has a content rule, we'll replace the text while keeping the original attributes
	if (style.content != nil) {
		NSString* content = [NSString stringWithFormat:@"%@\n", style.content];
		NSDictionary* attrs = [attributedString attributesAtIndex:0 effectiveRange:nil];
		[attributedString replaceCharactersInRange:NSMakeRange(0, attributedString.length) withAttributedString:[NSAttributedString.alloc initWithString:content attributes:attrs]];
	}
	
	// For headings, add some extra formatting (wrap them in a table and insert scene numbers)
	if (line.type == heading && style.sceneNumber) {
		attributedString = [self renderHeading:line content:attributedString firstElementOnPage:firstElementOnPage];
	}
	
	return attributedString;
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

- (NSAttributedString*)pageNumberBlockForPage:(BeatPaginationPage*)page pages:(NSArray<BeatPaginationPage*>*)pages
{
	NSInteger index = [pages indexOfObject:page];
	if (index == NSNotFound) index = pages.count;
	
	return [self pageNumberBlockForPageNumber:index + 1];
}

- (NSAttributedString*)pageNumberBlockForPageNumber:(NSInteger)pageNumber {
	// We might skip first page number (in screenplay mode)
	NSString* pageNumberString = (pageNumber >= self.styles.page.firstPageWithNumber) ? [NSString stringWithFormat:@"%lu.\n", pageNumber] : @" \n";
	
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
	headerStyle.maximumLineHeight = self.styles.page.lineHeight;
	
	NSMutableParagraphStyle* rightStyle = NSMutableParagraphStyle.new;
	rightStyle.textBlocks = @[rightCell];
	rightStyle.alignment = NSTextAlignmentRight;
	rightStyle.maximumLineHeight = BeatPagination.lineHeight; // We'll use standard line heights here
	rightStyle.paragraphSpacing = BeatPagination.lineHeight * 2;
	
	// Left cell is just empty, no additional styles needed
	NSMutableAttributedString* leftContent = [NSMutableAttributedString.alloc initWithString:@" \n" attributes:@{
		NSParagraphStyleAttributeName: leftStyle
	}];
	// Header content (centered at the top of page)
	NSString* header = [NSString stringWithFormat:@"%@\n", (self.settings.header != nil) ? self.settings.header : @""];
	NSMutableAttributedString* headerContent = [NSMutableAttributedString.alloc initWithString:header attributes:@{
		NSParagraphStyleAttributeName: headerStyle,
		NSFontAttributeName: self.fonts.regular,
		NSForegroundColorAttributeName: NSColor.blackColor
	}];
	// Actual page number goes in right corner
	NSMutableAttributedString* rightContent = [NSMutableAttributedString.alloc initWithString:pageNumberString attributes:@{
		NSParagraphStyleAttributeName: rightStyle,
		NSFontAttributeName: self.fonts.regular,
		NSForegroundColorAttributeName: NSColor.blackColor
	}];
	
	NSMutableAttributedString* pageNumberBlock = NSMutableAttributedString.new;
	[pageNumberBlock appendAttributedString:leftContent];
	[pageNumberBlock appendAttributedString:headerContent];
	[pageNumberBlock appendAttributedString:rightContent];
	
	return pageNumberBlock;
}



#pragma mark - Attribute management

- (NSFont*)fontWith:(RenderStyle*)style
{
	NSFont* font;
	
	if (style.font.length == 0) {
		// Plain fonts
		if (style.italic && style.bold) font = self.fonts.boldItalic;
		else if (style.italic) 			font = self.fonts.italic;
		else if (style.bold) 			font = self.fonts.bold;
		else 							font = self.fonts.regular;
	} else {
		// Specific fonts for some situations
		if ([style.font isEqualToString:@"system"]) {
			// System font
			BXFontDescriptorSymbolicTraits traits = 0;
			if (style.italic) traits |= BXFontDescriptorTraitItalic;
			if (style.bold) traits |= BXFontDescriptorTraitBold;
			
			CGFloat size = (style.fontSize > 0) ? style.fontSize : 11.0;
			font = [BeatFonts fontWithTrait:traits font:[BXFont systemFontOfSize:size]];
		} else {
			// Custom font
			font = [BXFont fontWithName:style.font size:self.fonts.regular.pointSize];
		}
	}
	
	// Non-default font size
	if (style.fontSize > 0) {
		font = [NSFont fontWithName:font.fontName size:style.fontSize];
	}
	
	return font;
}

/// Returns attribute dictionary for given line. We are caching the styles.
- (NSDictionary*)attributesForLine:(Line*)line dualDialogue:(bool)isDualDialogue {
	@synchronized (self.lineTypeAttributes) {
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
		if ([line.string rangeOfString:@"If I am so scared"].location != NSNotFound) {
			NSLog(@" ");
		}
		
		// TODO: We need to define *how* lines are unsafe for page break for the indents to work correctly.
		if (!line.beginsNewParagraph && (type == action || type == lyrics || type == centered) && !line.isTitlePage) {
			typeKey = @(type + 100);
		} else if (!line.paragraphIn && line.beginsNewParagraph && [self.styles forLine:line].unindentFreshParagraphs) {
			typeKey = @(type + 200);
		}
		
		if (line.isTitlePage) {
			// Some extra weirdness for title pages
			bool defaultParagraphType = (line.beginsTitlePageBlock + line.endsTitlePageBlock == 2);
			
			// If it's not a normal, one-line title page element, we'll need to define an additional type
			if (!defaultParagraphType) {
				NSInteger titlePageType = type + 2 * line.beginsTitlePageBlock + line.endsTitlePageBlock + 1000 + type * 100;
				typeKey = @(titlePageType);
			}
		}
				
		if (_lineTypeAttributes[paperSizeKey][typeKey] == nil) {
			RenderStyle *style = [self.styles forLine:line];
			
			NSFont* font = [self fontWith:style];
			
			// Get text color
			BXColor* textColor = BXColor.blackColor;
			if (style.color.length > 0) {
				BXColor* c = [BeatColors color:style.color];
				if (c != nil) textColor = c;
			}
			
			NSMutableDictionary* styles = [NSMutableDictionary dictionaryWithDictionary:@{
				NSForegroundColorAttributeName: textColor,
				NSFontAttributeName: (font != nil) ? font : self.fonts.regular
			}];
			
			// Block sizing
			CGFloat width = [style widthWithPageSize:paperSize];
			if (width == 0.0) width = [self.styles.page defaultWidthWithPageSize:paperSize];
			
			CGFloat blockWidth 	= width + style.marginLeft + ((paperSize == BeatA4) ? style.marginLeftA4 : style.marginLeftLetter);
			if (!isDualDialogue) blockWidth += self.styles.page.contentPadding;
						
			// Paragraph style
			NSMutableParagraphStyle* pStyle = NSMutableParagraphStyle.new;
			pStyle.headIndent 				= style.marginLeft + style.indent;
			pStyle.firstLineHeadIndent 		= style.marginLeft + style.firstLineIndent;
			
			// Check for additional rules
			if (style.unindentFreshParagraphs && line.beginsNewParagraph && !line.paragraphIn) {
				pStyle.firstLineHeadIndent -= style.firstLineIndent;
			}
			
			// Add additional indent for parenthetical lines
			if (line.type == parenthetical) {
				blockWidth += 7.25;
				pStyle.headIndent += 7.25;
			}
						
			pStyle.paragraphSpacingBefore = style.marginTop;
			
			pStyle.paragraphSpacing = style.marginBottom;
			pStyle.tailIndent = -1 * style.marginRight; // Negative value;
			
			pStyle.maximumLineHeight = self.styles.page.lineHeight;
			pStyle.minimumLineHeight = self.styles.page.lineHeight;
			
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
			
			// Title page rules
			if (line.isTitlePage) {
				if (line.beginsTitlePageBlock && !line.endsTitlePageBlock) pStyle.paragraphSpacing = 0.0;
				if (!line.beginsTitlePageBlock) pStyle.paragraphSpacingBefore = 0.0;
				if (!line.endsTitlePageBlock) pStyle.paragraphSpacing = 0.0;
			}
			
			// Apply paragraph style
			styles[NSParagraphStyleAttributeName] = pStyle;
			
			// We can't store conditional styles, so let's not store this one.
			if (style.dynamicStyle) {
				return [NSDictionary dictionaryWithDictionary:styles];
			}
			
			// Apply to existing styles
			_lineTypeAttributes[paperSizeKey][typeKey] = [NSDictionary dictionaryWithDictionary:styles];
		}
		
		return _lineTypeAttributes[paperSizeKey][typeKey];
	}
}


#pragma mark - Convenience methods

- (CGFloat)widthFor:(Line*)line {
	RenderStyle* style = [self.styles forLine:line];
	CGFloat width = [style widthWithPageSize:self.settings.paperSize];
	if (width == 0.0) width = [self.styles.page defaultWidthWithPageSize:self.settings.paperSize];
		
	return width;
}

@end
