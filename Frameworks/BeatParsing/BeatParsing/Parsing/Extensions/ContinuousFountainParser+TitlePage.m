//
//  ContinuousFountainParser+TitlePage.m
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 19.1.2026.
//

#import "ContinuousFountainParser+TitlePage.h"
#import <BeatParsing/BeatParsing-Swift.h>

@implementation ContinuousFountainParser (TitlePage)

#pragma mark - Parses a single line of title page

/// I don't understand any of this.
- (LineType)parseTitlePageLineTypeFor:(Line*)line previousLine:(Line*)previousLine lineIndex:(NSInteger)index
{
    NSString *key = line.titlePageKey;
    
    if (key.length > 0) {
        // This is a keyed title page line (Title: Something)
        NSString* value = line.titlePageValue;
        if (value == nil) value = @"";
        
        // Store title page data
        NSMutableDictionary *titlePageData = @{ key: [NSMutableArray arrayWithObject:value] }.mutableCopy;
        [self.titlePage addObject:titlePageData];
        
        // Set this key as open (in case there are additional title page lines)
        self.openTitlePageKey = key;
        
        if ([key isEqualToString:@"title"]) {
            return titlePageTitle;
        } else if ([key isEqualToString:@"author"] || [key isEqualToString:@"authors"]) {
            return titlePageAuthor;
        } else if ([key isEqualToString:@"credit"]) {
            return titlePageCredit;
        } else if ([key isEqualToString:@"source"]) {
            return titlePageSource;
        } else if ([key isEqualToString:@"contact"]) {
            return titlePageContact;
        } else if ([key isEqualToString:@"contacts"]) {
            return titlePageContact;
        } else if ([key isEqualToString:@"contact info"]) {
            return titlePageContact;
        } else if ([key isEqualToString:@"draft date"]) {
            return titlePageDraftDate;
        } else {
            return titlePageUnknown;
        }
    } else if (previousLine.isTitlePage) {
        // This is a non-keyed title page line and part of a title page block
        NSString *key = @"";
        NSInteger i = index - 1;
        while (i >= 0) {
            Line *pl = self.lines[i];
            if (pl.titlePageKey.length > 0) {
                key = pl.titlePageKey;
                break;
            }
            i -= 1;
        }
        if (key.length > 0) {
            NSMutableDictionary* dict = self.titlePage.lastObject;
            [(NSMutableArray*)dict[key] addObject:line.string];
        }
        
        return previousLine.type;
    }
    
    return NSNotFound;
}


#pragma mark - Title page data getters

/// Returns the title page lines as string
- (NSString*)titlePageAsString
{
    NSMutableString *string = NSMutableString.new;
    for (Line* line in self.safeLines) {
        if (!line.isTitlePage) break;
        [string appendFormat:@"%@\n", line.string];
    }
    return string;
}

/// Returns just the title page lines
- (NSArray<Line*>*)titlePageLines
{
    NSMutableArray *lines = NSMutableArray.new;
    for (Line* line in self.safeLines) {
        if (!line.isTitlePage) break;
        [lines addObject:line];
    }
    
    return lines;
}

/// Re-parses the title page and returns a weird array structure: `[ { "key": "value }, { "key": "value }, { "key": "value } ]`.
/// This is because we want to maintain the order of the keys, and though ObjC dictionaries sometimes stay in the correct order, things don't work like that in Swift.
/// TODO: This should be replaced by some kind struct-like objects instead of dictionary array silliness.
- (NSArray<NSDictionary<NSString*,NSArray<Line*>*>*>*)parseTitlePage
{
    [self.titlePage removeAllObjects];
    
    // Store the latest key
    NSString *key = @"";
    BeatMacroParser* titlePageMacros = BeatMacroParser.new;
    
    // Iterate through lines and break when we encounter a non- title page line
    for (Line* line in self.safeLines) {
        if (!line.isTitlePage) break;
        
        [self resolveMacrosOn:line parser:titlePageMacros];
        
        // Reset flags
        line.beginsTitlePageBlock = false;
        line.endsTitlePageBlock = false;
        
        // Determine if the line is empty
        bool empty = false;
        
        // See if there is a key present on the line ("Title: ..." -> "Title")
        if (line.titlePageKey.length > 0) {
            key = line.titlePageKey.lowercaseString;
            if ([key isEqualToString:@"author"]) key = @"authors";
            
            line.beginsTitlePageBlock = true;
            
            NSMutableDictionary* titlePageValue = [NSMutableDictionary dictionaryWithDictionary:@{ key: NSMutableArray.new }];
            [self.titlePage addObject:titlePageValue];
            
            // Add the line into the items of the current line, IF IT'S NOT EMPTY
            NSString* trimmed = [line.string substringFromIndex:line.titlePageKey.length+1].trim;
            if (trimmed.length == 0) empty = true;
        }
        
        // Find the correct item in an array of dictionaries
        // [ { "title": [Line] } , { ... }, ... ]
        NSMutableArray *items = [self titlePageArrayForKey:key];
        if (items == nil) continue;
        
        // Add the line if it's not empty
        if (!empty) [items addObject:line];
    }
    
    // After we've gathered all the elements, lets iterate them once more to determine where blocks end.
    for (NSDictionary<NSString*,NSArray<Line*>*>* element in self.titlePage) {
        NSArray<Line*>* lines = element.allValues.firstObject;
        Line* firstLine = lines.firstObject;
        Line* lastLine = lines.lastObject;
        
        // I've seen a weird issue with NSStrings being inserted here. No idea how and why, but… yeah. This is an emergency fix.
        if ([firstLine isKindOfClass:Line.class])
            firstLine.beginsTitlePageBlock = true;
        if ([lastLine isKindOfClass:Line.class])
            lastLine.endsTitlePageBlock = true;
    }
    
    return self.titlePage;
}

/// Returns the lines for given title page key. For example,`Title` would return something like `["My Film"]`.
- (NSMutableArray<Line*>*)titlePageArrayForKey:(NSString*)key
{
    for (NSMutableDictionary* d in self.titlePage) {
        if ([d.allKeys.firstObject isEqualToString:key]) return d[d.allKeys.firstObject];
    }
    return nil;
}

@end
/*
 
 On totta: minä ansaitsen vielä leipäni
 mutta uskokaa minua: se on vain sattumaa
 Ei mikään siitä, mitä teen, oikeuta minua syömään itseäni kylläiseksi.
 Olen säästynyt sattumalta. (Kun onni pettää, minä olen hukassa!)
  
 Minulle sanotaan: Syö ja juo! Ole iloinen, että sinulla on!
 Mutta miten minä voin syödä ja juoda, kun
 riistän ruokani nälkäiseltä, ja
 janoinen on vailla vettä jonka minä juon
 … ja kuitenkin minä syön ja juon
 
 */
