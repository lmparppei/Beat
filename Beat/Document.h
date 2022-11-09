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

#import "BeatTextView.h"
#import "TouchTimelineView.h"
#import "TouchTimelinePopover.h"
#import "SceneCards.h"
#import "BeatTimeline.h"
#import "TKSplitHandle.h"
#import "BeatTimer.h"
#import "BeatPreview.h"
#import "BeatPlugin.h"
#import "BeatOutlineView.h"
#import "BeatStatisticsPanel.h"
#import "BeatEditorDelegate.h"
#import "BeatRevisions.h"
#import "BeatRevisionItem.h"

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

@protocol DocumentExports <JSExport>
@property (nonatomic, readonly) ContinuousFountainParser *parser;
@property (atomic) BeatDocumentSettings *documentSettings;
- (NSMutableArray<Line*>*)lines;
@end

@interface Document : NSDocument <NSTextViewDelegate, BeatOutlineViewEditorDelegate, NSTableViewDelegate, NSMenuDelegate, NSLayoutManagerDelegate, WKScriptMessageHandler, TouchTimelineDelegate, TouchPopoverDelegate, ContinuousFountainParserDelegate, BeatTimelineDelegate, TKSplitHandleDelegate, BeatTextViewDelegate, BeatTimerDelegate, BeatPreviewDelegate, BeatScriptingDelegate, BeatTaggingDelegate, BeatEditorDelegate, NSWindowDelegate, DocumentExports, BeatPaginatorDelegate>

@property (strong, nonatomic) NSMutableArray<BeatPrintView*>* printViews; //To keep the asynchronously working print data generator in memory

@property(readonly, copy) NSArray<NSURL *> *recentDocumentURLs;
@property (nonatomic, readonly) NSString* preprocessedText;
@property (nonatomic) CGFloat magnification;
@property (nonatomic) CGFloat inset;
@property (nonatomic) bool printSceneNumbers;
@property (nonatomic) bool revisionMode;
@property (nonatomic) bool showRevisions;
@property (nonatomic) bool showTags;
@property (nonatomic) BeatPaperSize pageSize;

@property (nonatomic) bool contentLocked;

// Fonts
@property (strong, nonatomic) NSFont *courier;
@property (strong, nonatomic) NSFont *boldCourier;
@property (strong, nonatomic) NSFont *boldItalicCourier;
@property (strong, nonatomic) NSFont *italicCourier;

// For delegation
@property (nonatomic, weak) OutlineScene *currentScene; // Don't retain the Outline Scene
@property (nonatomic) NSMutableIndexSet *changes;
@property (atomic) NSString *textCache;
@property (atomic) NSAttributedString *attrTextCache;
- (NSAttributedString*)getAttributedText; // ONLY IN MAIN THREAD

// Character input
@property (nonatomic) Line* characterInputForLine;

// Plugins running in this window
@property (nonatomic) NSMutableDictionary <NSString*, BeatPlugin*>* runningPlugins;

// Document settings
@property (atomic) BeatDocumentSettings *documentSettings;

// Versioning
@property (nonatomic) NSURL *revertedTo;

// Tagging
@property (nonatomic) IBOutlet BeatTagging *tagging;

// Tab
@property (nonatomic) NSTabViewItem *currentTab;

// Content
- (NSString*)text;
- (NSString*)fileNameString;

- (void)setPrintSceneNumbers:(bool)value;
- (IBAction)togglePrintSceneNumbers:(id)sender;
- (void)readUserSettings;
- (void)applyUserSettings;

// Analysis
@property (nonatomic) NSMutableDictionary<NSString*, NSString*> *characterGenders;

// Revision Tracking
@property (nonatomic) IBOutlet BeatRevisions *revisionTracking;
@property (nonatomic) NSString *revisionColor;

// Set document colors
- (void)updateTheme;
- (bool)isDark;
- (void)updateUIColors;

// Mode
@property (nonatomic) BeatEditorMode mode;

// Review
@property (nonatomic) IBOutlet BeatReview *review;

@property (nonatomic, readwrite) bool outlineEdit;
- (NSMutableArray*)filteredOutline;

// Skip selection change events when needed
@property (nonatomic) bool skipSelectionChangeEvent;

//- (void)setScaleFactor:(CGFloat)newScaleFactor adjustPopup:(BOOL)flag;
- (void)invalidatePreview;
@end
