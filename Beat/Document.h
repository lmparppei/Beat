//
//  Document.h
//  Beat
//
//  Released under GPL.
//  Copyright (c) 2016 Hendrik Noeller
//  Based on Writer, copyright (c) 2016 Hendrik Noeller

/*
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*/



#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import <BeatParsing/BeatParsing.h>
#import <BeatCore/BeatCore.h>

#import "BeatTextView.h"
#import "TouchTimelineView.h"
#import "TouchTimelinePopover.h"
#import "SceneCards.h"
#import "BeatTimeline.h"
#import "TKSplitHandle.h"
#import "BeatTimer.h"
#import "BeatPlugin.h"
#import "BeatOutlineView.h"
#import "BeatStatisticsPanel.h"
//#import "Beat-Swift.h"

/*
typedef NS_ENUM(NSUInteger, BeatFormatting) {
	Block = 0,
	Bold,
	Italic,
	Underline,
	Note
};

*/


// Forward declaration to make parser available for text view
@class BeatTextView;
@class BeatReview;
@class BeatWidgetView;

@protocol DocumentExports <JSExport>
@property (nonatomic, readonly) ContinuousFountainParser* _Nonnull parser;
@property (atomic) BeatDocumentSettings * _Nonnull documentSettings;
- (NSMutableArray<Line*>* _Nonnull)lines;
@end

@interface Document : NSDocument <NSTextViewDelegate, BeatOutlineViewEditorDelegate, NSTableViewDelegate, NSMenuDelegate, NSLayoutManagerDelegate, WKScriptMessageHandler, TouchPopoverDelegate, ContinuousFountainParserDelegate, BeatTimelineDelegate, TKSplitHandleDelegate, BeatTextViewDelegate, BeatTimerDelegate, BeatPluginDelegate, BeatTaggingDelegate, BeatEditorDelegate, NSWindowDelegate, DocumentExports>

@property(readonly, copy) NSArray<NSURL *> * _Nullable recentDocumentURLs;
@property (nonatomic, readonly) NSString* _Nullable preprocessedText;
@property (nonatomic) CGFloat magnification;
@property (nonatomic) bool printSceneNumbers;
@property (nonatomic) bool showPageNumbers;
@property (nonatomic) bool showSceneNumberLabels;
@property (nonatomic) bool revisionMode;
@property (nonatomic) bool showRevisions;
@property (nonatomic) bool showTags;
@property (nonatomic) BeatPaperSize pageSize;
@property (nonatomic) BeatExportSettings* _Nonnull exportSettings;
@property (nonatomic) bool contentLocked;
@property (nonatomic) bool characterInput;

@property (nonatomic) NSArray* _Nullable outline;
- (void)reloadOutline;

// Fonts
@property (strong, nonatomic) NSFont* _Nonnull courier;
@property (strong, nonatomic) NSFont* _Nonnull boldCourier;
@property (strong, nonatomic) NSFont* _Nonnull boldItalicCourier;
@property (strong, nonatomic) NSFont* _Nonnull italicCourier;

// For delegation
@property (nonatomic) NSUUID* _Nonnull uuid;
@property (nonatomic, weak) OutlineScene* _Nullable currentScene; // Don't retain the Outline Scene
@property (nonatomic) NSMutableIndexSet*  _Nullable changes;
@property (atomic) NSString*  _Nullable textCache;
@property (atomic) NSAttributedString*  _Nullable attrTextCache;
- (NSAttributedString* _Nullable)getAttributedText; // ONLY IN MAIN THREAD

// Character input
@property (nonatomic) Line* _Nullable characterInputForLine;

// Plugin support
@property (nonatomic) NSMutableDictionary <NSString*, BeatPlugin*>* _Nullable runningPlugins;
@property (weak) IBOutlet BeatWidgetView* _Nullable widgetView;

// Document settings
@property (atomic) BeatDocumentSettings* _Nullable documentSettings;

// Versioning
@property (nonatomic) NSURL* _Nullable revertedTo;

// Tagging
@property (nonatomic) IBOutlet BeatTagging* _Nullable tagging;

// Tab
@property (nonatomic) NSTabViewItem* _Nonnull currentTab;

// Content
- (NSString* _Nullable)text;
- (NSString* _Nullable)fileNameString;

- (void)setPrintSceneNumbers:(bool)value;
- (IBAction)togglePrintSceneNumbers:(id _Nullable)sender;
- (void)readUserSettings;
- (void)applyUserSettings;

// Analysis
@property (nonatomic) NSDictionary<NSString*, NSString*>* _Nullable characterGenders;

// Revision Tracking
@property (nonatomic) IBOutlet BeatRevisions* _Nonnull revisionTracking;
@property (nonatomic) NSString* _Nullable revisionColor;

// Set document colors
- (void)updateTheme;
- (bool)isDark;
- (void)updateUIColors;

// Mode
@property (nonatomic) BeatEditorMode mode;

// Review
@property (nonatomic) IBOutlet BeatReview* _Nullable review;

@property (nonatomic, readwrite) bool outlineEdit;
- (NSMutableArray* _Nullable)filteredOutline;

// Skip selection change events when needed
@property (nonatomic) bool skipSelectionChangeEvent;
@property (nonatomic) bool moving;

//- (void)setScaleFactor:(CGFloat)newScaleFactor adjustPopup:(BOOL)flag;
- (void)invalidatePreview;


// Scrolling

/// Scroll to given scene number (number is `NSString`)
- (void)scrollToSceneNumber:(NSString* __nullable)sceneNumber;
/// Scroll to given scene object.
- (void)scrollToScene:(OutlineScene* __nullable)scene;
/// Legacy method. Use selectAndScrollToRange
- (void)scrollToRange:(NSRange)range;
/// Scrolls to given range and runs a callback after animation is done.
- (void)scrollToRange:(NSRange)range callback:(nullable void (^)(void))callbackBlock;
/// Scrolls the given position into view
- (void)scrollTo:(NSInteger)location;
/// Selects the given line and scrolls it into view
- (void)scrollToLine:(Line* __nullable)line;
/// Selects the line at given index and scrolls it into view
- (void)scrollToLineIndex:(NSInteger)index;
/// Selects the scene at given index and scrolls it into view
- (void)scrollToSceneIndex:(NSInteger)index;
/// Selects the given range and scrolls it into view
- (void)selectAndScrollTo:(NSRange)range;

@end
