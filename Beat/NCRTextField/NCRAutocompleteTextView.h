//
//  NCRAutocompleteTextView.m
//  Modified for Beat
//
//  Parts copyright © 2019 Lauri-Matti Parppei. All rights reserved.
//  Copyright (c) 2014 Null Creature. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol NCRAutocompleteTableViewDelegate <NSObject>
@optional
- (NSImage *)textView:(NSTextView *)textView imageForCompletion:(NSString *)word;
- (NSArray *)textView:(NSTextView *)textView completions:(NSArray *)words forPartialWordRange:(NSRange)charRange indexOfSelectedItem:(NSInteger *)index;
@end

@interface NCRAutocompleteTextView : NSTextView <NSTableViewDataSource, NSTableViewDelegate>
- (IBAction)toggleDarkPopup:(id)sender;
//@property (weak) id <NCRAutocompleteTableViewDelegate> delegate;
@end
