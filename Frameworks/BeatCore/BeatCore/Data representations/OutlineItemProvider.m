//
//  OutlineItemProvider.m
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 1.8.2025.
//

#import "OutlineItemProvider.h"
#import "OutlineViewItem.h"

#import <TargetConditionals.h>
#import <BeatParsing/BeatParsing.h>
#import <BeatThemes/BeatThemes.h>
#import <BeatCore/BeatCore.h>
#import <BeatCore/BeatCore-Swift.h>

@implementation BeatOutlineItemData
- (instancetype)initWithText:(NSAttributedString*)text line:(Line* _Nullable)line range:(NSRange)range
{
    self = [super init];
    if (self) {
        self.line = line;
        self.text = text;
        self.range = range;
    }
    return self;
}
@end

@interface OutlineItemProvider ()
@property (nonatomic) OutlineItemOptions options;
@property (nonatomic) OutlineScene* scene;
@property (nonatomic) bool dark;
@end

@implementation OutlineItemProvider

- (instancetype)initWithScene:(OutlineScene*)scene dark:(bool)dark
{
    self = [super init];
    if (self) {
        _scene = scene;
        _dark = dark;
        
        BeatUserDefaults* d = BeatUserDefaults.sharedDefaults;
        OutlineItemOptions options = 0;
        if ([d getBool:BeatSettingShowHeadingsInOutline]) options |= OutlineItemIncludeHeading;
        if ([d getBool:BeatSettingShowSceneNumbers]) options |= OutlineItemIncludeSceneNumber;
        if ([d getBool:BeatSettingShowNotesInOutline]) options |= OutlineItemIncludeNotes;
        if ([d getBool:BeatSettingShowSynopsisInOutline]) options |= OutlineItemIncludeSynopsis;
        if ([d getBool:BeatSettingShowMarkersInOutline]) options |= OutlineItemIncludeMarkers;
        
        _options = options;
    }
    return self;
}

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

+ (BXColor*)elementColor:(OutlineElementType)type dark:(BOOL)dark
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

- (NSArray<BeatOutlineItemData*>*)items
{
    NSMutableArray<BeatOutlineItemData*>* items = [NSMutableArray.alloc initWithCapacity:15];
    if (mask_contains(_options, OutlineItemIncludeNotes))
        [items addObjectsFromArray:self.notes];
    if (mask_contains(_options, OutlineItemIncludeMarkers))
        [items addObjectsFromArray:self.markers];
    if (mask_contains(_options, OutlineItemIncludeSynopsis))
        [items addObjectsFromArray:self.synopses];
    
    return items;
}

- (NSAttributedString*)heading
{
    Line *line = _scene.line;
    if (line == nil) return NSMutableAttributedString.new;
    
    NSMutableAttributedString *resultString = NSMutableAttributedString.new;
    
    bool includeHeading = (_options & OutlineItemIncludeHeading) != 0;
    NSString* rawString = @"";
    
    // Handle section headings when headings are *not* included
    if (!(_scene.type == heading && !includeHeading)) {
        rawString = [_scene.stringForDisplay stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        rawString = [rawString stringByReplacingOccurrencesOfString:@"*" withString:@"" options:0 range:NSMakeRange(0, rawString.length)];
    }
    
    NSString *string = rawString;
    
    // Set item color
    BXColor *itemColor;
    if (line.color && !line.omitted) itemColor = [BeatColors color:line.color];
    
    // Style the item
    if (line.type == heading) {
        CGFloat fontSize = [OutlineItemProvider fontSizeForType:line.type];
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
        bool includeSceneNumber = (_options & OutlineItemIncludeSceneNumber) != 0;
        NSString *sceneNumber = (!line.omitted && includeSceneNumber) ? [NSString stringWithFormat:@"%@. ", line.sceneNumber] : @"";
        NSAttributedString *header = [NSAttributedString.alloc initWithString:sceneNumber attributes:@{
            NSForegroundColorAttributeName: [OutlineItemProvider elementColor:OutlineElementTypeSceneNumber dark:_dark],
            NSFontAttributeName: font
        }];
        
        BXColor *sceneColor = (itemColor != nil) ? itemColor : [OutlineItemProvider elementColor:OutlineElementTypeDefault dark:_dark];
        
        NSAttributedString *body = [NSAttributedString.alloc initWithString:string attributes:@{
            NSForegroundColorAttributeName: (!line.omitted) ? sceneColor : [OutlineItemProvider elementColor:OutlineElementTypeOmitted dark:_dark],
            NSFontAttributeName: font
        }];
        
        [resultString appendAttributedString:header];
        [resultString appendAttributedString:body];
    } else if (line.type == section && string.length > 0) {
        CGFloat fontSize = [OutlineItemProvider fontSizeForType:line.type];
        BXFont *font = [BXFont systemFontOfSize:fontSize weight:BXFontWeightBold];
        
        BXColor *color = (itemColor != nil) ? itemColor : [OutlineItemProvider elementColor:OutlineElementTypeSection dark:_dark];
        resultString = [[NSMutableAttributedString alloc] initWithString:(string) ? string : @"" attributes:@{
            NSForegroundColorAttributeName: color,
            NSFontAttributeName: font
        }];
    }
    
    return resultString;
}

- (NSArray<BeatOutlineItemData*>*)synopses
{
    CGFloat fontSize = [OutlineItemProvider fontSizeForType:synopse];
    NSMutableParagraphStyle *synopsisStyle = NSMutableParagraphStyle.new;
    synopsisStyle.lineSpacing = .65;
    synopsisStyle.paragraphSpacingBefore = 4.0;
    
    NSMutableArray* items = [NSMutableArray.alloc initWithCapacity:_scene.synopsis.count];
    
    for (Line* synopsis in _scene.synopsis) {
        NSString *synopsisStr = [NSString stringWithFormat:@"• %@", synopsis.stripFormatting];
        BXColor *synopsisColor;
        
        if (synopsis.color.length > 0) synopsisColor = [BeatColors color:synopsis.color];
        if (synopsisColor == nil) synopsisColor = [OutlineItemProvider elementColor:OutlineElementTypeSynopsis dark:_dark];
        
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
        
        BeatOutlineItemData* item = [BeatOutlineItemData.alloc initWithText:synopsisLine line:synopsis range:synopsis.range];
        [items addObject:item];
    }
    
    return items;
}

- (NSArray<BeatOutlineItemData*>*)notes
{
    CGFloat fontSize = [OutlineItemProvider fontSizeForType:action];
    BXFont* noteFont = [BXFont systemFontOfSize:fontSize];
    
    NSMutableParagraphStyle *noteStyle = NSMutableParagraphStyle.new;
    noteStyle.lineSpacing = .65;
    noteStyle.paragraphSpacingBefore = 5.0;
    
    NSMutableArray<BeatOutlineItemData*>* items = [NSMutableArray.alloc initWithCapacity:self.scene.notes.count];
    
    for (BeatNoteData* note in self.scene.notes) {
        if (note.content.length == 0 ||
            NSIntersectionRange(note.range, self.scene.line.colorRange).length == note.range.length ||
             note.type != NoteTypeNormal)
            continue;
        
        NSString* noteStr = [NSString stringWithFormat:@"✎ %@", note.content];
        
        BXColor* noteColor = [OutlineItemProvider elementColor:OutlineElementTypeNote dark:_dark];
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
        
        BeatOutlineItemData* item = [BeatOutlineItemData.alloc initWithText:noteLine line:note.line range:note.range];
        
        [items addObject:item];
    }
    
    return items;
}

- (NSArray<BeatOutlineItemData*>*)markers
{
    CGFloat fontSize = [OutlineItemProvider fontSizeForType:action];
    NSMutableParagraphStyle *markerStyle = NSMutableParagraphStyle.new;
    markerStyle.lineSpacing = .65;
    markerStyle.paragraphSpacingBefore = 4.0;
    
    NSMutableArray<BeatOutlineItemData*>* items = [NSMutableArray.alloc initWithCapacity:self.scene.markers.count];
    
    for (NSDictionary* marker in self.scene.markers) {
        NSString* colorName = marker[@"color"];
        
        BXColor* color = (colorName.length > 0) ? [BeatColors color:colorName] : nil;
        if (color == nil) color = [BeatColors color:@"orange"];
        
        NSString* description = [NSString stringWithFormat:@" %@", marker[@"description"]];
        NSArray* blocks = @[
            //[AttributedBlock.alloc initWithType:AttributedBlockTypeText value:@"\n"],
            [AttributedBlock.alloc initWithType:AttributedBlockTypeSymbol value:@"bookmark.fill"],
            [AttributedBlock.alloc initWithType:AttributedBlockTypeText value:description],
        ];
        
        NSAttributedString* aStr = [NSAttributedString createWithBlocks:blocks font:[BXFont systemFontOfSize:fontSize] textColor:color symbolColor:color paragraphStyle:markerStyle];
        
        Line* line = ((NSValue*)marker[@"line"]).nonretainedObjectValue;
        
        NSRange globalRange = ((NSValue*)marker[@"globalRange"]).rangeValue;
        BeatOutlineItemData* item = [BeatOutlineItemData.alloc initWithText:aStr line:line range:globalRange];
        
        [items addObject:item];
    }
    
    return items;
}

@end
