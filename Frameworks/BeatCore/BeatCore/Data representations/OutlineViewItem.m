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
#import <BeatCore/BeatCore.h>
#import <BeatCore/BeatCore-Swift.h>

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

+ (CGFloat)fontSizeForType:(LineType)type
{
    CGFloat size = BXFont.smallSystemFontSize;
    if (type == section) {
        size += [BeatUserDefaults.sharedDefaults getInteger:BeatSettingOutlineFontSizeModifier];
        size *= 1.2;
    } else {
        size += [BeatUserDefaults.sharedDefaults getInteger:BeatSettingOutlineFontSizeModifier];
    }
    
    return size;
}

+ (BXColor*)elementColor:(OutlineElementType)type dark:(bool)dark
{
    ThemeManager* theme = ThemeManager.sharedManager;
    switch (type) {
        case OutlineElementTypeSceneNumber:
            return (dark) ? theme.outlineSceneNumber.darkColor : theme.outlineSceneNumber.lightColor;
        case OutlineElementTypeOmitted:
            return (dark) ? theme.outlineItemOmitted.darkColor : theme.outlineItemOmitted.lightColor;
        case OutlineElementTypeSection:
            return (dark) ? theme.outlineSection.darkColor : theme.outlineSection.lightColor;
        case OutlineElementTypeNote:
            return (dark) ? theme.outlineNote.darkColor : theme.outlineNote.lightColor;
        case OutlineElementTypeSynopsis:
            return (dark) ? theme.outlineSynopsis.darkColor : theme.outlineSynopsis.lightColor;
            break;
        default:
#if TARGET_OS_OSX
            return (dark) ? theme.outlineItem.darkColor : theme.outlineItem.lightColor;
#else
            return UIColor.labelColor;
#endif
    }
}

+ (OutlineItemOptions)optionsWithSceneNumber:(bool)includeSceneNumber synopsis:(bool)includeSynopsis notes:(bool)includeNotes markers:(bool)includeMarkers isDark:(bool)dark
{
    OutlineItemOptions options = OutlineItemIncludeHeading;
    if (includeSceneNumber) options |= OutlineItemIncludeSceneNumber;
    if (includeSynopsis) options |= OutlineItemIncludeSynopsis;
    if (includeNotes) options |= OutlineItemIncludeNotes;
    if (includeMarkers) options |= OutlineItemIncludeMarkers;
    if (dark) options |= OutlineItemDarkMode;
    
    return options;
}

/// Returns an attributed string for outline view
+ (NSAttributedString*)withScene:(OutlineScene *)scene currentScene:(OutlineScene *)current sceneNumber:(bool)includeSceneNumber synopsis:(bool)includeSynopsis notes:(bool)includeNotes markers:(bool)includeMarkers isDark:(bool)dark
{
    OutlineItemOptions options = OutlineItemIncludeHeading;
    if (includeSceneNumber) options |= OutlineItemIncludeSceneNumber;
    if (includeSynopsis) options |= OutlineItemIncludeSynopsis;
    if (includeNotes) options |= OutlineItemIncludeNotes;
    if (includeMarkers) options |= OutlineItemIncludeMarkers;
    if (dark) options |= OutlineItemDarkMode;
    
    return [OutlineViewItem withScene:scene currentScene:current options:options];
}

+ (void)appendMarkers:(NSMutableAttributedString *)resultString scene:(OutlineScene * _Nonnull)scene {
    CGFloat fontSize = [OutlineViewItem fontSizeForType:action];
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

+ (void)appendNotes:(bool)dark resultString:(NSMutableAttributedString *)resultString scene:(OutlineScene * _Nonnull)scene {
    CGFloat fontSize = [OutlineViewItem fontSizeForType:action];
    BXFont* noteFont = [BXFont systemFontOfSize:fontSize];
    
    NSMutableParagraphStyle *noteStyle = NSMutableParagraphStyle.new;
    noteStyle.lineSpacing = .65;
    noteStyle.paragraphSpacingBefore = 5.0;
    
    for (BeatNoteData* note in scene.notes) {
        if (note.content.length == 0) continue;
        else if (NSIntersectionRange(note.range, scene.line.colorRange).length == note.range.length) continue;
        else if (note.type != NoteTypeNormal) continue;
        
        NSString* noteStr = [NSString stringWithFormat:@"\n✎ %@", note.content];
        
        BXColor* noteColor = [OutlineViewItem elementColor:OutlineElementTypeNote dark:dark];
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

+ (void)appendSynopsis:(bool)dark resultString:(NSMutableAttributedString *)resultString scene:(OutlineScene * _Nonnull)scene {
    CGFloat fontSize = [OutlineViewItem fontSizeForType:synopse];
    NSMutableParagraphStyle *synopsisStyle = NSMutableParagraphStyle.new;
    synopsisStyle.lineSpacing = .65;
    synopsisStyle.paragraphSpacingBefore = 4.0;
    
    for (Line* synopsis in scene.synopsis) {
        NSString *synopsisStr = [NSString stringWithFormat:@"\n• %@", synopsis.stripFormatting];
        BXColor *synopsisColor;
        
        if (synopsis.color.length > 0) synopsisColor = [BeatColors color:synopsis.color];
        if (synopsisColor == nil) synopsisColor = [OutlineViewItem elementColor:OutlineElementTypeSynopsis dark:dark];
        
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

+ (NSAttributedString*)withScene:(OutlineScene *)scene currentScene:(OutlineScene *)current options:(OutlineItemOptions)options
{
    Line *line = scene.line;
    if (line == nil) { return NSMutableAttributedString.new; }
    
    bool dark = (options & OutlineItemDarkMode) != 0;
    // Relative heights render background differently (when future generations come along)
    /*
     if ([BeatUserDefaults.sharedDefaults getBool:BeatSettingRelativeOutlineHeights] && scene.color.length > 0 && scene.type == heading) {
     BXColor* c = [BeatColors color:scene.color];
     if (c != nil) dark = c.isDarkAsBackground;
     } */
    
    NSMutableAttributedString *resultString = NSMutableAttributedString.new;
    
    // Get the string, trim and strip any formatting. Only add the actual heading if a heading is wanted.
    bool includeHeading = (options & OutlineItemIncludeHeading) != 0;
    NSString* rawString = @"";
    // Add heading if not toggled off and this is a scene. Sections will always have headings.
    if (!(scene.type == heading && !includeHeading)) {
        rawString = [scene.stringForDisplay stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        rawString = [rawString stringByReplacingOccurrencesOfString:@"*" withString:@"" options:0 range:NSMakeRange(0, rawString.length)];
    }
    
    NSString *string = rawString;
    
    // Set item color
    BXColor *itemColor;
    if (line.color && !line.omitted) itemColor = [BeatColors color:line.color];
    
    // Style the item
    if (line.type == heading) {
        CGFloat fontSize = [OutlineViewItem fontSizeForType:line.type];
        BXFont *font = [BXFont systemFontOfSize:fontSize weight:BXFontWeightRegular];
        
        if (includeHeading) {
            //Replace "INT/EXT" with "I/E" to make the lines match nicely
            string = string.uppercaseString;
            string = [string stringByReplacingOccurrencesOfString:@"INT/EXT" withString:@"I/E"];
            string = [string stringByReplacingOccurrencesOfString:@"INT./EXT" withString:@"I/E"];
            string = [string stringByReplacingOccurrencesOfString:@"EXT/INT" withString:@"I/E"];
            string = [string stringByReplacingOccurrencesOfString:@"EXT./INT" withString:@"I/E"];
            
            // Put omitted scenes in parentheses
            if (line.omitted) string = [NSString stringWithFormat:@"(%@)", string];
        }
        
        // Only include scene number if it's requested
        bool includeSceneNumber = (options & OutlineItemIncludeSceneNumber) != 0;
        NSString *sceneNumber = (!line.omitted && includeSceneNumber) ? [NSString stringWithFormat:@"%@. ", line.sceneNumber] : @"";
        NSAttributedString *header = [NSAttributedString.alloc initWithString:sceneNumber attributes:@{
            NSForegroundColorAttributeName: [OutlineViewItem elementColor:OutlineElementTypeSceneNumber dark:dark],
            NSFontAttributeName: font
        }];
        
        BXColor *sceneColor = (itemColor != nil) ? itemColor : [OutlineViewItem elementColor:OutlineElementTypeDefault dark:dark];
        
        NSAttributedString *body = [NSAttributedString.alloc initWithString:string attributes:@{
            NSForegroundColorAttributeName: (!line.omitted) ? sceneColor : [OutlineViewItem elementColor:OutlineElementTypeOmitted dark:dark],
            NSFontAttributeName: font
        }];
        
        [resultString appendAttributedString:header];
        [resultString appendAttributedString:body];
    } else if (line.type == section && string.length > 0) {
        CGFloat fontSize = [OutlineViewItem fontSizeForType:line.type];
        BXFont *font = [BXFont systemFontOfSize:fontSize weight:BXFontWeightBold];
        
        BXColor *color = (itemColor != nil) ? itemColor : [OutlineViewItem elementColor:OutlineElementTypeSection dark:dark];
        resultString = [[NSMutableAttributedString alloc] initWithString:(string) ? string : @"" attributes:@{
            NSForegroundColorAttributeName: color,
            NSFontAttributeName: font
        }];
    }
    
    // Append rest of the elements
    if ((options & OutlineItemIncludeSynopsis) != 0) {
        [self appendSynopsis:dark resultString:resultString scene:scene];
    }
    if ((options & OutlineItemIncludeNotes) != 0) {
        [self appendNotes:dark resultString:resultString scene:scene];
    }
    if ((options & OutlineItemIncludeMarkers) != 0) {
        [self appendMarkers:resultString scene:scene];
    }
    
    // Let's remove first line break if needed
    if (!includeHeading && resultString.length > 0) {
        unichar c = [resultString.string characterAtIndex:0];
        if (c == '\n') resultString = [resultString attributedSubstringFromRange:NSMakeRange(1, resultString.length - 1)].mutableCopy;
    }
    
    return resultString;
}

@end
