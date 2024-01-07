//
//  Document.h
//  Beat
//
//  Released under GPL.
//  Copyright © 2019-2023 Lauri-Matti Parppei
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
#import <BeatPlugins/BeatPlugins.h>

#import "TouchTimelineView.h"
#import "TouchTimelinePopover.h"
#import "BeatTimeline.h"
#import "TKSplitHandle.h"
#import "BeatTimer.h"
#import "BeatOutlineView.h"
#import "BeatStatisticsPanel.h"


@class BeatReview;
@class BeatWidgetView;
@class BeatTextIO;


@interface Document : BeatDocumentBaseController <NSTextViewDelegate, BeatOutlineViewEditorDelegate, NSTableViewDelegate, NSMenuDelegate, NSLayoutManagerDelegate, TouchPopoverDelegate, ContinuousFountainParserDelegate, TKSplitHandleDelegate, BeatTimerDelegate, BeatPluginDelegate, BeatTaggingDelegate, BeatEditorDelegate, NSWindowDelegate>

@property(readonly, copy) NSArray<NSURL *> * _Nullable recentDocumentURLs;
@property (nonatomic, readonly) NSString* _Nullable preprocessedText;
@property (nonatomic) CGFloat magnification;

@property (nonatomic) bool showPageNumbers;
@property (nonatomic) bool showRevisions;
@property (nonatomic) bool showTags;

@property (nonatomic) bool revisionMode;

@property (nonatomic) bool contentLocked;

- (void)reloadOutline;

@property (nonatomic) NSMutableIndexSet*  _Nullable changes;

// Plugin support
@property (weak) IBOutlet BeatWidgetView* _Nullable widgetView;

// Versioning
@property (nonatomic) NSURL* _Nullable revertedTo;

// Tab
@property (nonatomic) NSTabViewItem* _Nonnull currentTab;

- (IBAction)togglePrintSceneNumbers:(id _Nullable)sender;
- (void)readUserSettings;
- (void)applyUserSettings;

// Analysis
@property (nonatomic) NSDictionary<NSString*, NSString*>* _Nullable characterGenders;

// Set document colors
- (void)updateTheme;
- (bool)isDark;
- (void)updateUIColors;

// Mode
@property (nonatomic) BeatEditorMode mode;

@property (nonatomic, readwrite) bool outlineEdit;
- (NSMutableArray* _Nullable)filteredOutline;

@property (nonatomic) bool moving;


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
