//
//  OutlineItem.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 20.11.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

//#import <Cocoa/Cocoa.h>
#import <TargetConditionals.h>
#import <BeatParsing/BeatParsing.h>
#import <BeatThemes/BeatThemes.h>
#import "OutlineViewItem.h"
#import <BeatCore/BeatCore.h>
#import <BeatCore/BeatCore-Swift.h>

#define SECTION_FONTSIZE 13.0
#define SYNOPSE_FONTSIZE 12.0
#define SCENE_FONTSIZE 11.5

#if TARGET_OS_IOS
	#import <UIKit/UIKit.h>
	#define BXFont UIFont
	#define BXColor UIColor
	#define BXFontWeightRegular UIFontWeightRegular
	#define BXFontWeightBold UIFontWeightBold
#else
	#import <Cocoa/Cocoa.h>
	#define BXFont NSFont
	#define BXColor NSColor
	#define BXFontWeightRegular NSFontWeightRegular
	#define BXFontWeightBold NSFontWeightBold
#endif


@interface OutlineViewItem ()
@property (nonatomic) OutlineScene *scene;
@end

@implementation OutlineViewItem

+ (CGFloat)fontSize {
	CGFloat size = BXFont.smallSystemFontSize;
	size += [BeatUserDefaults.sharedDefaults getInteger:BeatSettingOutlineFontSizeModifier];
	return size;
}
+ (CGFloat)sectionFontSize {
	CGFloat size = BXFont.smallSystemFontSize;
	size += [BeatUserDefaults.sharedDefaults getInteger:BeatSettingOutlineFontSizeModifier];
	return size * 1.2;
}

/// Returns an attributed string for outline view
+ (NSAttributedString*)withScene:(OutlineScene *)scene currentScene:(OutlineScene *)current sceneNumber:(bool)includeSceneNumber synopsis:(bool)includeSynopsis notes:(bool)includeNotes markers:(bool)includeMarkers isDark:(bool)dark
{
	Line *line = scene.line;
	if (line == nil) { return NSMutableAttributedString.new; }
	
	ThemeManager* theme = ThemeManager.sharedManager;
	BXColor* sceneNumberColor  = (dark) ? theme.outlineSceneNumber.darkColor : theme.outlineSceneNumber.lightColor;
	BXColor* outlineItemColor  = (dark) ? theme.outlineItem.darkColor : theme.outlineItem.lightColor;
	BXColor* omittedItemColor  = (dark) ? theme.outlineItemOmitted.darkColor : theme.outlineItemOmitted.lightColor;
	BXColor* sectionItemColor  = (dark) ? theme.outlineSection.darkColor : theme.outlineSection.lightColor;
	BXColor* synopsisItemColor = (dark) ? theme.outlineSynopsis.darkColor : theme.outlineSynopsis.lightColor;
	BXColor* noteItemColor     = (dark) ? theme.outlineNote.darkColor : theme.outlineNote.lightColor;

	
	NSMutableAttributedString *resultString = NSMutableAttributedString.new;
	
	// Get the string, trim and strip any formatting. See if anything is left after that.
	NSMutableString* rawString = [scene.stringForDisplay stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet].mutableCopy;
	[rawString replaceOccurrencesOfString:@"*" withString:@"" options:0 range:NSMakeRange(0, rawString.length)];
	
	// Nothing left, return an empty attributed string.
	if (rawString.length == 0) { return NSAttributedString.new; }
	
	NSString *string = rawString;
	
	// Set item color
	BXColor *itemColor;
	if (line.color && !line.omitted) itemColor = [BeatColors color:line.color];
	
	// Style the item
	if (line.type == heading) {
		CGFloat fontSize = [OutlineViewItem fontSize];
		BXFont *font = [BXFont systemFontOfSize:fontSize weight:BXFontWeightRegular];
		
		//Replace "INT/EXT" with "I/E" to make the lines match nicely
		string = string.uppercaseString;
		string = [string stringByReplacingOccurrencesOfString:@"INT/EXT" withString:@"I/E"];
		string = [string stringByReplacingOccurrencesOfString:@"INT./EXT" withString:@"I/E"];
		string = [string stringByReplacingOccurrencesOfString:@"EXT/INT" withString:@"I/E"];
		string = [string stringByReplacingOccurrencesOfString:@"EXT./INT" withString:@"I/E"];

		// Put omitted scenes in parentheses
		if (line.omitted) string = [NSString stringWithFormat:@"(%@)", string];
		
		// Only include scene number if it's requested
		NSString *sceneNumber = (!line.omitted && includeSceneNumber) ? [NSString stringWithFormat:@"%@. ", line.sceneNumber] : @"";
		NSAttributedString *header = [NSAttributedString.alloc initWithString:sceneNumber attributes:@{
			NSForegroundColorAttributeName: sceneNumberColor,
			NSFontAttributeName: font
		}];
		
		BXColor *sceneColor = (itemColor != nil) ? itemColor : outlineItemColor;
		NSAttributedString *body = [NSAttributedString.alloc initWithString:string attributes:@{
			NSForegroundColorAttributeName: (!line.omitted) ? sceneColor : omittedItemColor,
			NSFontAttributeName: font
		}];
			
		[resultString appendAttributedString:header];
		[resultString appendAttributedString:body];
	}

	else if (line.type == section) {
		if (string.length > 0) {
			CGFloat fontSize = [OutlineViewItem sectionFontSize];
			BXFont *font = [BXFont systemFontOfSize:fontSize weight:BXFontWeightBold];
			
			BXColor *color = (itemColor != nil) ? itemColor : sectionItemColor;
			resultString = [[NSMutableAttributedString alloc] initWithString:(string) ? string : @"" attributes:@{
				NSForegroundColorAttributeName: color,
				NSFontAttributeName: font
			}];
		}
	}
	
	// Append synopsis lines
	if (includeSynopsis) {
		NSMutableParagraphStyle *synopsisStyle = NSMutableParagraphStyle.new;
		synopsisStyle.lineSpacing = .65;
		synopsisStyle.paragraphSpacingBefore = 4.0;
		
		CGFloat fontSize = [OutlineViewItem fontSize];

		for (Line* synopsis in scene.synopsis) {
			NSString *synopsisStr = [NSString stringWithFormat:@"\n• %@", synopsis.stripFormatting];
			BXColor *synopsisColor;
			
			if (synopsis.color.length > 0) synopsisColor = [BeatColors color:synopsis.color];
			if (synopsisColor == nil) synopsisColor = synopsisItemColor;
						
			#if TARGET_OS_IOS
				BXFont* synopsisFont = [BXFont italicSystemFontOfSize:fontSize];
			#else
				BXFont* synopsisFont = [BXFont systemFontOfSize:fontSize];
			#endif
			
			NSMutableAttributedString *synopsisLine = [NSMutableAttributedString.alloc initWithString:synopsisStr attributes:@{
				NSFontAttributeName: synopsisFont,
				NSForegroundColorAttributeName: synopsisColor,
				NSParagraphStyleAttributeName: synopsisStyle
			}];
			
			#if !TARGET_OS_IOS
				[synopsisLine applyFontTraits:NSItalicFontMask range:NSMakeRange(0, synopsisLine.length)];
			#endif
			
			[resultString appendAttributedString:synopsisLine];
		}
	}
	
	if (includeNotes) {
		CGFloat fontSize = [OutlineViewItem fontSize];
		BXFont* noteFont = [BXFont systemFontOfSize:fontSize];
		
		NSMutableParagraphStyle *noteStyle = NSMutableParagraphStyle.new;
		noteStyle.lineSpacing = .65;
		noteStyle.paragraphSpacingBefore = 5.0;
		
		for (BeatNoteData* note in scene.notes) {
			if (note.content.length == 0) continue;
			else if (NSIntersectionRange(note.range, scene.line.colorRange).length == note.range.length) continue;
			else if (note.type != NoteTypeNormal) continue;
			
			NSString* noteStr = [NSString stringWithFormat:@"\n✎ %@", note.content];
			
			BXColor* noteColor = noteItemColor;
			if (note.color) {
				BXColor* c = [BeatColors color:note.color];
				if (c != nil) noteColor = c;
			}
			
			NSAttributedString* noteLine = [NSAttributedString.alloc initWithString:noteStr attributes:@{
				NSFontAttributeName: noteFont,
				NSForegroundColorAttributeName: noteColor,
				NSParagraphStyleAttributeName: noteStyle
			}];
			
			if ([noteStr containsString:@"\n"]) {
				// Fix paragraph style for multi-line notes
				NSInteger p = 2; // Exclude the first line breaks
				NSRange rangeWithoutFirstLine = NSMakeRange(p, noteStr.length - p);
				
				NSMutableAttributedString* noteLineCopy = noteLine.mutableCopy;
				NSMutableParagraphStyle* noSpacingStyle = noteStyle.mutableCopy;
				noSpacingStyle.paragraphSpacingBefore = 0.0;
				
				[noteLineCopy addAttribute:NSParagraphStyleAttributeName value:noSpacingStyle range:rangeWithoutFirstLine];
				noteLine = noteLineCopy;
			}
			
			[resultString appendAttributedString:noteLine];
		}
	}

	if (includeMarkers) {
		CGFloat fontSize = [OutlineViewItem fontSize];

		NSMutableParagraphStyle *markerStyle = NSMutableParagraphStyle.new;
		markerStyle.lineSpacing = .65;
		markerStyle.paragraphSpacingBefore = 4.0;
		
		for (NSDictionary* marker in scene.markers) {
			NSString* colorName = marker[@"color"];
			
			BXColor* color = (colorName.length > 0) ? [BeatColors color:colorName] : nil;
			if (color == nil) color = [BeatColors color:@"orange"];
			
			NSString* description = [NSString stringWithFormat:@" %@", marker[@"description"]];
			NSArray* blocks = @[
				[AttributedBlock.alloc initWithType:AttributedBlockTypeText value:@"\n"],
				[AttributedBlock.alloc initWithType:AttributedBlockTypeSymbol value:@"bookmark.fill"],
				[AttributedBlock.alloc initWithType:AttributedBlockTypeText value:description],
			];
			
			NSAttributedString* aStr = [NSAttributedString createWithBlocks:blocks font:[BXFont systemFontOfSize:fontSize] textColor:color symbolColor:color paragraphStyle:markerStyle];
			
			[resultString appendAttributedString:aStr];
		}
	}

	return resultString;
}

@end
