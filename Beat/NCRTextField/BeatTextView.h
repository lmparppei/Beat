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
#import "ContinousFountainParser.h"
#import "ThemeManager.h"
#import "BeatTagging.h"

typedef enum : NSInteger {
	NoPopup = 0,
	Autocomplete,
	ForceElement,
	Tagging
} BeatTextviewPopupMode;

@protocol NCRAutocompleteTableViewDelegate <NSObject>
@optional
- (NSImage *)textView:(NSTextView *)textView imageForCompletion:(NSString *)word;
- (NSArray *)textView:(NSTextView *)textView completions:(NSArray *)words forPartialWordRange:(NSRange)charRange indexOfSelectedItem:(NSInteger *)index;
@end

@protocol BeatTextViewDelegate <NSTextViewDelegate>
@property (nonatomic) CGFloat magnification;
@property (nonatomic, readonly) ContinousFountainParser *parser;
@property (readonly) NSFont *courier;
@property (readonly) NSFont *boldCourier;
@property (readonly) NSFont *italicCourier;
@property (readonly) ThemeManager* themeManager;
- (NSMutableArray*)getOutlineItems;
@end

@protocol BeatTaggingDelegate;

@interface BeatTextView : NSTextView <NSTableViewDataSource, NSTableViewDelegate>
- (IBAction)toggleDarkPopup:(id)sender;
- (IBAction)showInfo:(id)sender;
- (void)updateSections:(NSArray*)sections;
- (void)setInsets;

// Scene Numbering
- (void) updateSceneNumberLabels;
- (void) deleteSceneNumberLabels;

@property CGFloat textInsetY;
@property (weak) id<BeatTextViewDelegate> zoomDelegate;
@property (weak) id<BeatTaggingDelegate> taggingDelegate;
@property NSMutableArray* masks;
@property NSArray* sceneNumbers;
@property NSArray* sections;
@property (nonatomic, weak) DynamicColor* marginColor;
@property NSArray* pageBreaks;
@property CGFloat zoomLevel;
@property CGFloat documentWidth;
@property NSInteger autocompleteIndex;

@end
