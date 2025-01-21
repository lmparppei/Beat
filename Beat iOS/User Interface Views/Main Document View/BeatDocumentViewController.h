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

@interface BeatDocumentViewController : BeatDocumentBaseController <BeatEditorDelegate, ContinuousFountainParserDelegate, BeatPluginDelegate>

@property (nonatomic) iOSDocument* document;
@property (weak, readonly) BXWindow* documentWindow;

@property (nonatomic) UIDocumentBrowserViewController *documentBrowser;

/// Main editor view
@property (nonatomic) BeatUITextView* textView;
/// Sidebar outline view
@property (nonatomic, weak) IBOutlet BeatiOSOutlineView* outlineView;

@property (nonatomic) BeatEditorFormattingActions* formattingActions;

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

@end

NS_ASSUME_NONNULL_END
