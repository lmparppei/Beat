//
//  BeatTextIO.h
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 18.2.2023.
//

#import <TargetConditionals.h>
#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
#define BXTextView UITextView
#else
#import <Cocoa/Cocoa.h>
#define BXTextView NSTextView
#endif

#import "BeatEditorDelegate.h"

@class OutlineScene;
@class ContinuousFountainParser;
@class Line;

@protocol BeatTextIODelegate
@property (nonatomic) ContinuousFountainParser* parser;
@property (nonatomic, readwrite) bool moving;
@property (nonatomic, readwrite) NSRange selectedRange;
@optional @property (nonatomic) NSUndoManager* undoManager;
- (Line*)currentLine;
- (NSArray<OutlineScene*>*)getOutlineItems;
- (BXTextView*)getTextView;
- (NSString*)text;
- (void)textDidChange:(NSNotification *)notification;

#if TARGET_OS_IOS
- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text;
#else
- (BOOL)textView:(NSTextView *)textView shouldChangeTextInRange:(NSRange)affectedCharRange replacementString:(NSString *)replacementString;
#endif
@end

@interface BeatTextIO : NSObject
@property (nonatomic, weak) id<BeatTextIODelegate> delegate;

- (instancetype)initWithDelegate:(id<BeatTextIODelegate>)delegate;
- (void)replaceCharactersInRange:(NSRange)range withString:(NSString*)string;
- (void)addString:(NSString*)string atIndex:(NSUInteger)index;
- (void)addString:(NSString*)string atIndex:(NSUInteger)index skipAutomaticLineBreaks:(bool)skipLineBreaks;
- (void)removeAt:(NSUInteger)index length:(NSUInteger)length;
- (void)replaceRange:(NSRange)range withString:(NSString*)newString;
- (void)replaceString:(NSString*)string withString:(NSString*)newString atIndex:(NSUInteger)index;
- (void)removeRange:(NSRange)range;
- (void)moveStringFrom:(NSRange)range to:(NSInteger)position actualString:(NSString*)string;
- (void)moveStringFrom:(NSRange)range to:(NSInteger)position;
- (NSRange)globalRangeFromLocalRange:(NSRange*)range inLineAtPosition:(NSUInteger)position;
- (void)moveScene:(OutlineScene*)sceneToMove from:(NSInteger)from to:(NSInteger)to;
- (void)removeTextOnLine:(Line*)line inLocalIndexSet:(NSIndexSet*)indexSet;

- (void)addNewParagraph:(NSString*)string;

- (bool)shouldAddLineBreaks:(Line*)currentLine range:(NSRange)affectedCharRange;
- (bool)shouldJumpOverParentheses:(NSString*)replacementString range:(NSRange)affectedCharRange;
- (void)matchParenthesesIn:(NSRange)affectedCharRange string:(NSString*)replacementString;
- (BOOL)shouldAddContdIn:(NSRange)affectedCharRange string:(NSString*)replacementString;

@end


