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
#import "BeatTextView.h"
#import "TouchTimelineView.h"
#import "TouchTimelinePopover.h"
#import "ContinousFountainParser.h"
#import "SceneCards.h"
#import "BeatTimeline.h"
#import "TKSplitHandle.h"
#import "BeatTimer.h"
#import "BeatDocumentSettings.h"
#import "BeatPreview.h"
#import "BeatScriptParser.h"
#import "BeatOutlineView.h"
#import "BeatAnalysisPanel.h"

// Forward declaration to make parser available for text view
@class BeatTextView;

@interface Document : NSDocument <NSTextViewDelegate, NSOutlineViewDataSource, NSOutlineViewDelegate, NSTableViewDelegate, NSMenuDelegate, NSLayoutManagerDelegate, WKScriptMessageHandler, TouchTimelineDelegate, TouchPopoverDelegate, ContinuousFountainParserDelegate, SceneCardDelegate, BeatTimelineDelegate, TKSplitHandleDelegate, BeatTextViewDelegate, BeatTimerDelegate, BeatPreviewDelegate, BeatScriptingDelegate, BeatAnalysisDelegate, BeatTaggingDelegate>

@property(readonly, copy) NSArray<NSURL *> *recentDocumentURLs;
@property (nonatomic, readonly) NSString* preprocessedText;
@property (nonatomic) CGFloat magnification;
@property (nonatomic) bool printSceneNumbers;
 
// Fonts
@property (strong, nonatomic) NSFont *courier;
@property (strong, nonatomic) NSFont *boldCourier;
@property (strong, nonatomic) NSFont *italicCourier;

// For delegation
@property (nonatomic) OutlineScene *currentScene;

// Document settings
@property (nonatomic) BeatDocumentSettings *documentSettings;

- (NSString*)getText;
- (NSString*)fileNameString;
// Make some of the actions available for text view
// (wtf btw, why aren't we using these through delegation?)
- (IBAction)forceAction:(id)sender;
- (IBAction)forceHeading:(id)sender;
- (IBAction)forceCharacter:(id)sender;
- (OutlineScene*)getCurrentScene;

// Analysis
@property (nonatomic) NSMutableDictionary *characterGenders;

// Set document colors
- (void)updateTheme;
- (bool)isDark;

// Tagging
@property (nonatomic) BeatEditorMode mode;

@end
