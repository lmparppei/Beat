//
//  BeatiOSFormatting.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 14.5.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatiOSFormatting.h"
#import <BeatThemes/BeatThemes.h>
#import "ContinuousFountainParser.h"
#import "BeatColors.h"
#import "NSString+CharacterControl.h"
#import "BeatRevisions.h"
#import "BeatTagging.h"
#import "BeatTag.h"
#import "Beat_iOS-Swift.h"

@implementation BeatiOSFormatting

// DOCUMENT LAYOUT SETTINGS
// The 0.?? values represent percentages of view width
#define INITIAL_WIDTH 900
#define INITIAL_HEIGHT 700

#define DOCUMENT_WIDTH_MODIFIER 630

#define DD_CHARACTER_INDENT_P 0.56
#define DD_PARENTHETICAL_INDENT_P 0.50
#define DUAL_DIALOGUE_INDENT_P 0.40
#define DD_RIGHT 650
#define DD_RIGHT_P .95

// Title page element indent
#define TITLE_INDENT .15

#define CHARACTER_INDENT_P 0.34
#define PARENTHETICAL_INDENT_P 0.27
#define DIALOGUE_INDENT_P 0.164
#define DIALOGUE_RIGHT_P 0.735

#define SECTION_FONT_SIZE 20.0 // base value for section sizes
#define FONT_SIZE 17.92
#define LINE_HEIGHT 1.1

static NSString *lineBreak = @"\n\n===\n\n";
static NSString *boldSymbol = @"**";
static NSString *italicSymbol = @"*";
static NSString *underlinedSymbol = @"_";
static NSString *noteOpen = @"[[";
static NSString *noteClose= @"]]";
static NSString *omitOpen = @"/*";
static NSString *omitClose= @"*/";
static NSString *forceHeadingSymbol = @".";
static NSString *forceActionSymbol = @"!";
static NSString *forceCharacterSymbol = @"@";
static NSString *forcetransitionLineSymbol = @">";
static NSString *forceLyricsSymbol = @"~";
static NSString *forceDualDialogueSymbol = @"^";

static NSString *highlightSymbolOpen = @"<<";
static NSString *highlightSymbolClose = @">>";
static NSString *strikeoutSymbolOpen = @"{{";
static NSString *strikeoutSymbolClose = @"}}";

static NSString *tagAttribute = @"BeatTag";
static NSString *reviewAttribute = @"BeatReview";

- (UITextRange*)getTextRangeFor:(NSRange)range {
	UITextRange *oldRange = self.delegate.textView.selectedTextRange;
	[self.delegate.textView setSelectedRange:range];
	UITextRange *newRange = [self.delegate.textView selectedTextRange];
	[self.delegate.textView setSelectedTextRange:oldRange];
	return newRange;
}

- (void)formatLine:(Line*)line { [self formatLine:line firstTime:NO]; }

- (void)formatLine:(Line*)line firstTime:(bool)firstTime
{
	/*
	 
	 This method uses a mixture of permanent text attributes and temporary attributes
	 to optimize performance.
	 
	 Colors are set using NSLayoutManager's temporary attributes, while everything else
	 is stored into the attributed string in NSTextStorage.
	 
	*/

	UITextView *textView = _delegate.textView;

	// Don't go out of range (just a safety measure for plugins etc.)
	if (line.position + line.string.length > textView.text.length) return;	
	
	NSRange range = line.textRange;
	UITextRange *textRange = [self getTextRangeFor:range];
	
	NSTextStorage *textStorage = textView.textStorage;
	NSMutableDictionary *attributes = NSMutableDictionary.new;
	NSMutableParagraphStyle *paragraphStyle = NSMutableParagraphStyle.new;

	ThemeManager *themeManager = ThemeManager.sharedManager;
		
	// Do nothing for already formatted empty lines (except remove the background)
	if (line.type == empty && line.formattedAs == empty && line.string.length == 0) {
		[textStorage addAttribute:NSBackgroundColorAttributeName value:UIColor.clearColor range:line.textRange];
		return;
	}

	// Store the type we are formatting for
	line.formattedAs = line.type;
	
	// Line height
	[paragraphStyle setLineHeightMultiple:LINE_HEIGHT];
	
	[textStorage addAttribute:NSForegroundColorAttributeName value:themeManager.textColor range:line.textRange];
	[textStorage addAttribute:NSBackgroundColorAttributeName value:UIColor.clearColor range:line.textRange];
	
	// Redo everything we just did for forced character input
	if (_delegate.characterInput && _delegate.characterInputForLine == line) {
		// Do some extra checks for dual dialogue
		if (line.length && line.lastCharacter == '^') line.type = dualDialogueCharacter;
		else line.type = character;
		
		NSRange selectedRange = textView.selectedRange;
		
		// Only do this if we are REALLY typing at this location
		// Foolproof fix for a strange, rare bug which changes multiple
		// lines into character cues and the user is unable to undo the changes
		if (range.location + range.length <= selectedRange.location) {
			[textView replaceRange:textRange withText:[textStorage.string substringWithRange:range].uppercaseString];
			line.string = line.string.uppercaseString;
			[textView setSelectedRange:selectedRange];
			
			// Reset attribute because we have replaced the text
			[textStorage addAttribute:NSForegroundColorAttributeName value:themeManager.textColor range:line.textRange];
		}
	}
	
	if (line.type == heading) {
		// Format heading
		
		// Stylize according to settings
		if (_delegate.headingStyleBold) [attributes setObject:_delegate.boldCourier forKey:NSFontAttributeName];
		if (_delegate.headingStyleUnderline) [attributes setObject:@1 forKey:NSUnderlineStyleAttributeName];
		
		// If the scene has a color, let's color it
		if (line.color.length) {
			UIColor* headingColor = [BeatColors color:line.color.lowercaseString];
			if (headingColor != nil) [textStorage addAttribute:NSForegroundColorAttributeName value:headingColor range:line.textRange];
		}
	} else if (line.type == pageBreak) {
		// Format page break - bold
		[attributes setObject:_delegate.boldCourier forKey:NSFontAttributeName];
		
	} else if (line.type == lyrics) {
		// Format lyrics - italic
		[attributes setObject:_delegate.italicCourier forKey:NSFontAttributeName];
		[paragraphStyle setAlignment:NSTextAlignmentCenter];
	}
	
	// Handle title page block
	if (line.type == titlePageTitle  ||
		line.type == titlePageAuthor ||
		line.type == titlePageCredit ||
		line.type == titlePageSource ||
		
		line.type == titlePageUnknown ||
		line.type == titlePageContact ||
		line.type == titlePageDraftDate) {
		
		[paragraphStyle setFirstLineHeadIndent:TITLE_INDENT * DOCUMENT_WIDTH_MODIFIER];
		[paragraphStyle setHeadIndent:TITLE_INDENT * DOCUMENT_WIDTH_MODIFIER];
		[attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
		
		// Indent lines following a first-level title page element a bit more
		if ([line.string rangeOfString:@":"].location != NSNotFound) {
			[paragraphStyle setFirstLineHeadIndent:TITLE_INDENT * DOCUMENT_WIDTH_MODIFIER];
			[paragraphStyle setHeadIndent:TITLE_INDENT * DOCUMENT_WIDTH_MODIFIER];
		} else {
			[paragraphStyle setFirstLineHeadIndent:TITLE_INDENT * 1.25 * DOCUMENT_WIDTH_MODIFIER];
			[paragraphStyle setHeadIndent:TITLE_INDENT * 1.1 * DOCUMENT_WIDTH_MODIFIER];
		}
	} else if (line.type == transitionLine) {
		// Transitions
		[paragraphStyle setAlignment:NSTextAlignmentRight];
		
	} else if (line.type == centered || line.type == lyrics) {
		// Lyrics & centered text
		[paragraphStyle setAlignment:NSTextAlignmentCenter];
	
	} else if (line.type == character) {
		// Character cue
		[paragraphStyle setFirstLineHeadIndent:CHARACTER_INDENT_P * DOCUMENT_WIDTH_MODIFIER];
		[paragraphStyle setHeadIndent:CHARACTER_INDENT_P * DOCUMENT_WIDTH_MODIFIER];

		[attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
	} else if (line.type == parenthetical) {
		// Parenthetical after character
		[paragraphStyle setFirstLineHeadIndent:PARENTHETICAL_INDENT_P * DOCUMENT_WIDTH_MODIFIER];
		[paragraphStyle setHeadIndent:PARENTHETICAL_INDENT_P * DOCUMENT_WIDTH_MODIFIER];
		[paragraphStyle setTailIndent:DIALOGUE_RIGHT_P * DOCUMENT_WIDTH_MODIFIER];
		
	} else if (line.type == dialogue) {
		// Dialogue block
		[paragraphStyle setFirstLineHeadIndent:DIALOGUE_INDENT_P * DOCUMENT_WIDTH_MODIFIER];
		[paragraphStyle setHeadIndent:DIALOGUE_INDENT_P * DOCUMENT_WIDTH_MODIFIER];
		[paragraphStyle setTailIndent:DIALOGUE_RIGHT_P * DOCUMENT_WIDTH_MODIFIER];
		
	} else if (line.type == dualDialogueCharacter) {
		[paragraphStyle setFirstLineHeadIndent:DD_CHARACTER_INDENT_P * DOCUMENT_WIDTH_MODIFIER];
		[paragraphStyle setHeadIndent:DD_CHARACTER_INDENT_P * DOCUMENT_WIDTH_MODIFIER];
		[paragraphStyle setTailIndent:DD_RIGHT_P * DOCUMENT_WIDTH_MODIFIER];
		
	} else if (line.type == dualDialogueParenthetical) {
		[paragraphStyle setFirstLineHeadIndent:DD_PARENTHETICAL_INDENT_P * DOCUMENT_WIDTH_MODIFIER];
		[paragraphStyle setHeadIndent:DD_PARENTHETICAL_INDENT_P * DOCUMENT_WIDTH_MODIFIER];
		[paragraphStyle setTailIndent:DD_RIGHT_P * DOCUMENT_WIDTH_MODIFIER];
		
	} else if (line.type == dualDialogue) {
		[paragraphStyle setFirstLineHeadIndent:DUAL_DIALOGUE_INDENT_P * DOCUMENT_WIDTH_MODIFIER];
		[paragraphStyle setHeadIndent:DUAL_DIALOGUE_INDENT_P * DOCUMENT_WIDTH_MODIFIER];
		[paragraphStyle setTailIndent:DD_RIGHT_P * DOCUMENT_WIDTH_MODIFIER];
	} else if (line.type == section || line.type == synopse) {
		// Stylize sections & synopses

		if (line.type == section) {
			CGFloat size = SECTION_FONT_SIZE;
			
			UIColor *sectionColor;
			
			if (line.sectionDepth == 1) {
				[paragraphStyle setParagraphSpacingBefore:30];
				[paragraphStyle setParagraphSpacing:0];
				
				// Black or custom for high-level sections
				
				if (line.color) {
					if (!(sectionColor = [BeatColors color:line.color])) sectionColor = themeManager.sectionTextColor;
				} else sectionColor = themeManager.sectionTextColor;
				

				[textStorage addAttribute:NSForegroundColorAttributeName value:sectionColor range:line.textRange];
				//[attributes setObject:sectionColor forKey:NSForegroundColorAttributeName];
				[attributes setObject:[_delegate sectionFontWithSize:size] forKey:NSFontAttributeName];
			} else {
				if (line.sectionDepth == 2) {
					[paragraphStyle setParagraphSpacingBefore:20];
					[paragraphStyle setParagraphSpacing:0];
				}
				
				// And custom or gray for others
				if (line.color) {
					if (!(sectionColor = [BeatColors color:line.color])) sectionColor = themeManager.sectionTextColor;
				} else sectionColor = themeManager.commentColor;
				
				//[attributes setObject:sectionColor forKey:NSForegroundColorAttributeName];
				[textStorage addAttribute:NSForegroundColorAttributeName value:sectionColor range:line.textRange];
				
				// Also, make lower sections a bit smaller
				size = size - line.sectionDepth;
				if (size < 15) size = 15.0;
				
				[attributes setObject:[_delegate sectionFontWithSize:size] forKey:NSFontAttributeName];
			}
		}
		
		if (line.type == synopse) {
			UIColor* synopsisColor;
			if (line.color) {
				if (!(synopsisColor = [BeatColors color:line.color])) synopsisColor = themeManager.sectionTextColor;
			} else synopsisColor = themeManager.synopsisTextColor;
			
			//if (synopsisColor) [attributes setObject:synopsisColor forKey:NSForegroundColorAttributeName];
			if (synopsisColor) [textStorage addAttribute:NSForegroundColorAttributeName value:synopsisColor range:line.textRange];
			
			[attributes setObject:_delegate.synopsisFont forKey:NSFontAttributeName];
		}
		
	} else if (line.type == empty) {
		// Just to make sure that after second empty line we reset indents
		NSInteger lineIndex = [_delegate.parser.lines indexOfObject:line];
		
		if (lineIndex > 1) {
			Line* precedingLine = [_delegate.parser.lines objectAtIndex:lineIndex - 1];
			if (precedingLine.string.length < 1) {
				[paragraphStyle setFirstLineHeadIndent:0];
				[paragraphStyle setHeadIndent:0];
				[paragraphStyle setTailIndent:0];
			}
		}
	}
	
	// Apply paragraph styles set above
	[attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
	
	// Overwrite fonts if they are not set yet
	if (![attributes valueForKey:NSFontAttributeName]) {
		[attributes setObject:_delegate.courier forKey:NSFontAttributeName];
	}
	if (![attributes valueForKey:NSUnderlineStyleAttributeName]) {
		[attributes setObject:@0 forKey:NSUnderlineStyleAttributeName];
	}
	if (![attributes valueForKey:NSStrikethroughStyleAttributeName]) {
		[attributes setObject:@0 forKey:NSStrikethroughStyleAttributeName];
	}
	if (!attributes[NSBackgroundColorAttributeName]) {
		//[attributes setObject:UIColor.clearColor forKey:NSBackgroundColorAttributeName];
		[textStorage addAttribute:NSBackgroundColorAttributeName value:UIColor.clearColor range:range];
	}
	
	// Add selected attributes
	if (range.length > 0) {
		[textStorage addAttributes:attributes range:range];
	} else {
		// Add attributes ahead
		if (range.location + 1 < textStorage.string.length) {
			range = NSMakeRange(range.location, range.length + 1);
			[textStorage addAttributes:attributes range:range];
		}
	}
		
	//[self endMeasure:@"Add attributes"];
	
	// INPUT ATTRIBUTES FOR CARET / CURSOR
	if (line.string.length == 0 && !firstTime) {
		// If the line is empty, we need to set typing attributes too, to display correct positioning if this is a dialogue block.
		Line* previousLine;
		NSInteger lineIndex = [_delegate.parser.lines indexOfObject:line];
		if (lineIndex > 0) previousLine = [_delegate.parser.lines objectAtIndex:lineIndex - 1];
		
		//NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc]init];

		// Keep dialogue input for character blocks
		if ((previousLine.type == dialogue || previousLine.type == character || previousLine.type == parenthetical)
			&& previousLine.string.length) {
			[paragraphStyle setFirstLineHeadIndent:DIALOGUE_INDENT_P * DOCUMENT_WIDTH_MODIFIER];
			[paragraphStyle setHeadIndent:DIALOGUE_INDENT_P * DOCUMENT_WIDTH_MODIFIER];
			[paragraphStyle setTailIndent:DIALOGUE_RIGHT_P * DOCUMENT_WIDTH_MODIFIER];
		} else {
			[paragraphStyle setFirstLineHeadIndent:0];
			[paragraphStyle setHeadIndent:0];
			[paragraphStyle setTailIndent:0];
		}
		[attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
		[textView setTypingAttributes:attributes];
	}
	
	// Format scene number as invisible
	if (line.sceneNumberRange.length > 0) {
		NSRange sceneNumberRange = NSMakeRange(line.sceneNumberRange.location - 1, line.sceneNumberRange.length + 2);
		// Don't go out of range, please, please
		if (sceneNumberRange.location + sceneNumberRange.length <= line.string.length && sceneNumberRange.location >= 0) {
			[textStorage addAttribute:NSForegroundColorAttributeName value:themeManager.invisibleTextColor
								range:[self globalRangeFromLocalRange:&sceneNumberRange inLineAtPosition:line.position]];
		}
	}
	
	//Add in bold, underline, italics and other stylization
	[line.italicRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[self stylize:NSFontAttributeName value:_delegate.italicCourier line:line range:range formattingSymbol:italicSymbol];
	}];
	[line.boldRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[self stylize:NSFontAttributeName value:_delegate.boldCourier line:line range:range formattingSymbol:boldSymbol];
	}];
	[line.boldItalicRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[self stylize:NSFontAttributeName value:_delegate.boldItalicCourier line:line range:range formattingSymbol:@""];
	}];
	[line.underlinedRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[self stylize:NSUnderlineStyleAttributeName value:@1 line:line range:range formattingSymbol:underlinedSymbol];
	}];
	[line.strikeoutRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[self stylize:NSStrikethroughStyleAttributeName value:@1 line:line range:range formattingSymbol:strikeoutSymbolOpen];
	}];

	// Foreground color attributes
	if (line.isTitlePage && line.titleRange.length > 0) {
		NSRange titleRange = line.titleRange;
			[textStorage addAttribute:NSForegroundColorAttributeName
								   value:themeManager.commentColor
					   range:[self globalRangeFromLocalRange:&titleRange inLineAtPosition:line.position]];
	}
	
	[line.escapeRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[textStorage addAttribute:NSForegroundColorAttributeName
								   value:themeManager.invisibleTextColor
					   range:[self globalRangeFromLocalRange:&range inLineAtPosition:line.position]];
	}];
	
	[line.noteRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[textStorage addAttribute:NSForegroundColorAttributeName
								   value:themeManager.commentColor
					   range:[self globalRangeFromLocalRange:&range inLineAtPosition:line.position]];
	}];
	
	[line.omittedRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[textStorage addAttribute:NSForegroundColorAttributeName
								   value:themeManager.invisibleTextColor
					   range:[self globalRangeFromLocalRange:&range
												 inLineAtPosition:line.position]];
	}];


	// Format force element symbols
	if (line.numberOfPrecedingFormattingCharacters > 0 && line.string.length >= line.numberOfPrecedingFormattingCharacters) {
		[textStorage addAttribute:NSForegroundColorAttributeName
								   value:themeManager.invisibleTextColor
					   range:NSMakeRange(line.position, line.numberOfPrecedingFormattingCharacters)];
	} else if (line.type == centered && line.string.length > 1) {
		[textStorage addAttribute:NSForegroundColorAttributeName
								   value:themeManager.invisibleTextColor
					   range:NSMakeRange(line.position, 1)];
		[textStorage addAttribute:NSForegroundColorAttributeName
								   value:themeManager.invisibleTextColor
					   range:NSMakeRange(line.position + line.string.length - 1, 1)];
	}
	if (line.type == dualDialogueCharacter) {
		[textStorage addAttribute:NSForegroundColorAttributeName
								   value:themeManager.invisibleTextColor
					   range:NSMakeRange(line.position + line.length - 1, 1)];
	}
	
	if (line.string.containsOnlyWhitespace && line.length >= 2) {
		[textStorage addAttribute:NSForegroundColorAttributeName value:themeManager.invisibleTextColor range:line.textRange];
		[textStorage addAttribute:NSForegroundColorAttributeName value:themeManager.invisibleTextColor range:line.textRange];
	}
		
	// Color markers
	if (line.marker.length && line.markerRange.length) {
		UIColor *color = [BeatColors color:line.marker];
		NSRange markerRange = line.markerRange;
		if (color) [textStorage addAttribute:NSForegroundColorAttributeName
											  value:color
								  range:[self globalRangeFromLocalRange:&markerRange inLineAtPosition:line.position]];
	}

	
	// Render backgrounds according to text attributes
	// This is AMAZINGLY slow
	// [self renderTextBackgroundOnLine:line];

	if (!firstTime && line.string.length) {
		[self renderBackgroundForLine:line clearFirst:NO];
	}
}


#pragma mark - Text backgrounds (for revisions + tagging)

- (void)renderBackgroundForLines {
	for (Line* line in self.delegate.lines) {
		[self renderBackgroundForLine:line clearFirst:YES];
	}
}

- (void)renderBackgroundForLine:(Line*)line clearFirst:(bool)clear {
	NSTextStorage *textStorage = _delegate.textView.textStorage;
	
	// First clear the background attribute if needed
	if (clear) [textStorage addAttribute:NSBackgroundColorAttributeName value:UIColor.clearColor range:line.textRange];
	
	[textStorage addAttribute:NSStrikethroughStyleAttributeName value:@0 range:line.textRange];
	
	if (_delegate.showRevisions || _delegate.showTags) {
		// Enumerate attributes
		[textStorage enumerateAttributesInRange:line.textRange options:0 usingBlock:^(NSDictionary<NSAttributedStringKey,id> * _Nonnull attrs, NSRange range, BOOL * _Nonnull stop) {
			if (attrs[BeatRevisions.revisionAttribute] && _delegate.showRevisions) {
				BeatRevisionItem *revision = attrs[BeatRevisions.revisionAttribute];
				if (revision.type == RevisionAddition) {
					[textStorage addAttribute:NSBackgroundColorAttributeName value:revision.backgroundColor range:range];
				}
				else if (revision.type == RevisionRemovalSuggestion) {
					[textStorage addAttribute:NSStrikethroughColorAttributeName value:[BeatColors color:@"red"] range:range];
					[textStorage addAttribute:NSStrikethroughStyleAttributeName value:@1 range:range];
					[textStorage addAttribute:NSBackgroundColorAttributeName value:[[BeatColors color:@"red"] colorWithAlphaComponent:0.125] range:range];
				}
			}
			
			/*
			if (attrs[reviewAttribute]) {
				BeatReviewItem *review = attrs[reviewAttribute];
				if (!review.emptyReview) {
					UIColor *reviewColor = BeatReview.reviewColor;
					reviewColor = [reviewColor colorWithAlphaComponent:.5];
					[textStorage addAttribute:NSBackgroundColorAttributeName value:reviewColor range:range];
				}
			}
			 */
			
			if (attrs[tagAttribute] && _delegate.showTags) {
				BeatTag *tag = attrs[tagAttribute];
				UIColor *tagColor = [BeatTagging colorFor:tag.type];
				tagColor = [tagColor colorWithAlphaComponent:.5];
			   
				[textStorage addAttribute:NSBackgroundColorAttributeName value:tagColor range:range];
			}
		}];
	}
}

- (void)initialTextBackgroundRender {
	if (!_delegate.showTags && !_delegate.showRevisions) return;
	
	dispatch_async(dispatch_get_main_queue(), ^(void){
		[self renderBackgroundForLines];
	});
}


- (void)stylize:(NSString*)key value:(id)value line:(Line*)line range:(NSRange)range formattingSymbol:(NSString*)sym {
	// Don't add a nil value
	if (!value) return;
	
	ThemeManager *themeManager = ThemeManager.sharedManager;
	UITextView *textView = _delegate.textView;
	NSTextStorage *textStorage = textView.textStorage;
	
	NSUInteger symLen = sym.length;
	NSRange openRange = (NSRange){ range.location, symLen };
	NSRange closeRange = (NSRange){ range.location + range.length - symLen, symLen };
	
	NSRange effectiveRange;
	
	if (symLen == 0) {
		// Format full range
		effectiveRange = NSMakeRange(range.location, range.length);
	}
	else if (range.length >= 2 * symLen) {
		// Format between characters (ie. *italic*)
		effectiveRange = NSMakeRange(range.location + symLen, range.length - 2 * symLen);
	} else {
		// Format nothing
		effectiveRange = NSMakeRange(range.location + symLen, 0);
	}
	
	if (key.length) [textView.textStorage addAttribute:key value:value
						range:[self globalRangeFromLocalRange:&effectiveRange
											 inLineAtPosition:line.position]];
	
	if (openRange.length) {
		// Fuck. We need to format these ranges twice, because there is a weird bug in glyph setter.
		[textView.textStorage addAttribute:NSForegroundColorAttributeName
									 value:themeManager.invisibleTextColor
									 range:[self globalRangeFromLocalRange:&openRange
														  inLineAtPosition:line.position]];
		[textView.textStorage addAttribute:NSForegroundColorAttributeName
									 value:themeManager.invisibleTextColor
									 range:[self globalRangeFromLocalRange:&closeRange
														  inLineAtPosition:line.position]];
		
		[textStorage addAttribute:NSForegroundColorAttributeName value:themeManager.invisibleTextColor
					   range:[self globalRangeFromLocalRange:&openRange inLineAtPosition:line.position]];
		[textStorage addAttribute:NSForegroundColorAttributeName value:themeManager.invisibleTextColor
					   range:[self globalRangeFromLocalRange:&closeRange inLineAtPosition:line.position]];
	}
}

- (NSRange)globalRangeFromLocalRange:(NSRange*)range inLineAtPosition:(NSUInteger)position
{
	return NSMakeRange(range->location + position, range->length);
}

@end
