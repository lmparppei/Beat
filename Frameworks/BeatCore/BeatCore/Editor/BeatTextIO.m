//
//  BeatTextIO.m
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 18.2.2023.
//
/**
 
 Common editor text manipulation methods for both macOS and iOS.
 Note that the OSs work differently when adding/removing text. On iOS, the cursor has to be readjusted after each operation.
 
 */

#import "BeatTextIO.h"
#import <BeatParsing/Line+Storybeats.h>
#import <BeatCore/BeatAttributes.h>
#import <BeatCore/BeatCore-Swift.h>
#import <TargetConditionals.h>
#import <BeatParsing/BeatParsing.h>
#import "BeatUserDefaults.h"


@interface BeatTextIO()
@property (nonatomic) bool skipAutomaticLineBreaks;
@end

@implementation BeatTextIO

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
static NSString *forceTransitionLineSymbol = @">";
static NSString *forceLyricsSymbol = @"~";
static NSString *forceDualDialogueSymbol = @"^";

static NSString *centeredStart = @"> ";
static NSString *centeredEnd = @" <";


-(instancetype)initWithDelegate:(id<BeatTextIODelegate>)delegate {
    self = [super init];
    if (self) {
        self.delegate = delegate;
    }
    return self;
}

- (BXTextView*)textView
{
    return self.delegate.getTextView;
}

#pragma mark - iOS weirdness fix

/// Restores caret position after changing something in the text view.
/// @note Does nothing on macOS.
- (void)restorePositionForChangeAt:(NSInteger)index length:(NSInteger)length originalRange:(NSRange)range {
#if TARGET_OS_IOS
    // We'll only do this on iOS
    
    if (range.location < index) {
        self.delegate.selectedRange = NSMakeRange(range.location, 0);
    } else {
        NSRange newSelection = NSMakeRange(range.location + length, range.length);
        if (NSMaxRange(range) > self.delegate.text.length) {
            newSelection.length = self.delegate.text.length - newSelection.location;
        }
        
        self.delegate.selectedRange = newSelection;
    }
#endif
}

#pragma mark - Text I/O

/**
 Main method for adding text to editor view.  Forces added text to be parsed, but does NOT invoke undo manager.
 @warning __Don't use__ this for adding text. Go through the intermediate methods instead, `addString`, `removeString` etc.
 */
- (void)replaceCharactersInRange:(NSRange)range withString:(NSString*)string
{
    BXTextView* textView = self.textView;
    
    if (NSMaxRange(range) > textView.text.length) {
        if (range.length == 0) {
            range = NSMakeRange(textView.text.length, 0);
        } else {
            NSInteger loc = MIN(textView.text.length, range.location);
            NSInteger len = textView.text.length - loc;
            range = NSMakeRange(loc, len);
        }
    }

    // If range is over bounds (this can happen with certain undo operations for some reason), let's fix it
    if (range.length + range.location > _delegate.text.length) {
        NSInteger length = _delegate.text.length - range.location;
        range = NSMakeRange(range.location, length);
    }
    
    // Text view fires up shouldChangeTextInRange only when the text is changed by the user.
    // When replacing stuff directly in the view, we need to call it manually.
    
#if TARGET_OS_IOS
    if ([self.delegate textView:textView shouldChangeTextInRange:range replacementString:string]) {
        UITextRange *oldRange = textView.selectedTextRange;
        [self.delegate setSelectedRange:range];
        
        UITextRange *textRange = textView.selectedTextRange;
        [self.textView setSelectedTextRange:oldRange];
        
        [textView replaceRange:textRange withText:string];
        if (textView.textStorage.isEditing) [textView.textStorage endEditing];
        //[self.delegate textDidChange:[NSNotification notificationWithName:@"" object:nil]];
    }
#else
    if ([self.delegate textView:textView shouldChangeTextInRange:range replacementString:string]) {
        [textView replaceCharactersInRange:range withString:string];
        [self.delegate textDidChange:[NSNotification notificationWithName:@"" object:nil]];
    }
#endif
    
}

/// Adds a string at the given index.
- (void)addString:(NSString*)string atIndex:(NSUInteger)index
{
    [self addString:string atIndex:index skipAutomaticLineBreaks:false];
}
/// Adds a string at the given index. When adding text with line breaks, you can skip automatic line breaks.
- (void)addString:(NSString*)string atIndex:(NSUInteger)index skipAutomaticLineBreaks:(bool)skipLineBreaks
{
    NSRange selectedRange = _delegate.selectedRange;
    
    _skipAutomaticLineBreaks = skipLineBreaks;
    [self replaceCharactersInRange:NSMakeRange(index, 0) withString:string];
    _skipAutomaticLineBreaks = false;
    
#if !TARGET_OS_IOS
    // I don't know why, but we shouldn't invoke undo manager on iOS
    [[_delegate.undoManager prepareWithInvocationTarget:self] removeRange:NSMakeRange(index, string.length)];
#endif
    
    // Restore position on iOS
    [self restorePositionForChangeAt:index length:string.length originalRange:selectedRange];
}


/// Removes a range. This is here for backwards-compatibility.
- (void)removeAt:(NSUInteger)index length:(NSUInteger)length {
    [self replaceRange:NSMakeRange(index, length) withString:@""];
}

/// Replaces text in a range with another string.
- (void)replaceRange:(NSRange)range withString:(NSString*)newString
{
    NSRange selectedRange = _delegate.selectedRange;
    
    // Remove unnecessary line breaks
    newString = [newString stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"];
    
    [self.delegate.getTextView.textStorage beginEditing];
    
    // Replace with undo registration
    NSString *oldString = [_delegate.text substringWithRange:range];
    
    [self replaceCharactersInRange:range withString:newString];
    [self.delegate.getTextView.textStorage endEditing];
    
#if TARGET_OS_OSX
    // We shouldn't invoke undo manager on iOS
    [[_delegate.undoManager prepareWithInvocationTarget:self] replaceString:newString withString:oldString atIndex:range.location];
#endif
    
    // Restore position on iOS
    [self restorePositionForChangeAt:range.location length:newString.length - range.length originalRange:selectedRange];
}

/// Replaces the given string with another string at given index. A convenience method, I guess.
- (void)replaceString:(NSString*)string withString:(NSString*)newString atIndex:(NSUInteger)index
{
    [self replaceRange:NSMakeRange(index, string.length) withString:newString];
}

/// Removes given range.
- (void)removeRange:(NSRange)range
{
    [self replaceRange:range withString:@""];
}

/// Moves the given string in a range to another position. You can provide another string to mutate the string before moving.
- (void)moveStringFrom:(NSRange)range to:(NSInteger)position actualString:(NSString*)string
{
    NSString *oldString = [_delegate.text substringWithRange:range];
    
    NSString *stringToMove = string;
    NSInteger length = _delegate.text.length;
    
    if (position > length) position = length;
    
    [self replaceCharactersInRange:range withString:@""];
    
    NSInteger newPosition = position;
    if (range.location < position) {
        newPosition = position - range.length;
    }
    if (newPosition < 0) newPosition = 0;
    
    [self replaceCharactersInRange:NSMakeRange(newPosition, 0) withString:stringToMove];
    
    NSRange undoingRange;
    NSInteger undoPosition;
    
    if (range.location > position) {
        undoPosition = range.location + stringToMove.length;
        undoingRange = NSMakeRange(position, stringToMove.length);
    } else {
        undoingRange = NSMakeRange(newPosition, stringToMove.length);
        undoPosition = range.location;
    }
    
    [[_delegate.undoManager prepareWithInvocationTarget:self] moveStringFrom:undoingRange to:undoPosition actualString:oldString];
    [_delegate.undoManager setActionName:@"Move Scene"];
}

/// Moves given range to another position
- (void)moveStringFrom:(NSRange)range to:(NSInteger)position
{
    NSString *stringToMove = [_delegate.text substringWithRange:range];
    [self moveStringFrom:range to:position actualString:stringToMove];
}

- (void)moveScene:(OutlineScene*)scene from:(NSInteger)from to:(NSInteger)to
{
    OutlineScene* target = (to < _delegate.parser.outline.count) ? _delegate.parser.outline[to] : nil;
    OutlineScene* nextScene = (from < _delegate.parser.outline.count - 1) ? _delegate.parser.outline[from+1] : nil;
    
    NSRange range = scene.range;
    bool closeOmit = false, closeOmitInString = false, openOmit = false, movedMidOmission = false;
    
    if (scene.omitted) {
        // Let's make note if we're breaking a longer omission
        if (nextScene.omitted) openOmit = true;
        
        NSInteger p = [_delegate.parser findSceneOmissionStartFor:scene];
        if (p == NSNotFound) {
            closeOmit = true;
        } else {
            range.length += range.location - p;
            range.location = p;
        }
    } else if (nextScene.omitted) {
        // If *next scene* is omitted (but current isn't) let's find out where the omission starts.
        NSInteger p = [_delegate.parser findOmissionStartFrom:nextScene.position];
        NSRange gapRange = NSMakeRange(p, nextScene.position - p);
        NSString* gap = [[_delegate.text substringWithRange:gapRange] stringByTrimmingTrailingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    
        if ([gap isEqualToString:@"/*"]) {
            // This omit is just for the next scene. Remove the gap from range.
            range.length -= NSMaxRange(range) - p;
        } else {
            // For some reason the user began omission mid-scene. Omit next scene and close omission in this scene.
            openOmit = true;
            closeOmitInString = true;
        }
    }
    
    if (target.omitted) movedMidOmission = true;

    NSString* string = [_delegate.text substringWithRange:range];
    if (string.length == 0) return;
    
    // Create the replacement string for the scene according to omissions
    NSString* replace = @"";
    if (closeOmit) {
        replace = @"*/\n\n";
        string = [@"/*\n" stringByAppendingString:string];
        if (![string containsString:@"*/"]) string = [string stringByAppendingString:@"\n*/"];
    }
    if (openOmit) {
        replace = [replace stringByAppendingString:@"\n/*\n"];
    }
    if (closeOmitInString) {
        string = [string stringByAppendingString:@"*/"];
    }
    if (movedMidOmission && !scene.omitted) {
        string = [NSString stringWithFormat:@"*/\n\n%@/*", string];
    }
        
    // Replace scene range
    [self replaceRange:range withString:replace];
    NSInteger targetPosition = 0;
    
    if (target == nil) {
        // Add at the end
        Line* lastLine = _delegate.parser.lines.lastObject;
        // Add a line break if needed
        if (lastLine.length > 0) string = [@"\n\n" stringByAppendingString:string];
        
        targetPosition = _delegate.text.length;
    } else {
        if ([string characterAtIndex:string.length-1] != '\n') {
            string = [string stringByAppendingString:@"\n\n"];
        }
        
        targetPosition = target.position;
    }
    
    [self addString:string atIndex:targetPosition];
}

- (void)moveScenesInRange:(NSRange)range to:(NSInteger)position
{
    if (range.length == 0 || NSMaxRange(range) > self.delegate.text.length) return;
    
    NSString* string = [self.delegate.text substringWithRange:range];
    
    Line* lastLine = [self.delegate.parser lineAtPosition:NSMaxRange(range)];
    // Add line breaks if needed
    if (lastLine.type == section && [string characterAtIndex:string.length-1] != '\n') [string stringByAppendingString:@"\n"];
    else if (lastLine.type != empty || lastLine.length > 0) string = [string stringByAppendingString:@"\n"];

    [self moveStringFrom:range to:position actualString:string];
}

/// Removes text on the given line in its LOCAL range instead of global range.
- (void)removeTextOnLine:(Line*)line inLocalIndexSet:(NSIndexSet*)indexSet {
    __block NSUInteger offset = 0;
    [indexSet enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
        // Remove beats on any line
        NSRange globalRange = [line globalRangeFromLocal:range];
        [self removeRange:(NSRange){ globalRange.location - offset, globalRange.length }];
        offset += range.length;
    }];
}

/// Adds a character extension. The line *has* to be a character.
- (void)addCueExtension:(NSString*)extension onLine:(Line*)line
{
    if (line == nil) line = _delegate.currentLine;
    if (!line.isAnyCharacter || line.length == 0) return;
    
    NSString* str = [NSString stringWithFormat:@"%@%@", (line.lastCharacter != ' ') ? @" " : @"", extension];
    
    if (line.type == character) [self addString:str atIndex:NSMaxRange(_delegate.currentLine.textRange)];
    else if (line.type == dualDialogueCharacter) [self addString:str atIndex:NSMaxRange(_delegate.currentLine.textRange) - 1]; // Keep the ^ for DD cues
}


#pragma mark - Add text with Beat attributes

/// Adds an attributed string to text view. Only accepts Beat attributes.
- (void)replaceRange:(NSRange)range withAttributedString:(NSAttributedString *)attrString
{
    NSMutableAttributedString* newString = [NSMutableAttributedString.alloc initWithString:attrString.string];
    
    // Enumerate custom attributes
    [attrString enumerateAttributesInRange:NSMakeRange(0, attrString.length) options:0 usingBlock:^(NSDictionary<NSAttributedStringKey,id> * _Nonnull attrs, NSRange range, BOOL * _Nonnull stop) {
        // If no custom attributes are found, just skip
        if (![BeatAttributes containsCustomAttributes:attrs]) return;
        
        // Only spare our custom, registered attributes
        NSDictionary* customAttrs = [BeatAttributes stripUnnecessaryAttributesFrom:attrs];
        [newString addAttributes:customAttrs range:NSMakeRange(range.location, range.length)];
    }];

    if ([self.delegate textView:self.textView shouldChangeTextInRange:range replacementString:newString.string]) {
        NSAttributedString* oldString = [self.textView.textStorage attributedSubstringFromRange:range];
        
        [self.textView.textStorage beginEditing];
        [self.textView.textStorage replaceCharactersInRange:range withAttributedString:newString];
        [self.textView.textStorage endEditing];
#if TARGET_OS_OSX
        [self.textView didChangeText];
#endif
        
        [[_delegate.undoManager prepareWithInvocationTarget:self] replaceRange:NSMakeRange(range.location, newString.length) withAttributedString:oldString];
    }

}


#pragma mark - Additional editor convenience stuff

/// Checks if we should add additional line breaks. Returns `true` if line breaks were added.
/// @warning: Do **NOT** add a *single* line break here, because you'll end up with an infinite loop.
- (bool)shouldAddLineBreaks:(Line*)currentLine range:(NSRange)affectedCharRange
{
    bool prevent = false;
    if ([BeatUserDefaults.sharedDefaults getBool:BeatSettingAutomaticLineBreaks] == false ||
        _delegate.editorStyles.document.disableAutomaticParagraphs) {
        // Check if automatic paragraphs are disabled either in settings or in styles
        prevent = true;
    } else if (_skipAutomaticLineBreaks) {
        // Some methods can opt out of this behavior. Reset the flag once it's been used.
        _skipAutomaticLineBreaks = false;
        prevent = true;
    }
    // Prevent default
    if (prevent) return false;
    
    
    // Don't add a dual line break if shift is pressed
    NSUInteger currentIndex = [_delegate.parser indexOfLine:currentLine];
    
    // Handle lines with content
    bool shiftPressed = false;
    
#if TARGET_OS_OSX
    // On macOS, pressing shift will avoid adding an extra line break
    shiftPressed = (NSEvent.modifierFlags & NSEventModifierFlagShift);
#else
    shiftPressed = self.delegate.inputModifierFlags & UIKeyModifierShift;
#endif
    
    
    if (currentLine.string.length > 0 && !shiftPressed) {
        // Add double breaks for outline element lines
        if (currentLine.isOutlineElement || currentLine.isAnyDialogue) {
            [self addString:@"\n\n" atIndex:affectedCharRange.location];
            return YES;
        } else if (currentLine.type == action) {
            // Action lines need to perform some checks
            // Perform a double-check if there is a next line
            if (currentIndex + 1 < _delegate.parser.lines.count && currentIndex != NSNotFound) {
                Line* nextLine = _delegate.parser.lines[currentIndex + 1];
                if (nextLine.string.length == 0) {
                    // If it *might* be a character cue, skip this behavior.
                    if (currentLine.string.onlyUppercaseUntilParenthesis) return NO;
                    // Otherwise add dual line break
                    [self addString:@"\n\n" atIndex:affectedCharRange.location];
                    return YES;
                }
            } else {
                [self addString:@"\n\n" atIndex:affectedCharRange.location];
                return YES;
            }
        }
    } else if (currentLine.string.length == 0) {
        Line *prevLine = [_delegate.parser previousLine:currentLine];
        Line *nextLine = [_delegate.parser nextLine:currentLine];
        
        // Add a line break above and below when writing something in between two dialogue blocks
        if ((prevLine.isDialogueElement || prevLine.isDualDialogueElement) && prevLine.string.length > 0 && nextLine.isAnyCharacter) {
            [self addString:@"\n\n" atIndex:affectedCharRange.location];
            self.textView.selectedRange = NSMakeRange(affectedCharRange.location + 1, 0);
            return YES;
        }
    }
    
    return NO;
}

/// If the user types `)` where there already is a closing parentheses, jump over the `)`.
- (bool)shouldJumpOverParentheses:(NSString*)replacementString range:(NSRange)affectedCharRange
{
    // Jump over matched parentheses
    if (([replacementString isEqualToString:@")"] || [replacementString isEqualToString:@"]"]) &&
        affectedCharRange.location < _delegate.text.length) {
        unichar currentCharacter = [_delegate.text characterAtIndex:affectedCharRange.location];
        if ((currentCharacter == ')' && [replacementString isEqualToString:@")"]) ||
            (currentCharacter == ']' && [replacementString isEqualToString:@"]"])) {
            [_delegate setSelectedRange:NSMakeRange(affectedCharRange.location + 1, 0)];
            return YES;
        }
    }
    
    return NO;
}


/**
 Finds a matching closure for parenthesis, notes and omissions.
 This works by checking both the entered symbol and the previous symbol in text. If both match the terminator counterpart, the block is closed.
 For example: If the users enters  `*`, and the previous symbol in that range is `/`, we'll close the omission.
 
 Sorry, future me, this is a mess with tons of exit points etc.
 */
- (bool)shouldMatchParenthesesIn:(NSRange)affectedCharRange string:(NSString*)replacementString
{
    static NSDictionary *matches;
    if (matches == nil) matches = @{
        @"(" : @")",
        @"[[" : @"]]",
        @"/*" : @"*/",
        @"<<" : @">>",
        @"{{" : @"}}"
    };
    
    // Find match for the parenthesis symbol
    NSString *match = nil;
    for (NSString* key in matches.allKeys) {
        NSString *lastSymbol = [key substringWithRange:NSMakeRange(key.length - 1, 1)];
        
        if ([replacementString isEqualToString:lastSymbol]) {
            match = key;
            break;
        }
    }
    
    // No match for this parenthesis. Do nothing.
    if (matches[match] == nil) return false;

    // If we are typing (and not replacing) check for dual symbol matches, and don't add them if the previous character doesn't match.
    bool skipFirstCharacter = false;
    if (match.length > 1 && affectedCharRange.length <= 1) {
        if (affectedCharRange.location == 0) return false;
        unichar characterBefore = [_delegate.text characterAtIndex:affectedCharRange.location-1];
        if (characterBefore != [match characterAtIndex:0]) return false;
        
        skipFirstCharacter = true;
    }
    
    // After this, we'll also make sure we're not adding extraneous closing brackets anywhere.
    Line* line = _delegate.currentLine;
    NSString* terminator = matches[match];
    
    bool found = false;
    for (NSInteger i=affectedCharRange.location - line.position; i<=line.length; i++) {
        // Don't go out of range
        if (i + terminator.length > line.string.length) break;
        
        // Check if the line already has a closing bracket
        NSString* s = [line.string substringWithRange:NSMakeRange(i, terminator.length)];
        if ([s isEqualToString:terminator]) {
            found = true;
            break;
        } else if ([s isEqualToString:match]) {
            break;
        }
    }
    
    // If a terminator was found do nothing.
    if (found) return false;
    
    // And if it was, close the brackets.
    // First make sure there are no line breaks
    NSString* text = [self.delegate.text substringWithRange:affectedCharRange];
    bool safeToAdd = ![[text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] containsString:@"\n"];
    
    if (safeToAdd) {
        NSString* open = (skipFirstCharacter) ? replacementString : match;
        NSString* result = [NSString stringWithFormat:@"%@%@%@", open, text, matches[match]];
        [self replaceRange:affectedCharRange withString:result];
        
        // For longer chunks, we'll add the whole delimiter length to position, and when typing letters one by one, it's enough to adjust by one character
        NSInteger l = (affectedCharRange.length > 0) ? match.length : 1;
        [_delegate setSelectedRange:NSMakeRange(affectedCharRange.location + l, 0)];
    }
    
    return safeToAdd;
}

/// Check if we should add `CONT'D` at the the current character cue
- (BOOL)shouldAddContdIn:(NSRange)affectedCharRange string:(NSString*)replacementString
{
    Line *currentLine = _delegate.currentLine;
    NSInteger lineIndex = [_delegate.parser indexOfLine:currentLine] - 1;
    
    // Don't add CONT'D when not editing this line
    if (!NSLocationInRange(lineIndex, NSMakeRange(0, _delegate.parser.lines.count))) return NO;
    // ... or when there's already an extension
    else if ([currentLine.string containsString:@"("]) return NO;
    
    NSString *charName = currentLine.characterName;
    
    while (lineIndex > 0) {
        Line * prevLine = _delegate.parser.lines[lineIndex];
        
        // Stop at headings
        if (prevLine.type == heading) break;
        
        if (prevLine.isAnyCharacter) {
            // Stop if the previous character is not the current one
            if (![prevLine.characterName isEqualToString:charName]) break;
            
            // This is the character. Put in CONT'D and a line break and return NO
            NSString *contd = [BeatUserDefaults.sharedDefaults get:BeatSettingScreenplayItemContd];
            NSString *contdString = [NSString stringWithFormat:@" (%@)", contd];
            
            if (![currentLine.string containsString:[NSString stringWithFormat:@"(%@)", contd]]) {
                NSString* result = currentLine.string;
                // Remove dual dialogue symbol and add it back if needed
                if (currentLine.type == dualDialogueCharacter) result = [result stringByReplacingOccurrencesOfString:@"^" withString:@""];
                result = [result stringByAppendingFormat:@"%@%@\n", contdString, (currentLine.type == dualDialogueCharacter) ? @"^" : @""];
                
                [self replaceRange:currentLine.textRange withString:result];
                if (_delegate.characterInputForLine == currentLine && _delegate.characterInput) {
                    _delegate.characterInput = false;
                    _delegate.characterInputForLine = nil;
                }
                return YES;
            }
        }
        
        lineIndex--;
    }
    
    return NO;
}

- (void)addNewParagraph:(NSString*)string {
    [self addNewParagraph:string caretPosition:NSNotFound];
}

/// Adds a new paragraph at given position
- (void)addNewParagraph:(NSString*)string at:(NSInteger)position {
    [self addNewParagraph:string at:position caretPosition:NSNotFound];
}

/// Adds a new, clean paragraph at selected position and moves caret accordingly
- (void)addNewParagraph:(NSString*)string caretPosition:(NSInteger)newPosition {
    [self addNewParagraph:string at:NSNotFound caretPosition:newPosition];
}

- (void)addNewParagraph:(NSString*)string at:(NSInteger)position caretPosition:(NSInteger)newPosition {
    if (position == NSNotFound) position = self.delegate.currentLine.position;
    self.delegate.selectedRange = NSMakeRange(position, 0);
    
    // If current line is not empty, add a line break at current line.
    Line* previous = [self.delegate.parser previousLine:self.delegate.currentLine];
    if (self.delegate.currentLine.type != empty) {
        position = NSMaxRange(self.delegate.currentLine.textRange);
        [self addString:@"\n\n" atIndex:position];
        self.delegate.selectedRange = NSMakeRange(position + 2, 0);
    }
    else if (previous.type != empty) {
        position = NSMaxRange(self.delegate.currentLine.textRange);
        [self addString:@"\n" atIndex:position skipAutomaticLineBreaks:true];
        self.delegate.selectedRange = NSMakeRange(position + 1, 0);
    }

    // If current or next line are not empty, add two line breaks at current line.
    Line* next = [self.delegate.parser nextLine:self.delegate.currentLine];
    if (next.string.length > 0) {
        [self addString:@"\n" atIndex:NSMaxRange(self.delegate.currentLine.textRange) skipAutomaticLineBreaks:true];
        self.delegate.selectedRange = NSMakeRange(NSMaxRange(self.delegate.currentLine.textRange) - 1, 0);
    }
    
    [self addString:string atIndex:self.delegate.selectedRange.location];
    
    if (newPosition != NSNotFound) {
        self.delegate.selectedRange = NSMakeRange(self.delegate.selectedRange.location + newPosition, 0);
    }
}


#pragma mark - Quick elements

- (void)addSection:(NSInteger)position
{
    [self addNewParagraph:@"# " at:position];
}

- (void)addSynopsis:(NSInteger)position
{
    [self addNewParagraph:@"= " at:position];
}

- (void)addShot:(NSInteger)position
{
    [self addNewParagraph:@"!! " at:position];
}


#pragma mark - Set color

- (void)setColor:(NSString *)color forLine:(Line *)line
{
    if (line == nil) return;
    
    // First replace the existing color range (if it exists)
    if (line.colorRange.length > 0) {
        NSRange localRange = line.colorRange;
        NSRange globalRange = [line globalRangeFromLocal:localRange];
        [self removeRange:globalRange];
    }
    
    // Do nothing else if color is set to none
    if ([color.lowercaseString isEqualToString:@"none"]) return;
    
    // Create color string and add a space at the end of heading if needed
    NSString *colorStr = [NSString stringWithFormat:@"[[%@]]", color.lowercaseString];
    if ([line.string characterAtIndex:line.string.length - 1] != ' ') {
        colorStr = [NSString stringWithFormat:@" %@", colorStr];
    }
    
    [self addString:colorStr atIndex:NSMaxRange(line.textRange)];
}

- (void)setColor:(NSString *)color forScene:(OutlineScene *)scene
{
    if (scene == nil) return;
    [self setColor:color forLine:scene.line];
}


#pragma mark - Storylines

- (void)addStoryline:(NSString*)storyline to:(OutlineScene*)scene
{
    NSMutableArray *storylines = scene.storylines.copy;
    
    // Do nothing if the storyline is already there
    if ([storylines containsObject:storyline]) return;
    
    if (storylines.count > 0) {
        // If the scene already has any storylines, we'll have to add the beat somewhere.
        // Check if scene heading has note ranges, and if not, add it. Otherwise stack into that range.
        if (!scene.line.beatRanges.count) {
            // No beat note in heading yet
            NSString *beatStr = [Storybeat stringWithStorylineNames:@[storyline]];
            beatStr = [@" " stringByAppendingString:beatStr];
            [self addString:beatStr atIndex:NSMaxRange(scene.line.textRange)];
        } else {
            NSMutableArray <Storybeat*>*beats = scene.line.beats.mutableCopy;
            NSRange replaceRange = beats.firstObject.rangeInLine;
            
            // This is fake storybeat object to handle the string creation correctly.
            [beats addObject:[Storybeat line:scene.line scene:scene string:storyline range:replaceRange]];
            NSString *beatStr = [Storybeat stringWithBeats:beats];
            
            [self replaceRange:[scene.line globalRangeFromLocal:replaceRange] withString:beatStr];
        }
        
    } else {
        // There are no storylines yet. Create a beat note and add it at the end of scene heading.
        NSString *beatStr = [Storybeat stringWithStorylineNames:@[storyline]];
        beatStr = [@" " stringByAppendingString:beatStr];
        [self addString:beatStr atIndex:NSMaxRange(scene.line.textRange)];
    }
}

- (void)removeStoryline:(NSString*)storyline from:(OutlineScene*)scene
{
    NSMutableArray *storylines = scene.storylines.copy;
    // Do nothing if the storyline is not there.
    if (![storylines containsObject:storyline]) return;
    
    if (storylines.count > 0) {
        if (storylines.count <= 1) {
            // The last storybeat. Clear ALL storyline notes.
            for (Line *line in [self.delegate.parser linesForScene:scene]) {
                [self removeTextOnLine:line inLocalIndexSet:line.beatRanges];
            }
        } else {
            // This is unnecessarily complicated.
            // Find the specified beat note
            Line *lineWithBeat;
            for (Line *line in [_delegate.parser linesForScene:scene]) {
                if ([line hasBeatForStoryline:storyline]) {
                    lineWithBeat = line;
                    break;
                }
            }
            if (!lineWithBeat) return;
            
            NSMutableArray *beats = lineWithBeat.beats.mutableCopy;
            Storybeat *beatToRemove = [lineWithBeat storyBeatWithStoryline:storyline];
            [beats removeObject:beatToRemove];
            
            // Multiple beats can be tucked into a single note. Store the other beats.
            NSMutableArray *stackedBeats = NSMutableArray.new;
            for (Storybeat *beat in beats) {
                if (NSEqualRanges(beat.rangeInLine, beatToRemove.rangeInLine)) [stackedBeats addObject:beat];
            }
            
            // If any beats were left, recreate the beat note with the leftovers.
            // Otherwise, just remove it.
            NSString *beatStr = @"";
            if (stackedBeats.count) beatStr = [Storybeat stringWithBeats:stackedBeats];
            
            NSRange removalRange = beatToRemove.rangeInLine;
            [self replaceRange:[lineWithBeat globalRangeFromLocal:removalRange] withString:beatStr];
        }
    }
}


#pragma mark - Moving blocks around

- (void)moveBlockUp:(NSArray<Line*>*)lines
{
    ContinuousFountainParser* parser = self.delegate.parser;
    if (lines.firstObject == parser.lines.firstObject) return;
    
    NSUInteger prevIndex = [parser indexOfLine:lines.firstObject] - 1;
    Line* prevLine = parser.lines[prevIndex];
    
    NSArray *prevBlock = [parser blockFor:prevLine];
    
    Line *firstLine = prevBlock.firstObject;
    NSInteger position = firstLine.position; // Save the position so we don't move the block at the wrong position
    
    // If the block doesn't have an empty line at the end, create one
    if (lines.lastObject.length > 0) [self addString:@"\n" atIndex:position];
    
    NSRange blockRange = [parser rangeForBlock:lines];
    [self moveStringFrom:blockRange to:position];
    if (blockRange.length > 0) [self.delegate setSelectedRange:NSMakeRange(position, blockRange.length - 1)];
}

- (void)moveBlockDown:(NSArray<Line*>*)lines
{
    ContinuousFountainParser* parser = self.delegate.parser;
    
    // Don't move downward if we're already at the last object
    if (lines.lastObject == parser.lines.lastObject ||
        lines.count == 0) return;
    
    NSUInteger nextIndex = [parser indexOfLine:lines.lastObject] + 1;
    Line* nextLine = parser.lines[nextIndex];
    
    // Get the next block (paragraph/dialogue block)
    NSArray* nextBlock = [parser blockFor:nextLine];
    Line *endLine = nextBlock.lastObject;
    if (endLine == nil) return;
    
    NSRange blockRange = [parser rangeForBlock:lines];
    
    if (endLine.string.length > 0) {
        // Add a line break if we're moving a block at the end
        [self addString:@"" atIndex:NSMaxRange(endLine.textRange)];
    }
    
    [self moveStringFrom:blockRange to:NSMaxRange(endLine.range)];
    
    if (![parser.lines containsObject:endLine]) {
        // The last line was deleted in the process, so let's find the one that's still there.
        NSInteger i = lines.count;
        while (i > 0) {
            i--;
            if ([parser.lines containsObject:lines[i]]) {
                endLine = lines[i];
                break;
            }
        }
    }
    
    // Select the moved line
    if (blockRange.length > 0) {
        [self.delegate setSelectedRange:NSMakeRange(NSMaxRange(endLine.range), blockRange.length - 1)];
    }
}


#pragma mark - Force element types

- (NSDictionary*)forceSymbols
{
    static NSDictionary<NSNumber*,NSString*>* symbols;
    if (symbols == nil) symbols = @{
        @(heading): forceHeadingSymbol,
        @(character): forceCharacterSymbol,
        @(action): forceActionSymbol,
        @(lyrics): forceLyricsSymbol,
        @(transitionLine): forceTransitionLineSymbol
    };
    return symbols;
}

- (void)forceLineType:(LineType)lineType
{
    [self forceLineType:lineType range:self.delegate.selectedRange];
}

- (void)forceLineType:(LineType)type range:(NSRange)cursorLocation
{
    Line* currentLine = self.delegate.currentLine;
    if (currentLine == nil) return;
    
    NSString* symbol = self.forceSymbols[@(type)];
    
    // Remove or change current symbol
    NSRange forcedRange = NSMakeRange(currentLine.position, currentLine.numberOfPrecedingFormattingCharacters);
    [self replaceRange:forcedRange withString:symbol];
}

@end
