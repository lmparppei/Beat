//
//  BeatNotepad.m
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 15.8.2024.
//
/*
 
 This is a cross-platform implementation of notepad. Might work. Or not.
 You need to create OS-specific implementations for both systems, because there's no cross-platform way to use didChangeText I guess.
 
 */

#import "BeatNotepad.h"
#import <BeatCore/BeatCompatibility.h>
#import <BeatCore/BeatColors.h>
#import <BeatCore/BeatCore-Swift.h>

@interface BeatNotepad() <BeatEditorView> {
    bool awoken;
}
@property (nonatomic) BeatMarkdownTextStorageDelegate* mdDelegate;
@property (nonatomic) bool loading;
@end

@implementation BeatNotepad

- (void)awakeFromNib
{
    [super awakeFromNib];
    if (!awoken) {
        [self setColor:@"default"];
        
        CGFloat fontSize = (self.baseFontSize > 0) ? self.baseFontSize : 12.0;
        
        self.mdDelegate = [BeatMarkdownTextStorageDelegate.alloc initWithFontSize:fontSize];
        self.mdDelegate.textStorage = self.textStorage;
        self.textStorage.delegate = self.mdDelegate;
        
        self.textColor = self.currentColor;
        awoken = true;
    }
}

- (void)setup
{
#if TARGET_OS_OSX
    [self.editorDelegate registerEditorView:self];
#endif
    _loading = true;
        
    NSString* notes = [self.editorDelegate.documentSettings getString:@"Notes"];
    if (notes.length > 0) [self loadString:notes];
    else [self setString:@""];
    _loading = false;
}


#pragma mark - Loading and storing text

#if TARGET_OS_IOS
- (NSString*)string { return self.text; }
#else
- (NSString*)text { return self.string; }
- (void)setText:(NSString*)text { [self setString:text]; }
#endif

- (void)setString:(NSString *)string
{
#if TARGET_OS_OSX
    [super setString:string];
#else
    [super setText:string];
#endif
    if (!_loading) [self saveToDocument];
}

/// Alias for iOS
//- (NSString*)text { return self.string; }
/// Alias for iOS
//- (void)setText:(NSString *)text { [self setString:text]; }

-(void)loadString:(NSString*)string
{
    [self.textStorage setAttributedString:[self coloredRanges:string]];
    [self textViewNeedsDisplay];
}

- (NSAttributedString*)coloredRanges:(NSString*)fullString
{
    // Iterate through <colorName>...</colorName>, add colors to tagged ranges,
    // and afterwards remove the tags enumerating the index set which contains ranges for tags.
    
    NSMutableAttributedString *attrStr = [NSMutableAttributedString.alloc initWithString:fullString];
    [attrStr addAttribute:NSForegroundColorAttributeName value:self.currentColor range:(NSRange){ 0, attrStr.length }];
    
    NSMutableIndexSet *keyRanges = NSMutableIndexSet.new;
    
    for (NSString *color in BeatColors.colors.allKeys) {
        BXColor* colorObj = [BeatColors color:color];
        
        NSString *open = [NSString stringWithFormat:@"<%@>", color];
        NSString *close = [NSString stringWithFormat:@"</%@>", color];
        
        NSInteger prevLoc = 0;
        NSRange openRange;
        NSRange closeRange = NSMakeRange(0, 0);
        
        do {
            openRange = [attrStr.string rangeOfString:open options:0 range:NSMakeRange(prevLoc, attrStr.length - prevLoc)];
            if (openRange.location == NSNotFound) continue;
            
            closeRange = [attrStr.string rangeOfString:close options:0 range:NSMakeRange(prevLoc, attrStr.length - prevLoc)];
            if (closeRange.location == NSNotFound) continue;
            
            [attrStr addAttribute:NSForegroundColorAttributeName value:colorObj range:(NSRange){ openRange.location, NSMaxRange(closeRange) - openRange.location }];
            
            [keyRanges addIndexesInRange:openRange];
            [keyRanges addIndexesInRange:closeRange];
            
            prevLoc = NSMaxRange(closeRange);
        } while (openRange.location != NSNotFound && closeRange.location != NSNotFound);
        
    }
    
    // Create an index set with full string
    NSMutableIndexSet *visibleIndices = [NSMutableIndexSet.alloc initWithIndexesInRange:NSMakeRange(0, attrStr.length)];
    [keyRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
        [visibleIndices removeIndexesInRange:range];
    }];
    
    NSMutableAttributedString *result = NSMutableAttributedString.new;
    [visibleIndices enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
        [result appendAttributedString:[attrStr attributedSubstringFromRange:range]];
    }];
    
    return result;
}

- (void)setColor:(NSString*)colorName
{
    self.currentColorName = colorName;
    
    if ([colorName isEqualToString:@"default"]) {
        self.currentColor = (BXColor*)self.defaultColor;
    } else {
        self.currentColor = [BeatColors color:colorName];
    }
    
    NSMutableDictionary* attrs = self.typingAttributes.mutableCopy;
    attrs[NSForegroundColorAttributeName] = self.currentColor;
    [self setTypingAttributes:attrs];
    
#if TARGET_OS_IOS
    
    //self.typingAttributes[NSForegroundColorAttributeName] = self.currentColor;
#endif
}

- (void)saveToDocument
{
    [self.editorDelegate.documentSettings set:@"Notes" as:self.stringForSaving];
    if (!self.editorDelegate.documentIsLoading) [self.editorDelegate addToChangeCount];
}

- (NSString*)stringForSaving
{
    NSMutableString *result = [NSMutableString.alloc initWithString:@""];
    [self.textStorage enumerateAttributesInRange:NSMakeRange(0, self.textStorage.length) options:0 usingBlock:^(NSDictionary<NSAttributedStringKey,id> * _Nonnull attrs, NSRange range, BOOL * _Nonnull stop) {
        DynamicColor* color = attrs[NSForegroundColorAttributeName];
        NSString* string = [self.string substringWithRange:range];
        
        if (color != self.defaultColor) {
            NSString *colorTag;
            for (NSString *colorName in BeatColors.colors.allKeys) {
                if (BeatColors.colors[colorName] == color) {
                    colorTag = colorName;
                    break;
                }
            }
            
            if (colorTag != nil) string = [NSString stringWithFormat:@"<%@>%@</%@>", colorTag, string, colorTag];
        }
        
        [result appendString:string];
    }];
    /*
     [self.attributedString enumerateAttribute:NSForegroundColorAttributeName inRange:(NSRange){0,self.string.length} options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
     
     NSString* string = [self.string substringWithRange:range];
     
     // Do nothing for default color
     if (value != self.defaultColor) {
     NSString *colorTag;
     for (NSString *colorName in BeatColors.colors.allKeys) {
     if (BeatColors.colors[colorName] == value) {
     colorTag = colorName;
     break;
     }
     }
     
     if (colorTag) string = [NSString stringWithFormat:@"<%@>%@</%@>", colorTag, string, colorTag];
     }
     
     [result appendString:string];
     }];
     */
    return result;
}

#pragma mark - Text I/O

-(void)didChangeText
{
#if TARGET_OS_OSX
    [super didChangeText];
#endif
    // Save contents into document settings
    if (!self.editorDelegate.documentIsLoading) [self saveToDocument];
}

- (void)replaceRange:(NSInteger)position length:(NSInteger)length string:(NSString*)string color:(NSString*)colorName
{
    NSRange range = NSMakeRange(position, length);
    if (NSMaxRange(range) > self.string.length) return;
    
    BXColor* color;
    if (colorName.length > 0) color = [BeatColors color:colorName];
    if (color == nil) color = self.currentColor;
    
    NSAttributedString* result = [NSAttributedString.alloc initWithString:string attributes:@{
        NSForegroundColorAttributeName: color
    }];
    
    bool shouldChange = false;
    
#if TARGET_OS_OSX
    shouldChange = [self shouldChangeTextInRange:range replacementString:string];
#else
    UITextRange* textRange = [self textRangeFrom:range];
    shouldChange = [self shouldChangeTextInRange:textRange replacementText:string];
#endif
    
    if (shouldChange) {
        [self.textStorage beginEditing];
        [self.textStorage replaceCharactersInRange:range withAttributedString:result];
        [self.textStorage endEditing];
        
        [self didChangeText];
    }
}

- (void)setSelectedRange:(NSRange)selectedRange
{
    if (NSMaxRange(selectedRange) > self.text.length) return;
    [super setSelectedRange:selectedRange];
}


#pragma mark - Editor view conformance (macOS)

- (void)reloadInBackground { }

- (void)reloadView { }

-(bool)visible
{
    NSLog(@"!!! Override notepad visibility check in OS-specific implementation");
    return false;
}


@end
