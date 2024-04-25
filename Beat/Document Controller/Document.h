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
@class BeatTimeline;
@class BeatSegmentedControl;
@class ColorView;
@class ScrollView;
@class MarginView;
@class BeatTimer;
@class BeatLockButton;

@interface Document : BeatDocumentBaseController <NSTextViewDelegate, BeatOutlineViewEditorDelegate, NSTableViewDelegate, NSMenuDelegate, NSLayoutManagerDelegate, ContinuousFountainParserDelegate, TKSplitHandleDelegate, BeatTimerDelegate, BeatPluginDelegate, BeatTaggingDelegate, BeatEditorDelegate>


#pragma mark - Editor flags

/// Current editor magnification. This value is forwarded from text view.
@property (nonatomic) CGFloat magnification;

/// Current editor view. This is __not__ a sidebar tab, but the underlying tab view in full document view. Editor, preview and index cards are different tabs.
@property (nonatomic) NSTabViewItem* _Nonnull currentTab;

@property (nonatomic) bool showRevisions;
@property (nonatomic) bool showTags;
@property (nonatomic) bool revisionMode;
@property (nonatomic) bool contentLocked;
@property (nonatomic) BOOL autosave;
@property (nonatomic) BOOL sidebarVisible;

@property (weak) IBOutlet TKSplitHandle* _Nullable splitHandle;

/// Current editor mode flag. Changing this should change the editor behavior as well.
@property (nonatomic) BeatEditorMode mode;

/// For versioning support. This is probably not used right now.
@property (nonatomic) NSURL* _Nullable revertedTo;

- (bool)isFullscreen;


#pragma mark - Applying settings

- (void)readUserSettings;
- (void)applyUserSettings;


#pragma mark - Outline data

@property (nonatomic) NSMutableIndexSet*  _Nullable changes;
@property (nonatomic, readwrite) bool outlineEdit;
@property (nonatomic) bool moving;


#pragma mark - Plugin support

@property (weak) IBOutlet BeatWidgetView* _Nullable widgetView;
/// Returns gender JSON from document settings.
@property (nonatomic) NSDictionary<NSString*, NSString*>* _Nullable characterGenders;



#pragma mark - Window controls

@property (nonatomic, weak) NSWindow* _Nullable currentKeyWindow;


#pragma mark - Tabs

@property (weak) IBOutlet NSTabViewItem* _Nullable editorTab;
@property (weak) IBOutlet NSTabViewItem* _Nullable previewTab;
@property (weak) IBOutlet NSTabViewItem* _Nullable cardsTab;
@property (weak) IBOutlet NSTabViewItem* _Nullable nativePreviewTab;

/// Sidebar tab for outline view
@property (nonatomic, weak) IBOutlet NSTabViewItem* _Nullable tabOutline;
/// Sidebar tab for notepad view
@property (nonatomic, weak) IBOutlet NSTabViewItem* _Nullable tabNotepad;
/// Sidebar tab for dialogue and character view
@property (nonatomic, weak) IBOutlet NSTabViewItem* _Nullable tabDialogue;
/// Sidebar tab for reviews
@property (nonatomic, weak) IBOutlet NSTabViewItem* _Nullable tabReviews;
/// Sidebar tab for widgets. Usually hidden, unless a plugin registers a widget.
@property (nonatomic, weak) IBOutlet NSTabViewItem* _Nullable tabWidgets;


#pragma mark - Buttons

@property (nonatomic, weak) IBOutlet NSButton* _Nullable outlineButton;
@property (nonatomic, weak) IBOutlet NSButton* _Nullable previewButton;
@property (nonatomic, weak) IBOutlet NSButton* _Nullable timelineButton;
@property (nonatomic, weak) IBOutlet NSButton* _Nullable cardsButton;


#pragma mark - Views

/// Scroll view which holds the text view
@property (weak, nonatomic) IBOutlet ScrollView* _Nullable textScrollView;
/// View which draws the "margins" and the fake "paper" behind editor.
@property (weak, nonatomic) IBOutlet MarginView* _Nullable marginView;
/// Bottom timeline view
@property (weak) IBOutlet BeatTimeline* _Nullable timeline;

/// The __main__ tab view (holds the main editor/preview/card views)
@property (weak) IBOutlet NSTabView* _Nullable tabView;
/// Master background view
@property (weak) IBOutlet ColorView* _Nullable backgroundView;
/// Background for outline
@property (weak) IBOutlet ColorView* _Nullable outlineBackgroundView;

/// Outline view
@property (weak) IBOutlet BeatOutlineView* _Nullable outlineView;

/// Sidebar tab view
@property (weak) IBOutlet NSTabView* _Nullable sideBarTabs;
/// Segmented control which switches the sidebar view
@property (weak) IBOutlet BeatSegmentedControl* _Nullable sideBarTabControl;

/// Productivity timer. Should probably be moved somewhere else.
@property (weak) IBOutlet BeatTimer* _Nullable beatTimer;

/// Lock button
@property (nonatomic, weak) IBOutlet BeatLockButton* _Nullable lockButton;


#pragma mark - Scrolling methods (move these elsewhere)

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

/// Some menu items to validate. This should be removed at some point.
@property (nonatomic) NSArray* _Nullable itemsToValidate;

@end
