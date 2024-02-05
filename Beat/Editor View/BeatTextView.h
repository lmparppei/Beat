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
//#import "Beat-Swift.h"

typedef NS_ENUM(NSInteger, BeatTextviewPopupMode) {
	NoPopup,
	Autocomplete,
	ForceElement,
	Tagging,
	SelectTag
};

@class BeatPreviewController;
@class BeatReview;
@class BeatStylesheet;

@protocol NCRAutocompleteTableViewDelegate <NSObject>
@optional
- (NSImage *)textView:(NSTextView *)textView imageForCompletion:(NSString *)word;
- (NSArray *)textView:(NSTextView *)textView completions:(NSArray *)words forPartialWordRange:(NSRange)charRange indexOfSelectedItem:(NSInteger *)index;
@end

@protocol BeatTextViewDelegate <NSTextViewDelegate, BeatEditorDelegate>

@property (nonatomic) CGFloat magnification;
@property (readonly) ThemeManager* themeManager;
@property (readonly) bool showRevisions;
@property (readonly) bool sceneNumberLabelUpdateOff;
@property (nonatomic) bool showSceneNumberLabels;
@property (nonatomic) bool showPageNumbers;
@property (readonly) NSMutableIndexSet *changes;
@property (readonly) bool contentLocked;
@property (readonly) CGFloat fontSize;
@property (readonly) bool hideFountainMarkup;
@property (readonly) bool documentIsLoading;
@property (nonatomic) bool skipSelectionChangeEvent;

@property (nonatomic) BeatReview* review;

@property (readonly) NSRange lastChangedRange;

@property (nonatomic, readonly) Line *previouslySelectedLine;
@property (nonatomic, readonly) Line *currentLine;

@property (nonatomic, readonly) BeatStylesheet *editorStyles;

@property (nonatomic, readonly) BeatPreviewController* previewController;

- (bool)isDark;
- (void)ensureLayout;
- (void)showLockStatus;
- (void)handleTabPress;

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
@property (nonatomic) NSString* text;

@property (nonatomic) bool didType;


#pragma mark - Layout and positioning

+ (CGFloat)linePadding;
- (CGFloat)documentWidth;

@property CGFloat textInsetY;
@property NSArray* sceneNumbers;
@property (nonatomic, weak) DynamicColor* marginColor;

@property (nonatomic) CGFloat zoomLevel;
@property (nonatomic) CGFloat scaleFactor;

@property (nonatomic) NSTextFinder* textFinder;

- (void)setupZoom;
- (void)resetZoom;
- (void)zoom:(bool)zoomIn;
- (void)adjustZoomLevel:(CGFloat)level;

/// Calculates the insets to make content centered
- (CGFloat)setInsets;


#pragma mark - Pagination

@property NSArray* pageBreaks;

/// Typewriter mode
@property (nonatomic) bool typewriterMode;


#pragma mark - Autocompletion

/// Current popup view mode (autocomplete/tagging/etc.)
@property (nonatomic) BeatTextviewPopupMode popupMode;

/// Autocompletion results
@property (nonatomic, strong) NSArray *matches;

/// Selected index in autocomplete popover
@property NSInteger autocompleteIndex;
/// Popover for autocompletion
@property (nonatomic, strong) NSPopover *autocompletePopover;
/// Table view for autocompletion
@property (nonatomic, weak) NSTableView *autocompleteTableView;
/// Displays force element menu
- (void)forceElement:(id)sender;


#pragma mark - Common methods

- (void)setup;
- (IBAction)showInfo:(id)sender;


#pragma mark - Scrolling

- (void)scrollToRange:(NSRange)range;
- (void)scrollToRange:(NSRange)range callback:(void (^)(void))callbackBlock;
- (void)ensureRangeIsVisible:(NSRange)range;


#pragma mark - Drawing

-(void)redrawAllGlyphs;
-(void)redrawUI;
-(void)updateMarkupVisibility;
-(void)toggleHideFountainMarkup;
- (NSRect)rectForRange:(NSRange)range;


#pragma mark - Caret

- (void)loadCaret;
- (void)ensureCaret;

@end
