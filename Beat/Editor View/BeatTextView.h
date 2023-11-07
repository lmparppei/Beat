//
//	BeatTextView.m
//  Based on NCRAutocompleteTextView.m
//  Modified for Beat
//
//  Copyright (c) 2014 Null Creature. All rights reserved.
//  Parts copyright © 2019 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <BeatParsing/BeatParsing.h>
#import <BeatThemes/BeatThemes.h>
#import <BeatCore/BeatCore.h>
#import "BeatTextStorage.h"

typedef NS_ENUM(NSInteger, BeatTextviewPopupMode) {
	NoPopup,
	Autocomplete,
	ForceElement,
	Tagging,
	SelectTag
};

@class BeatReview;
@class BeatStylesheet;

@protocol NCRAutocompleteTableViewDelegate <NSObject>
@optional
- (NSImage *)textView:(NSTextView *)textView imageForCompletion:(NSString *)word;
- (NSArray *)textView:(NSTextView *)textView completions:(NSArray *)words forPartialWordRange:(NSRange)charRange indexOfSelectedItem:(NSInteger *)index;
@end

@protocol BeatTextViewDelegate <NSTextViewDelegate, BeatEditorDelegate>

@property (nonatomic) CGFloat magnification;
@property (nonatomic, readonly) ContinuousFountainParser *parser;
@property (readonly) ThemeManager* themeManager;
@property (readonly) bool showRevisions;
@property (readonly) bool sceneNumberLabelUpdateOff;
@property (nonatomic) bool showSceneNumberLabels;
@property (nonatomic) bool showPageNumbers;
@property (readonly) NSMutableIndexSet *changes;
@property (readonly) bool contentLocked;
@property (readonly) NSUInteger fontSize;
@property (readonly) bool typewriterMode;
@property (readonly) bool hideFountainMarkup;
@property (readonly) bool documentIsLoading;
@property (nonatomic) bool skipSelectionChangeEvent;

@property (nonatomic) BeatReview* review;

@property (readonly) NSRange lastChangedRange;

@property (readonly, nonatomic) NSFont *courier;
@property (readonly, nonatomic) NSFont *boldCourier;
@property (readonly, nonatomic) NSFont *boldItalicCourier;
@property (readonly, nonatomic) NSFont *italicCourier;

@property (nonatomic, readonly) Line *previouslySelectedLine;
@property (nonatomic, readonly) Line *currentLine;

@property (nonatomic, readonly) BeatStylesheet *editorStyles;

- (bool)isDark;
- (void)updateLayout;
- (void)ensureLayout;
- (void)ensureCaret;
- (void)showLockStatus;
- (void)handleTabPress;

- (NSInteger)getPageNumberAt:(NSInteger)location;
- (NSInteger)numberOfPages;

-(void)textStorage:(NSTextStorage *)textStorage didProcessEditing:(NSTextStorageEditActions)editedMask range:(NSRange)editedRange changeInLength:(NSInteger)delta;
- (void)renderBackgroundForLine:(Line*)line clearFirst:(bool)clear;
- (void)forceElement:(LineType)lineType;
- (CGFloat)lineHeight;

- (void)setSplitHandleMinSize:(CGFloat)value;

- (void)cancelOperation:(id)sender;

@end

@class BeatTagging;
@class BeatPaginationPage;

@interface BeatTextView : NSTextView <NSTableViewDataSource, NSTableViewDelegate, NSLayoutManagerDelegate, NSTextStorageDelegate>
@property (weak) IBOutlet id<BeatTextViewDelegate> editorDelegate;
@property (weak) IBOutlet BeatTagging *tagging;
@property (nonatomic) IBOutlet NSMenu *contextMenu;

@property (nonatomic) bool didType;

@property CGFloat textInsetY;
@property NSMutableArray* masks;
@property NSArray* sceneNumbers;
@property (nonatomic, weak) DynamicColor* marginColor;
@property NSArray* pageBreaks;
@property (nonatomic) CGFloat zoomLevel;
@property NSInteger autocompleteIndex;

@property (nonatomic) CGFloat scaleFactor;

+ (CGFloat)linePadding;
- (CGFloat)documentWidth;

- (IBAction)showInfo:(id)sender;
- (CGFloat)setInsets;
- (void)scrollToRange:(NSRange)range;
- (void)scrollToRange:(NSRange)range callback:(void (^)(void))callbackBlock;
- (void)ensureRangeIsVisible:(NSRange)range;

// Page numbering
- (void)deletePageNumbers;
- (void)updatePageNumbers;
- (void)updatePageNumbers:(NSArray*)pageBreaks;
// Native pagination
- (void)updatePagination:(NSArray<BeatPaginationPage*>*)pages;

-(void)redrawAllGlyphs;
-(void)redrawUI;
-(void)updateMarkupVisibility;
-(void)toggleHideFountainMarkup;
- (NSRect)rectForRange:(NSRange)range;

- (void)setup;

// Zooming
- (void)zoom:(bool)zoomIn;
- (void)setupZoom;
- (void)resetZoom;
- (void)adjustZoomLevel:(CGFloat)level;

// Force element
- (void)forceElement:(id)sender;

@end
