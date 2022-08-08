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
#import "BeatTextStorage.h"

typedef NS_ENUM(NSInteger, BeatTextviewPopupMode) {
	NoPopup,
	Autocomplete,
	ForceElement,
	Tagging,
	SelectTag
};


@protocol NCRAutocompleteTableViewDelegate <NSObject>
@optional
- (NSImage *)textView:(NSTextView *)textView imageForCompletion:(NSString *)word;
- (NSArray *)textView:(NSTextView *)textView completions:(NSArray *)words forPartialWordRange:(NSRange)charRange indexOfSelectedItem:(NSInteger *)index;
@end
 
@protocol BeatTextViewDelegate <NSTextViewDelegate, BeatEditorDelegate>

@property (nonatomic) CGFloat magnification;
@property (nonatomic, readonly) NSUInteger documentWidth;
@property (nonatomic, readonly) ContinuousFountainParser *parser;
@property (readonly) ThemeManager* themeManager;
@property (readonly) bool showRevisions;
@property (readonly) bool sceneNumberLabelUpdateOff;
@property (readonly) bool showSceneNumberLabels;
@property (readonly) bool showPageNumbers;
@property (readonly) NSMutableIndexSet *changes;
@property (readonly) bool contentLocked;
@property (readonly) NSUInteger fontSize;
@property (readonly) bool typewriterMode;
@property (readonly) bool hideFountainMarkup;
@property (readonly) bool documentIsLoading;
@property (nonatomic) bool skipSelectionChangeEvent;

@property (nonatomic) id review;

@property (readonly) NSRange lastChangedRange;

@property (readonly, nonatomic) NSFont *courier;
@property (readonly, nonatomic) NSFont *boldCourier;
@property (readonly, nonatomic) NSFont *boldItalicCourier;
@property (readonly, nonatomic) NSFont *italicCourier;

@property (nonatomic, readonly) Line *previouslySelectedLine;
@property (nonatomic, readonly) Line *currentLine;

- (void)replaceRange:(NSRange)range withString:(NSString*)newString;
- (NSMutableArray*)getOutlineItems;
- (Line*)getCurrentLine;
- (bool)isDark;
- (void)updateLayout;
- (void)ensureLayout;
- (void)ensureCaret;
- (void)showLockStatus;
- (LineType)lineTypeAt:(NSInteger)index;
- (Line*)lineAt:(NSInteger)index;
- (void)handleTabPress;

- (NSInteger)getPageNumber:(NSInteger)location;
- (NSInteger)numberOfPages;

-(void)textStorage:(NSTextStorage *)textStorage didProcessEditing:(NSTextStorageEditActions)editedMask range:(NSRange)editedRange changeInLength:(NSInteger)delta;
- (void)renderBackgroundForLine:(Line*)line clearFirst:(bool)clear;
- (void)forceElement:(LineType)lineType;
- (CGFloat)lineHeight;

- (void)setSplitHandleMinSize:(CGFloat)value;

@end

@class BeatTagging;

@interface BeatTextView : NSTextView <NSTableViewDataSource, NSTableViewDelegate, NSLayoutManagerDelegate, NSTextStorageDelegate>
+ (CGFloat)linePadding;

- (IBAction)toggleDarkPopup:(id)sender;
- (IBAction)showInfo:(id)sender;
- (CGFloat)setInsets;
- (void)scrollToRange:(NSRange)range;
- (void)scrollToRange:(NSRange)range callback:(void (^)(void))callbackBlock;

// Scene Numbering
- (void)updateSceneLabelsFrom:(NSInteger)changedIndex;
- (void)deleteSceneNumberLabels;
- (void)resetSceneNumberLabels;

// Page numbering
- (void)updatePageBreaks:(NSArray<NSDictionary*>*)pageBreaks;
- (void)deletePageNumbers;
- (void)updatePageNumbers;
- (void)updatePageNumbers:(NSArray*)pageBreaks;

-(void)redrawAllGlyphs;
-(void)redrawUI;
-(void)updateMarkdownView;
-(void)toggleHideFountainMarkup;
- (NSRect)rectForRange:(NSRange)range;

@property CGFloat textInsetY;
@property (weak) IBOutlet id<BeatTextViewDelegate> editorDelegate;
@property (weak) IBOutlet BeatTagging *tagging;
@property NSMutableArray* masks;
@property NSArray* sceneNumbers;
@property (nonatomic, weak) DynamicColor* marginColor;
@property NSArray* pageBreaks;
@property (nonatomic) CGFloat zoomLevel;
@property NSInteger autocompleteIndex;

@property (nonatomic) CGFloat scaleFactor;

@property (nonatomic) IBOutlet NSMenu *contextMenu;
//@property (nonatomic, readonly, weak) ContinuousFountainParser *parser;

- (void)refreshLayoutElementsFrom:(NSInteger)location;
- (void)refreshLayoutElements;

- (void)setup;

// Zooming
- (void)zoom:(bool)zoomIn;
- (void)setupZoom;
- (void)resetZoom;
- (void)adjustZoomLevel:(CGFloat)level;

@end
