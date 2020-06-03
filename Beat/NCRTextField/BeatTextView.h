//
//	BeatTextView.m
//  Based on NCRAutocompleteTextView.m
//  Modified for Beat
//
//  Copyright (c) 2014 Null Creature. All rights reserved.
//  Parts copyright © 2019 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DynamicColor.h"


@protocol NCRAutocompleteTableViewDelegate <NSObject>
@optional
- (NSImage *)textView:(NSTextView *)textView imageForCompletion:(NSString *)word;
- (NSArray *)textView:(NSTextView *)textView completions:(NSArray *)words forPartialWordRange:(NSRange)charRange indexOfSelectedItem:(NSInteger *)index;
@end

@interface BeatTextView : NSTextView <NSTableViewDataSource, NSTableViewDelegate>
- (IBAction)toggleDarkPopup:(id)sender;
- (IBAction)showInfo:(id)sender;
- (void)updateSections:(NSArray*)sections;

//@property (weak) id <NCRAutocompleteTableViewDelegate> delegate;

@property NSMutableArray* masks;
@property NSArray* sceneNumbers;
@property NSArray* sections;
@property (nonatomic, weak) DynamicColor* marginColor;
@property NSArray* pageBreaks;
@property CGFloat zoomLevel;
@property NSInteger autocompleteIndex;

@end

@protocol BeatTextViewDelegate <NSTextViewDelegate>

@end
