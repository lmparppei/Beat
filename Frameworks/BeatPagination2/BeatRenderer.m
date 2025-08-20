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
#import <BeatPagination2/BeatPagination.h>
#import <BeatPagination2/BeatPagination2-Swift.h>
#import <NaturalLanguage/NaturalLanguage.h>

//#import "Beat-Swift.h"

@interface BeatRenderer()
//@property (nonatomic) id<BeatPageDelegate> delegate;
@property (nonatomic) BeatStylesheet* styles;
//@property (nonatomic, weak) BeatFonts* fonts;
@property (nonatomic, weak) BeatFontSet* fonts;
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


- (BeatFontSet*)fonts
{
    BeatStylesheet* stylesheet = self.settings.styles;
    BeatFontSet* fonts = (stylesheet) ? [BeatFontManager.shared fontsFor:stylesheet.page.fontType] : BeatFontManager.shared.defaultFonts;
    return fonts;
}

- (BeatExportSettings*)settings
{
    if (self.pagination != nil) return ((BeatPaginationManager*)self.pagination).settings;
    else return _settings;
}

- (void)reloadStyles
{
    [self.lineTypeAttributes removeAllObjects];
}

- (BeatStylesheet*)styles {
    BeatStylesheet* sheet = nil;
    if ([self.settings.styles isKindOfClass:BeatStylesheet.class] && self.settings.styles != nil) {
        sheet = self.settings.styles;
    } else {
        sheet = BeatStyles.shared.defaultStyles;
    }
    
    return sheet;
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
            // Render dual dialogue block
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
                
                // Do a sweep for emojis
                if (lineStr.string.emo_containsEmoji) {
                    lineStr = [self emojiFontsFor:lineStr];
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
- (NSAttributedString*)renderLine:(Line*)line ofBlock:(BeatPaginationBlock* __nullable)block dualDialogueElement:(bool)dualDialogueElement firstElementOnPage:(bool)firstElementOnPage
{
    // Some elements won't be rendered
    if (line.type == pageBreak || line == nil) {
        return NSAttributedString.new;
    }
    
    // We might need to flip the type for lonely dual dialogue.
    if (line.isDualDialogue && !dualDialogueElement) {
        if (line.type == dualDialogueCharacter) line.type = character;
        if (line.type == dualDialogueParenthetical) line.type = parenthetical;
        if (line.type == dualDialogue) line.type = dialogue;
    }
    
    RenderStyle* style = [self.styles forLine:line];
        
    // Create attributed string with attributes for current style
    NSDictionary* attrs = [self attributesForLine:line dualDialogue:(block != nil) ? block.dualDialogueElement : false];
    
    // Support for empty character cues
    if (line.isAnyCharacter && line.stripFormatting.length == 0 && line.numberOfPrecedingFormattingCharacters == 1) {
        return [self emptyCharacterCueWith:attrs];
    }
    
    NSMutableAttributedString* lineAttrStr = [line attributedStringForOutputWith:self.settings].mutableCopy;
    
    // Apply transforms if needed. This is silly and super inefficient, but what can I say. We *could* do this in layout manager as well, but this is more reliable.
    if (style.uppercase) {
        [lineAttrStr.copy enumerateAttributesInRange:NSMakeRange(0, lineAttrStr.length) options:0 usingBlock:^(NSDictionary<NSAttributedStringKey,id> * _Nonnull attrs, NSRange range, BOOL * _Nonnull stop) {
            [lineAttrStr replaceCharactersInRange:range withAttributedString:[NSAttributedString.alloc initWithString:[lineAttrStr.string.uppercaseString substringWithRange:range] attributes:attrs]];
        }];
    }
    
    NSMutableAttributedString* attributedString = [NSMutableAttributedString.alloc initWithAttributedString:lineAttrStr];
    [attributedString appendString:@"\n"];
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
        if (line.unsafeForPageBreak && !style.indentSplitElements && line.paragraphIn) {
            pStyle.headIndent             -= style.indent;
            pStyle.firstLineHeadIndent     -= style.firstLineIndent;
        }
    }
    
    [attributedString.copy enumerateAttributesInRange:NSMakeRange(0,attributedString.length) options:0 usingBlock:^(NSDictionary<NSAttributedStringKey,id> * _Nonnull attrs, NSRange range, BOOL * _Nonnull stop) {
        if (attrs[@"Style"]) {
            NSSet* styleNames = attrs[@"Style"];
            if (styleNames.count == 0) return;

            // Apply inline formatting. Note that attributdString is an inout argument.
            [self applyInlineFormattingWithStyleNames:styleNames range:range attributedString:attributedString];
            
            if ([styleNames containsObject:@"Note"]) {
                RenderStyle* noteStyle = [self.styles forElement:@"note"];
                BXColor* c = [BeatColors color:noteStyle.color];
                [attributedString addAttribute:NSForegroundColorAttributeName value:(c) ? c : BXColor.grayColor range:range];
            }
            
            // Apply underline if needed
            if ([styleNames containsObject:@"Underline"]) {
                [attributedString addAttribute:NSUnderlineStyleAttributeName value:@(1) range:range];
                [attributedString addAttribute:NSUnderlineColorAttributeName value:BXColor.blackColor range:range];
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
        
    // Trim the line if needed
    if (style.trim) {
        attributedString = [attributedString trimWhiteSpaceWithIncludeLineBreaks:false].mutableCopy;
    }
    
    // And after all this, if the style has a content rule, we'll replace the text while keeping the original attributes
    if (style.content != nil) {
        NSString* content = [NSString stringWithFormat:@"%@\n", style.content];
        NSDictionary* attrs = [attributedString attributesAtIndex:0 effectiveRange:nil];
        [attributedString replaceCharactersInRange:NSMakeRange(0, attributedString.length) withAttributedString:[NSAttributedString.alloc initWithString:content attributes:attrs]];
    }
    
    // For headings, add some extra formatting (wrap them in a table and insert scene numbers)
    if (line.type == heading && style.sceneNumber && !self.settings.simpleSceneHeadings) {
        attributedString = [self renderHeading:line content:attributedString firstElementOnPage:firstElementOnPage];
        // This is an experimental feature to support PDF outlines
        [attributedString addAttribute:@"HEADING" value:[NSString stringWithFormat:@"%@ %@", line.sceneNumber, line.stringForDisplay.uppercaseString] range:NSMakeRange(0, attributedString.length)];
    }
    
    return attributedString;
}

- (void)applyInlineFormattingWithStyleNames:(NSSet*)styleNames range:(NSRange)range attributedString:(inout NSMutableAttributedString*)attributedString
{
    if (styleNames.count == 0) return;
    
#if TARGET_OS_OSX
    NSFontTraitMask traits = 0;
    
    if ([styleNames containsObject:@"Bold"]) traits |= NSBoldFontMask;
    if ([styleNames containsObject:@"Italic"]) traits |= NSItalicFontMask;
    [attributedString applyFontTraits:traits range:range];
#else
    UIFontDescriptorSymbolicTraits traits = 0;
    if ([styleNames containsObject:@"Bold"]) traits |= UIFontDescriptorTraitBold;
    if ([styleNames containsObject:@"Italic"]) traits |= UIFontDescriptorTraitItalic;

    if (traits != 0) {
        UIFont* font = [attributedString attribute:NSFontAttributeName atIndex:range.location effectiveRange:nil];
        if (font == nil) font = self.fonts.regular;
    
        UIFont* stylizedFont = [BeatFontSet fontWithTrait:traits font:font];
        if (stylizedFont) [attributedString addAttribute:NSFontAttributeName value:stylizedFont range:range];
    }
#endif
}

#if TARGET_OS_OSX
/// Adds scene numbers to a heading block
- (NSMutableAttributedString*)renderHeading:(Line*)line content:(NSMutableAttributedString*)content firstElementOnPage:(bool)firstElementOnPage
{
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
#else
- (NSMutableAttributedString*)renderHeading:(Line*)line content:(NSMutableAttributedString*)content firstElementOnPage:(bool)firstElementOnPage
{
    // Get render settings
    bool printSceneNumbers = self.settings.printSceneNumbers;

    CGFloat contentPadding = self.styles.page.contentPadding;
    CGFloat width = [self widthFor:line];

    // Inherit font
    BXFont* font = [content attribute:NSFontAttributeName atIndex:0 effectiveRange:nil];
    
    // Create a table with three cells:
    // [scene number] [INT. SCENE HEADING] [scene number]

    // Stylize the actual heading part. Make a copy of the style just in case.
    NSMutableParagraphStyle* contentStyle = [content attribute:NSParagraphStyleAttributeName atIndex:0 effectiveRange:nil];
    contentStyle = contentStyle.mutableCopy;
        
    // Set margins and indents to zero (as we're inside a cell)
    contentStyle.headIndent = 0;
    contentStyle.firstLineHeadIndent = 0;
    if (firstElementOnPage) contentStyle.paragraphSpacingBefore = 0.0;
    
    // Replace paragraph attributes in the content style
    [content addAttribute:NSParagraphStyleAttributeName value:contentStyle range:NSMakeRange(0, content.length)];
    
    NSMutableParagraphStyle* leftStyle = contentStyle.mutableCopy;
    leftStyle.paragraphSpacingBefore = 0.0;
    leftStyle.paragraphSpacing = 0.0;
    leftStyle.firstLineHeadIndent = 0.0;
    
    NSMutableParagraphStyle* rightStyle = leftStyle.mutableCopy;
    rightStyle.alignment = NSTextAlignmentRight;
    
    // Create scene number string
    NSString* sceneNumber = (printSceneNumbers) ? line.sceneNumber : @"";
    
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
        
    BeatTextTableCell* left = [BeatTextTableCell.alloc initWithContent:sceneNumberLeft width:contentPadding];
    BeatTextTableCell* center = [BeatTextTableCell.alloc initWithContent:content width:width - 5.0];
    BeatTextTableCell* right = [BeatTextTableCell.alloc initWithContent:sceneNumberRight width:contentPadding];
    
    BeatTableAttachment* attachment = [BeatTableAttachment.alloc initWithCells:@[left, center, right] spacing:0.0 margin:0.0];
    
    NSMutableAttributedString* tableString = [NSAttributedString attributedStringWithAttachment:attachment].mutableCopy;
    [tableString appendString:@"\n"];
    
    // Restore margin
    [tableString addAttribute:NSParagraphStyleAttributeName value:contentStyle range:NSMakeRange(0, tableString.length)];
    
    return tableString;
}
#endif

/// Returns an empty character cue with zero height.
/// - note This is a total hack, and might not work in the future. 
- (NSAttributedString * _Nonnull)emptyCharacterCueWith:(NSDictionary *)attrs
{
    NSMutableDictionary* a = attrs.mutableCopy;
    NSMutableParagraphStyle* s = ((NSParagraphStyle*)a[NSParagraphStyleAttributeName]).mutableCopy;
    s.lineHeightMultiple = 0.0; s.maximumLineHeight = 0.0; s.minimumLineHeight = 0.0; s.lineSpacing = 0.0;
    
    a[NSParagraphStyleAttributeName] = s;
    a[NSFontAttributeName] = [BXFont systemFontOfSize:0.00000000001];
    
    return [NSAttributedString.alloc initWithString:@"\n" attributes:a];
}

#if TARGET_OS_OSX
/// Render a block with left/right columns. This block will know the contents of both columns.
/// @note: macOS version uses `NSTextTable` which is available only in TextKit1 on macOS
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
#else
/// Render a block with left/right columns. This block will know the contents of both columns.
/// @warning: This iOS version requires TextKit 2, and won't work in TextKit 1
- (NSAttributedString*)renderDualDialogueContainer:(BeatPaginationBlock*)dualDialogueBlock {
    CGFloat width = (self.settings.paperSize == BeatA4) ? self.styles.page.defaultWidthA4 : self.styles.page.defaultWidthLetter;
    CGFloat cellWidth = width / 2;
    
    NSMutableAttributedString* leftContent = [self renderBlock:dualDialogueBlock.leftColumnBlock firstElementOnPage:false].mutableCopy;
    NSMutableAttributedString* rightContent = [self renderBlock:dualDialogueBlock.rightColumnBlock firstElementOnPage:false].mutableCopy;
    
    if (leftContent.length == 0) {
        leftContent = [NSMutableAttributedString.alloc initWithString:@" \n"];
        [leftContent addAttribute:NSParagraphStyleAttributeName value:NSMutableParagraphStyle.new range:NSMakeRange(0, leftContent.length)];
    }
    if (rightContent.length == 0) {
        rightContent = [NSMutableAttributedString.alloc initWithString:@" \n"];
        [rightContent addAttribute:NSParagraphStyleAttributeName value:NSMutableParagraphStyle.new range:NSMakeRange(0, rightContent.length)];
    }
    
    BeatTextTableCell* leftCell = [BeatTextTableCell.alloc initWithContent:leftContent width:cellWidth];
    BeatTextTableCell* rightCell = [BeatTextTableCell.alloc initWithContent:rightContent width:cellWidth];
    BeatTableAttachment* attachment = [BeatTableAttachment.alloc initWithCells:@[leftCell, rightCell] spacing:0.0 margin:0.0];
    
    NSMutableAttributedString* attrStr = [NSMutableAttributedString attributedStringWithAttachment:attachment].mutableCopy;
    [attrStr appendAttributedString:[NSAttributedString.alloc initWithString:@"\n"]];
    
    NSParagraphStyle* pStyle = [leftContent attribute:NSParagraphStyleAttributeName atIndex:0 effectiveRange:nil];
    if (pStyle != nil) [attrStr addAttribute:NSParagraphStyleAttributeName value:pStyle range:NSMakeRange(0, attrStr.length)];
    
    return attrStr;
}
#endif

#pragma mark - Page number block

#if TARGET_OS_OSX
- (NSAttributedString*)pageNumberBlockForPage:(BeatPaginationPage*)page
{
    NSInteger pageNumber = page.pageNumber;
    NSString* pageNumberString;
    
    // We might skip first page number (in screenplay mode)
    if (pageNumber < self.styles.page.firstPageWithNumber && page.customPageNumber == nil) {
        pageNumberString = @"\n";
    } else {
        pageNumberString = (page.customPageNumber == nil) ? [NSString stringWithFormat:@"%lu.\n", pageNumber] : [NSString stringWithFormat:@"%@\n", page.customPageNumber];
    }
    
    // We'll use A4 size for both page sizes
    CGFloat width = self.styles.page.defaultWidthA4 - 10.0;
    width += self.styles.page.contentPadding + self.styles.page.marginLeft;
    
    NSTextTable* table = NSTextTable.new;
    [table setContentWidth:width type:NSTextBlockAbsoluteValueType];
    
    NSTextTableBlock* leftCell = [NSTextTableBlock.alloc initWithTable:table startingRow:0 rowSpan:1 startingColumn:0 columnSpan:1];
    NSTextTableBlock* headerCell = [NSTextTableBlock.alloc initWithTable:table startingRow:0 rowSpan:1 startingColumn:1 columnSpan:1];
    NSTextTableBlock* rightCell = [NSTextTableBlock.alloc initWithTable:table startingRow:0 rowSpan:1 startingColumn:2 columnSpan:1];
    
    [leftCell setContentWidth:15 type:NSTextBlockPercentageValueType];
    [headerCell setContentWidth:70 type:NSTextBlockPercentageValueType];
    [rightCell setContentWidth:15 type:NSTextBlockPercentageValueType];
    
    NSMutableParagraphStyle* leftStyle = NSMutableParagraphStyle.new;
    leftStyle.textBlocks = @[leftCell];
    leftStyle.maximumLineHeight = BeatPagination.lineHeight;
    leftStyle.alignment = NSTextAlignmentLeft;
    
    NSMutableParagraphStyle* headerStyle = NSMutableParagraphStyle.new;
    headerStyle.textBlocks = @[headerCell];
    headerStyle.maximumLineHeight = BeatPagination.lineHeight;
    headerStyle.alignment = NSTextAlignmentCenter;
    
    NSMutableParagraphStyle* rightStyle = NSMutableParagraphStyle.new;
    rightStyle.textBlocks = @[rightCell];
    rightStyle.alignment = NSTextAlignmentRight;
    rightStyle.maximumLineHeight = BeatPagination.lineHeight; // We'll use standard line heights here
    rightStyle.paragraphSpacing = BeatPagination.lineHeight * 2;
    
    NSMutableAttributedString* leftContent;
    NSMutableAttributedString* headerContent;
    NSMutableAttributedString* rightContent;
    
    if (self.settings.headerAlignment == BeatHeaderAlignmentCenter) {
        // Left cell is just empty, no additional styles needed
        leftContent = [NSMutableAttributedString.alloc initWithString:@" \n" attributes:@{
            NSParagraphStyleAttributeName: leftStyle
        }];
        // Header content (centered at the top of page)
        NSString* header = [NSString stringWithFormat:@"%@\n", (self.settings.header != nil) ? self.settings.header : @""];
        headerContent = [NSMutableAttributedString.alloc initWithString:header attributes:@{
            NSParagraphStyleAttributeName: headerStyle,
            NSFontAttributeName: self.fonts.regular,
            NSForegroundColorAttributeName: NSColor.blackColor
        }];
        // Actual page number goes in right corner
        rightContent = [NSMutableAttributedString.alloc initWithString:pageNumberString attributes:@{
            NSParagraphStyleAttributeName: rightStyle,
            NSFontAttributeName: self.fonts.regular,
            NSForegroundColorAttributeName: NSColor.blackColor
        }];
    } else if (self.settings.headerAlignment == BeatHeaderAlignmentRight) {
        // Right content is enough here
        [rightCell setContentWidth:100.0 type:NSTextBlockPercentageValueType];
        [headerCell setContentWidth:0.0 type:NSTextBlockPercentageValueType];
        [leftCell setContentWidth:0.0 type:NSTextBlockPercentageValueType];
        
        NSString* header = (self.settings.header) ? [NSString stringWithFormat:@"%@", self.settings.header] : @"";
        if (pageNumber >= self.styles.page.firstPageWithNumber && header.length > 0) header = [header stringByAppendingString:@" -"];
        
        NSString* fullString = [NSString stringWithFormat:@"%@  %@", header, pageNumberString];
        rightContent = [NSMutableAttributedString.alloc initWithString:fullString attributes:@{
            NSParagraphStyleAttributeName: rightStyle,
            NSFontAttributeName: self.fonts.regular,
            NSForegroundColorAttributeName: NSColor.blackColor
        }];
    } else {
        // Adjust left side to be full width
        [leftCell setContentWidth:85 type:NSTextBlockPercentageValueType];
        [headerCell setContentWidth:0.0 type:NSTextBlockPercentageValueType];
        NSString* header = (self.settings.header) ? [NSString stringWithFormat:@"%@\n", self.settings.header] : @"";
        
        leftContent = [NSMutableAttributedString.alloc initWithString:header attributes:@{
            NSParagraphStyleAttributeName: leftStyle,
            NSFontAttributeName: self.fonts.regular,
            NSForegroundColorAttributeName: NSColor.blackColor
        }];
        
        // Actual page number goes in right corner
        rightContent = [NSMutableAttributedString.alloc initWithString:pageNumberString attributes:@{
            NSParagraphStyleAttributeName: rightStyle,
            NSFontAttributeName: self.fonts.regular,
            NSForegroundColorAttributeName: NSColor.blackColor
        }];
    }
    
    NSMutableAttributedString* pageNumberBlock = NSMutableAttributedString.new;
    if (leftContent != nil) [pageNumberBlock appendAttributedString:leftContent];
    if (headerContent != nil) [pageNumberBlock appendAttributedString:headerContent];
    if (rightContent != nil) [pageNumberBlock appendAttributedString:rightContent];
    
    return pageNumberBlock;
}
#else
- (NSAttributedString*)pageNumberBlockForPage:(BeatPaginationPage*)page
{
    NSInteger pageNumber = page.pageNumber;
    NSString* pageNumberString = (pageNumber >= self.styles.page.firstPageWithNumber) ? [NSString stringWithFormat:@"%lu.", pageNumber] : @"";
    
    // We'll use A4 size for both page sizes
    CGFloat width = self.styles.page.defaultWidthA4 - 10.0;
    width += self.styles.page.contentPadding + self.styles.page.marginLeft;
    
    CGFloat headerWidth = width * 0.7;
    CGFloat leftCellWidth = width * 0.15;
    CGFloat rightCellWidth = width * 0.15;
    
    NSMutableParagraphStyle* rightStyle = NSMutableParagraphStyle.new;
    rightStyle.alignment = NSTextAlignmentRight;
    rightStyle.maximumLineHeight = BeatPagination.lineHeight;
    
    NSMutableParagraphStyle* headerStyle = NSMutableParagraphStyle.new;
    headerStyle.alignment = NSTextAlignmentCenter;
    headerStyle.maximumLineHeight = BeatPagination.lineHeight;
    
    // Adjust sizing and positioning
    if (self.settings.headerAlignment == BeatHeaderAlignmentLeft) {
        headerStyle.alignment = NSTextAlignmentLeft;
        headerWidth += leftCellWidth;
        leftCellWidth = 0.0;
    } else if (self.settings.headerAlignment == BeatHeaderAlignmentRight) {
        rightCellWidth += headerWidth;
        headerWidth = 0.0;
    }

    NSString* headerText = (self.settings.header != nil) ? self.settings.header : @"";
    NSMutableAttributedString* headerContent = [NSMutableAttributedString.alloc initWithString:(self.settings.headerAlignment != BeatHeaderAlignmentRight) ? headerText : @"" attributes:@{
        NSParagraphStyleAttributeName: headerStyle,
        NSFontAttributeName: self.fonts.regular,
        NSForegroundColorAttributeName: BXColor.blackColor
    }];
    
    // Actual page number goes in right corner
    if (self.settings.headerAlignment == BeatHeaderAlignmentRight) pageNumberString = [headerText stringByAppendingFormat:@"  %@", pageNumberString];
    NSMutableAttributedString* rightContent = [NSMutableAttributedString.alloc initWithString:pageNumberString attributes:@{
        NSParagraphStyleAttributeName: rightStyle,
        NSFontAttributeName: self.fonts.regular,
        NSForegroundColorAttributeName: BXColor.blackColor
    }];
    
    BeatTextTableCell* left = [BeatTextTableCell.alloc initWithContent:NSAttributedString.new width:leftCellWidth];
    BeatTextTableCell* header = [BeatTextTableCell.alloc initWithContent:headerContent width:headerWidth];
    BeatTextTableCell* right = [BeatTextTableCell.alloc initWithContent:rightContent width:rightCellWidth];
    
    BeatTableAttachment* attachment = [BeatTableAttachment.alloc initWithCells:@[left, header, right] spacing:0.0 margin:0.0];
    
    NSMutableAttributedString* tableString = [NSAttributedString attributedStringWithAttachment:attachment].mutableCopy;
    [tableString appendString:@"\n"];
    
    // Restore margin
    NSMutableParagraphStyle* blockStyle = NSMutableParagraphStyle.new;
    blockStyle.paragraphSpacing = BeatPagination.lineHeight * 2;
    
    [tableString addAttribute:NSParagraphStyleAttributeName value:blockStyle range:NSMakeRange(0, tableString.length)];
    
    return tableString;
}

#endif



#pragma mark - Attribute management

- (BXFont*)fontWith:(RenderStyle*)style
{
    BXFont* font;
    CGFloat fontSize = (style.fontSize > 0) ? style.fontSize : 12.0;
    
    if (style.font.length == 0 || [style.font isEqualToString:@"default"]) {
        // Plain fonts
        if (style.italic && style.bold) font = self.fonts.boldItalic;
        else if (style.italic)          font = self.fonts.italic;
        else if (style.bold)            font = self.fonts.bold;
        else                            font = self.fonts.regular;
        
        if (fontSize != 12.0) {
            if (@available(macOS 10.15, *)) font = [font fontWithSize:style.fontSize];
            else font = [BXFont fontWithName:font.fontName size:style.fontSize];
        }
        
    } else {
        // Specific fonts for some situations
        if ([style.font isEqualToString:@"system"]) {
            // System font
            BXFontDescriptorSymbolicTraits traits = 0;
            if (style.italic) traits |= BXFontDescriptorTraitItalic;
            if (style.bold) traits |= BXFontDescriptorTraitBold;
            
            fontSize = (style.fontSize > 0) ? style.fontSize : 11.0;
            font = [BeatFontSet fontWithTrait:traits font:[BXFont systemFontOfSize:fontSize]];
        } else {
            // Custom font
            font = [BXFont fontWithName:style.font size:fontSize];
        }
    }
    
    return font;
}

/// Returns attribute dictionary for given line. We are caching the styles.
- (NSDictionary*)attributesForLine:(Line*)line dualDialogue:(bool)isDualDialogue
{
    if (line == nil) return @{};
    
    @synchronized (self.lineTypeAttributes) {
        BeatPaperSize paperSize = self.settings.paperSize;
        LineType type = line.type;
        bool forcedType = false;
        bool rightToLeft = line.string.hasRightToLeftText;
        
        if (isDualDialogue) {
            if (line.type == character) type = dualDialogueCharacter;
            else if (line.type == parenthetical) type = dualDialogueParenthetical;
            else if (line.type == dialogue) type = dualDialogue;
            else if (line.type == more) type = dualDialogueMore;

            forcedType = true;
        }
        
        // A dictionary of styles for current paper size.
        NSNumber* paperSizeKey = @(paperSize);
        if (_lineTypeAttributes[paperSizeKey] == nil) _lineTypeAttributes[paperSizeKey] = NSMutableDictionary.new;
        
        // Dictionary for the actual attributes
        NSNumber* typeKey = @(type);
        
        // We'll create additional, special attributes for some rules.
        // Let's add 100 to the type to create separate keys for split-paragraph rules.
        if (!line.beginsNewParagraph && (type == action || type == lyrics || type == centered) && !line.isTitlePage) {
            typeKey = @(type + 100);
        } else if (!line.paragraphIn && line.beginsNewParagraph && [self.styles forLine:line].unindentFreshParagraphs) {
            typeKey = @(type + 200);
        }
        
        // In the same way, RTL text needs an offset for saved value keys
        if (rightToLeft) typeKey = @(type + 300);
        
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
            RenderStyle *style = (!forcedType) ? [self.styles forLine:line] : [self.styles forElement:[Line typeName:type]];
            
            BXFont* font = [self fontWith:style];
            
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
            CGFloat blockWidth     = [self blockWidthFor:line dualDialogue:isDualDialogue];
                        
            // Paragraph style -- handle indents and margins
            NSMutableParagraphStyle* pStyle = NSMutableParagraphStyle.new;
            pStyle.headIndent               = style.marginLeft + style.indent;
            pStyle.firstLineHeadIndent      = style.marginLeft + style.firstLineIndent;
            pStyle.tailIndent = -1 * style.marginRight; // Negative value;

            // Check for additional rules
            if (style.unindentFreshParagraphs && line.beginsNewParagraph && !line.paragraphIn) {
                pStyle.firstLineHeadIndent -= style.firstLineIndent;
            }
            
            // Add additional indent for parenthetical lines (hard-coded for now)
            if (line.type == parenthetical) {
                blockWidth += 7.25;
                pStyle.headIndent += 7.25;
            }
            
            // Top/bottom spacing
            pStyle.paragraphSpacingBefore = style.marginTop;
            pStyle.paragraphSpacing = style.marginBottom;
                        
            // Line height
            pStyle.maximumLineHeight = self.styles.page.lineHeight;
            pStyle.minimumLineHeight = self.styles.page.lineHeight;
            
            // Add content padding where needed
            if (!isDualDialogue && !line.isTitlePage) {
                pStyle.firstLineHeadIndent     += self.styles.page.contentPadding;
                pStyle.headIndent              += self.styles.page.contentPadding;
            } else if (!line.isTitlePage) {
                pStyle.firstLineHeadIndent     = style.marginLeft;
                pStyle.headIndent              = style.marginLeft;
            }
            
            // With RTL text, we need to switch the margins
            if (rightToLeft) {
                CGFloat fLHI = pStyle.headIndent;
                CGFloat tI = pStyle.tailIndent;
                
                // Make the values negative from what they were.
                // In LTR text, positive value means the amount from *left* side, so a positive tail indent will mean that it's how far the tail is from LEFT SIDE of the text area.
                // Negative value means the distance from *right* max X.
                pStyle.tailIndent = -fLHI;
                pStyle.headIndent = -tI;
                pStyle.firstLineHeadIndent = -tI;
            }
            
            // Create text block for non-title page elements to restrict horizontal size
            if (!line.isTitlePage && !isDualDialogue) {
#if TARGET_OS_OSX
                NSTextBlock* textBlock = NSTextBlock.new;
                [textBlock setContentWidth:blockWidth type:NSTextBlockAbsoluteValueType];
                pStyle.textBlocks = @[textBlock];
#else
                // This is a cursed solution, but what can I say. TextKit 2 (or iOS for that matter) doesn't support text blocks.
                CGFloat rightMargin = style.marginLeft / 2 + blockWidth - style.marginRight;
                pStyle.tailIndent = rightMargin;                
#endif
            }
            
            // Text alignment
            pStyle.alignment = style.textAlignment;
                        
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

- (CGFloat)widthFor:(Line*)line
{
    if (line == nil) return 0.0;
    
    RenderStyle* style = [self.styles forLine:line];
    CGFloat width = [style widthWithPageSize:self.settings.paperSize];
    if (width == 0.0) width = [self.styles.page defaultWidthWithPageSize:self.settings.paperSize];
        
    return width;
}

/// This is the **full** block width, including margins
- (CGFloat)blockWidthFor:(Line*)line dualDialogue:(bool)isDualDialogue
{
    if (line == nil) return 0.0;
    
    RenderStyle* style = [self.styles forLine:line];
    CGFloat width = [style widthWithPageSize:self.settings.paperSize];
    if (width == 0.0) width = [self.styles.page defaultWidthWithPageSize:self.settings.paperSize];
    
    CGFloat blockWidth = width + style.marginLeft + ((self.settings.paperSize == BeatA4) ? style.marginLeftA4 : style.marginLeftLetter);
    if (!isDualDialogue) blockWidth += self.styles.page.contentPadding;
        
    return blockWidth;
}

- (NSAttributedString*)emojiFontsFor:(NSAttributedString*)attrStr
{
    NSMutableAttributedString* result = [NSMutableAttributedString.alloc initWithAttributedString:attrStr];
#if TARGET_OS_OSX
    if (@available(macOS 10.15, *)) {
#endif
        NSArray* ranges = attrStr.string.emo_emojiRanges;
        BXFont* emojiFont = BeatFontManager.shared.defaultFonts.emojiFont;
        
        for (NSValue* v in ranges) {
            NSRange range = v.rangeValue;
            if (NSMaxRange(range) > attrStr.length) continue;
            
            NSDictionary* attrs = [attrStr attributesAtIndex:range.location effectiveRange:0];
            BXFont* font = attrs[NSFontAttributeName];
            
            BXFont* eFont = [emojiFont fontWithSize:font.pointSize];
            
            if (eFont != nil)
                [result addAttribute:NSFontAttributeName value:eFont range:range];
        }
#if TARGET_OS_OSX
    }
#endif
    
    return result;
}

@end
