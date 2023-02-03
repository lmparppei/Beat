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
#import <BeatCore/BeatColors.h>

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


/// Returns an attributed string for outline view
+ (NSAttributedString*) withScene:(OutlineScene *)scene currentScene:(OutlineScene *)current withSynopsis:(bool)includeSynopsis isDark:(bool)dark {
	Line *line = scene.line;
	if (line == nil) { return NSMutableAttributedString.new; }
	
	ThemeManager* theme = ThemeManager.sharedManager;
	BXColor* sceneNumberColor = (dark) ? theme.outlineSceneNumber.darkAquaColor : theme.outlineSceneNumber.aquaColor;
	BXColor* outlineItemColor = (dark) ? theme.outlineItem.darkAquaColor : theme.outlineItem.aquaColor;
	BXColor* omittedItemColor = (dark) ? theme.outlineItemOmitted.darkAquaColor : theme.outlineItemOmitted.aquaColor;
	BXColor* sectionItemColor = (dark) ? theme.outlineSection.darkAquaColor : theme.outlineSection.aquaColor;
	BXColor* synopsisItemColor = (dark) ? theme.outlineSynopsis.darkAquaColor : theme.outlineSynopsis.aquaColor;

	
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
		BXFont *font = [BXFont systemFontOfSize:BXFont.smallSystemFontSize weight:BXFontWeightRegular];
		
		//Replace "INT/EXT" with "I/E" to make the lines match nicely
		string = string.uppercaseString;
		string = [string stringByReplacingOccurrencesOfString:@"INT/EXT" withString:@"I/E"];
		string = [string stringByReplacingOccurrencesOfString:@"INT./EXT" withString:@"I/E"];
		string = [string stringByReplacingOccurrencesOfString:@"EXT/INT" withString:@"I/E"];
		string = [string stringByReplacingOccurrencesOfString:@"EXT./INT" withString:@"I/E"];

		// Put omitted scenes in parentheses
		if (line.omitted) string = [NSString stringWithFormat:@"(%@)", string];
		
		NSString *sceneNumber = (!line.omitted) ? [NSString stringWithFormat:@"%@. ", line.sceneNumber] : @"";
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
			BXFont *font = [BXFont systemFontOfSize:BXFont.smallSystemFontSize * 1.2 weight:BXFontWeightBold];
			
			BXColor *color = (itemColor != nil) ? itemColor : sectionItemColor;
			resultString = [[NSMutableAttributedString alloc] initWithString:(string) ? string : @"" attributes:@{
				NSForegroundColorAttributeName: color,
				NSFontAttributeName: font
			}];
		}
	}
	
	// Append synopsis lines
	if (includeSynopsis) {
		for (Line* synopsis in scene.synopsis) {
			NSString *synopsisStr = [NSString stringWithFormat:@"\n• %@", synopsis.stripFormatting];
			BXColor *synopsisColor;
			
			if (synopsis.color.length > 0) synopsisColor = [BeatColors color:synopsis.color];
			if (synopsisColor == nil) synopsisColor = synopsisItemColor;
			
			NSMutableParagraphStyle *synopsisStyle = NSMutableParagraphStyle.new;
			synopsisStyle.lineSpacing = .65;
			synopsisStyle.paragraphSpacingBefore = 4.0;
			
			#if TARGET_OS_IOS
				BXFont* synopsisFont = [BXFont italicSystemFontOfSize:BXFont.smallSystemFontSize];
			#else
				BXFont* synopsisFont = [BXFont systemFontOfSize:BXFont.smallSystemFontSize];
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

	return resultString;
}

@end
