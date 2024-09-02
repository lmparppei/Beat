//
//  Document+TextEvents.h
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 1.9.2024.
//  Copyright © 2024 Lauri-Matti Parppei. All rights reserved.
//

#import "Document.h"
#import "BeatTextView.h"

NS_ASSUME_NONNULL_BEGIN

@interface Document (TextEvents) <NSTextViewDelegate>

- (BOOL)textView:(NSTextView *)textView shouldChangeTextInRange:(NSRange)affectedCharRange replacementString:(NSString *)replacementString;
- (void)textStorage:(NSTextStorage *)textStorage didProcessEditing:(NSTextStorageEditActions)editedMask range:(NSRange)editedRange changeInLength:(NSInteger)delta;
- (void)textViewDidChangeSelection:(NSNotification *)notification;
- (NSInteger)textView:(NSTextView *)textView shouldSetSpellingState:(NSInteger)value range:(NSRange)affectedCharRange;
- (void)cancelCharacterInput;

@end

NS_ASSUME_NONNULL_END
