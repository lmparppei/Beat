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
#import "ContinuousFountainParser.h"
#import "ThemeManager.h"
#import "BeatTagging.h"

typedef enum : NSInteger {
	NoPopup = 0,
	Autocomplete,
	ForceElement,
	Tagging,
	SelectTag
} BeatTextviewPopupMode;


@protocol NCRAutocompleteTableViewDelegate <NSObject>
@optional
- (NSImage *)textView:(NSTextView *)textView imageForCompletion:(NSString *)word;
- (NSArray *)textView:(NSTextView *)textView completions:(NSArray *)words forPartialWordRange:(NSRange)charRange indexOfSelectedItem:(NSInteger *)index;
@end

@protocol BeatTextViewDelegate <NSTextViewDelegate>

typedef enum : NSInteger {
	EditMode = 0,
	TaggingMode,
	ReviewMode
} BeatEditorMode;

@property (nonatomic) CGFloat magnification;
@property (nonatomic, readonly) NSUInteger documentWidth;
@property (nonatomic, readonly) ContinuousFountainParser *parser;
@property (readonly) NSFont *courier;
@property (readonly) NSFont *boldCourier;
@property (readonly) NSFont *italicCourier;
@property (readonly) ThemeManager* themeManager;
@property (readonly) BeatEditorMode mode;	
@property (readonly) bool trackChanges;
@property (readonly) bool showSceneNumberLabels;
@property (readonly) bool showPageNumbers;
@property (readonly) NSMutableIndexSet *changes;
@property (readonly) bool contentLocked;
@property (readonly) NSUInteger fontSize;
@property (readonly) bool typewriterMode;

- (void)replaceCharactersInRange:(NSRange)range withString:(NSString*)string;
- (NSMutableArray*)getOutlineItems;
- (Line*)getCurrentLine;
- (bool)isDark;
- (void)updateLayout;
- (void)ensureLayout;
- (void)showLockStatus;
@end

@protocol BeatTaggingDelegate;

@interface BeatTextView : NSTextView <NSTableViewDataSource, NSTableViewDelegate, NSLayoutManagerDelegate>
- (IBAction)toggleDarkPopup:(id)sender;
- (IBAction)showInfo:(id)sender;
- (CGFloat)setInsets;
- (void)scrollToRange:(NSRange)range;

// Scene Numbering
- (void)updateSceneLabelsFrom:(NSInteger)changedIndex;
- (void)deleteSceneNumberLabels;
- (void)resetSceneNumberLabels;
- (void)updateSectionLayers;

// Page numbering
- (void)deletePageNumbers;
- (void)updatePageNumbers;
- (void)updatePageNumbers:(NSArray*)pageBreaks;

-(void)redrawUI;

@property CGFloat textInsetY;
@property (weak) id<BeatTextViewDelegate> editorDelegate;
@property (weak) id<BeatTaggingDelegate> taggingDelegate;
@property NSMutableArray* masks;
@property NSArray* sceneNumbers;
@property (nonatomic, weak) DynamicColor* marginColor;
@property NSArray* pageBreaks;
@property CGFloat zoomLevel;
@property NSInteger autocompleteIndex;

@property (weak) IBOutlet NSMenu *contextMenu;

@end
