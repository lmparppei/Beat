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
#import "BeatTextView.h"


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
@class BeatNotepadView;
@class BeatOnOffMenuItem;
@class BeatModeDisplay;
@class BeatEditorFormatting;

@interface Document : BeatDocumentBaseController <BeatEditorDelegate, NSLayoutManagerDelegate, ContinuousFountainParserDelegate, TKSplitHandleDelegate, BeatTimerDelegate>

/// Main document window. Because Beat originates from antiquated code, we are not using a document view controller, but something else. I'm not exactly sure what.
@property (weak) NSWindow* _Nullable documentWindow;


#pragma mark - Editor flags

/// Current editor magnification. This value is forwarded from text view.
@property (nonatomic) CGFloat magnification;

/// Current editor view. This is __not__ a sidebar tab, but the underlying tab view in full document view. Editor, preview and index cards are different tabs.
@property (nonatomic) NSTabViewItem* _Nonnull currentTab;

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

/// Sheet view (strong reference for avoiding weirdness)
@property (nonatomic) NSWindowController* _Nullable sheetController;

/// Toggles user default or document setting value on or off. Requires `BeatOnOffMenuItem` with a defined `settingKey`.
- (IBAction)toggleSetting:(BeatOnOffMenuItem* _Nonnull)menuItem;

/// Check for dark mode
- (bool)isDark;


#pragma mark - Applying settings

- (void)readUserSettings;
- (void)applyUserSettings;


#pragma mark - Outline data

@property (nonatomic, readwrite) bool outlineEdit;


#pragma mark - Plugin support

@property (weak) IBOutlet BeatWidgetView* _Nullable widgetView;


#pragma mark - Window controls

@property (nonatomic, weak) NSWindow* _Nullable currentKeyWindow;
@property (nonatomic) NSWindowController* _Nullable tagManager;

/// Mode indicator view at the top of the editor
@property (weak) IBOutlet BeatModeDisplay *modeIndicator;


#pragma mark - Tabs

@property (weak) IBOutlet NSTabViewItem* _Nullable editorTab;
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

/// Main text view
@property (weak, nonatomic) IBOutlet BeatTextView* _Nullable textView;

/// Scroll view which holds the text view
@property (weak, nonatomic) IBOutlet ScrollView* _Nullable textScrollView;
/// View which draws the "margins" and the fake "paper" behind editor.
@property (weak, nonatomic) IBOutlet MarginView* _Nullable marginView;
/// Bottom timeline view
@property (weak) IBOutlet BeatTimeline* _Nullable timeline;

/// Right side view constraint
@property (nonatomic, weak) IBOutlet NSLayoutConstraint* _Nullable rightSidebarConstraint;
/// Tagging view on the right side of the screen
@property (weak) IBOutlet NSTextView* _Nullable tagTextView;

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

/// Notepad view
@property (nonatomic, weak) IBOutlet BeatNotepad* _Nullable notepad;

@property (nonatomic) NSMutableArray<NSWindowController*>* _Nullable additionalPanels;

/// Assisting windows
@property (nonatomic) NSMutableDictionary<NSValue*,NSWindow*>* _Nullable assistingWindows;

@property (nonatomic, weak) IBOutlet NSButton* _Nullable quickSettingsButton;
@property (nonatomic) NSPopover* _Nullable quickSettingsPopover;


#pragma mark - Touch bar

@property (nonatomic) NSColorPickerTouchBarItem* _Nullable colorPicker;

/// Some menu items to validate. This should be removed at some point.
@property (nonatomic) NSArray* _Nullable itemsToValidate;


#pragma mark - Other values

/// The range where last actual edit happened in text storage
@property (nonatomic) NSRange lastEditedRange;


#pragma mark - Action handlers

/// A collection of actions for quick inline formatting etc. Instantiated in the XIB for some reason.
@property (nonatomic, weak) IBOutlet BeatEditorFormattingActions *formattingActions;


#pragma mark - Initial formatting

/// This class handles the first-time format of the editor text to spare some CPU time. It has to be retained in memory but can be released once loading is complete.
@property (nonatomic) BeatEditorFormatting* _Nullable initialFormatting;
/// When loading longer documents, we need to show a progress panel
@property (nonatomic) NSPanel* _Nullable progressPanel;
/// The indicator for above panel
@property (nonatomic) NSProgressIndicator* _Nullable progressIndicator;

- (void)loadingComplete;

@end
