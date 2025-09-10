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

typedef NS_ENUM(NSInteger, BeatTextviewPopoverMode) {
	NoPopup,
	Autocomplete,
	ForceElement,
	Tagging,
	SelectTag
};

@class BeatPreviewController;
@class BeatReview;
@class BeatStylesheet;
@class BeatEditorFormatting;


#pragma mark - Autocompletion table view delegate
// Why is this here?

@protocol NCRAutocompleteTableViewDelegate <NSObject>
@optional
- (NSImage *)textView:(NSTextView *)textView imageForCompletion:(NSString *)word;
- (NSArray *)textView:(NSTextView *)textView completions:(NSArray *)words forPartialWordRange:(NSRange)charRange indexOfSelectedItem:(NSInteger *)index;
@end


#pragma mark - Expanded text view delegate

@protocol BeatTextViewDelegate <NSTextViewDelegate, BeatEditorDelegate>

@property (readonly) bool contentLocked;
@property (readonly) CGFloat fontSize;
@property (readonly) bool hideFountainMarkup;
@property (readonly) bool documentIsLoading;
@property (nonatomic) bool skipSelectionChangeEvent;

@property (nonatomic) BeatReview* review;

@property (readonly) NSRange lastChangedRange;

@property (nonatomic, readonly) Line *previouslySelectedLine;

@property (nonatomic) BeatEditorFormatting* formatting;

- (bool)isDark;
- (void)showLockStatus;
- (void)handleTabPress;

- (void)textStorage:(NSTextStorage *)textStorage didProcessEditing:(NSTextStorageEditActions)editedMask range:(NSRange)editedRange changeInLength:(NSInteger)delta;
- (CGFloat)lineHeight;

- (void)setSplitHandleMinSize:(CGFloat)value;

- (void)cancelOperation:(id)sender;
@end


#pragma mark - Text view

@class BeatTagging;
@class BeatPaginationPage;
@class BeatEditorPopoverController;

@interface BeatTextView : NSTextView <NSTableViewDataSource, NSTableViewDelegate, NSLayoutManagerDelegate, NSTextStorageDelegate>

@property (weak) IBOutlet id<BeatTextViewDelegate> editorDelegate;
@property (weak) IBOutlet BeatTagging *tagging;
@property (nonatomic) IBOutlet NSMenu *contextMenu;
@property (nonatomic) NSString* text;
@property (nonatomic) BeatEditorPopoverController* popoverController;

@property (nonatomic) bool didType;

/// This is set `true` while the user is scrolling the view
@property (nonatomic) bool scrolling;

/// A shorthand to return `true` when selection is at end. Use this to avoid going out of range when setting typing attributes.
@property (nonatomic) bool selectionAtEnd;

#pragma mark Layout and positioning

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


#pragma mark Pagination

@property NSArray* pageBreaks;

/// Typewriter mode
@property (nonatomic) bool typewriterMode;


#pragma mark Autocompletion

/// Autocompletion results
@property (nonatomic, strong) NSArray *matches;

/// Used to keep track of when the insert cursor has moved for both autocompletion and other popover handling. See  `didChangeSelection:`.
@property (nonatomic, assign) NSInteger lastPos;

/// This is the partial autocompletion word/line range
@property (nonatomic, copy) NSString *partialText;



#pragma mark - Common methods

- (void)setup;

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


#pragma mark - Popovers

/// Popover for displaying selection info (cmd-shift-I) has to stay in memory to reliably close it.
@property (nonatomic, strong) NSPopover *infoPopover;


#pragma mark - Markers

/// Returns an array of dictionaries which contain y position and scene / marker color
- (NSArray*)markersAndPositions;


@end
