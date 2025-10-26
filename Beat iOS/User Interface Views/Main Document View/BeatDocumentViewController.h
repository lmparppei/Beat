//
//  BeatDocumentViewController.h
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 18.2.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <BeatCore/BeatCore.h>
#import <BeatPlugins/BeatPlugins.h>

NS_ASSUME_NONNULL_BEGIN

@class iOSDocument;
@class BeatUITextView;
@class BeatiOSOutlineView;
@class BeatScrollView;
@class BeatEditorSplitViewController;

@interface BeatDocumentViewController : BeatDocumentBaseController <BeatEditorDelegate, ContinuousFountainParserDelegate, BeatPluginDelegate>

@property (nonatomic) iOSDocument* _Nullable document;
@property (weak, readonly) BXWindow* documentWindow;

@property (nonatomic, weak) UIDocumentBrowserViewController* _Nullable documentBrowser;

/// Main scroll view
@property (nonatomic) IBOutlet BeatScrollView* _Nullable scrollView;

/// Split view. Defined in storyboard segue.
@property (nonatomic, weak) BeatEditorSplitViewController* _Nullable editorSplitView;
@property (nonatomic, weak) IBOutlet UIView* _Nullable splitViewContainer;

/// Main editor view
@property (nonatomic, weak) BeatUITextView* _Nullable textView;
/// Sidebar outline view
@property (nonatomic, weak) IBOutlet BeatiOSOutlineView* outlineView;

@property (nonatomic) BeatEditorFormattingActions* _Nullable formattingActions;

// Editor flags
@property (nonatomic) bool revisionMode;
@property (nonatomic) BeatEditorMode mode;

@property (nonatomic) bool showRevisions;
@property (nonatomic) bool showTags;

- (void)loadDocumentWithCallback:(void (^)(void))callback;

@property (nonatomic, weak) IBOutlet UINavigationItem* titleBar;

@property (nonatomic, weak) IBOutlet UIBarButtonItem* screenplayButton;
@property (nonatomic, weak) IBOutlet UIBarButtonItem* dismissKeyboardButton;

/// Set to true when text storage is processing an edit
@property (nonatomic) bool processingEdit;
/// The range where the *edit* happened
@property (nonatomic) NSRange lastEditedRange;


- (IBAction)togglePreview:(id _Nullable)sender;
- (IBAction)toggleCards:(id _Nullable)sender;
- (IBAction)toggleNotepad:(id _Nullable)sender;

/// This is called by `iOSDocument` after closing the document
- (void)unloadViews;

@end

NS_ASSUME_NONNULL_END
