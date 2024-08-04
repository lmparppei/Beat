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

@interface BeatDocumentViewController : BeatDocumentBaseController <BeatEditorDelegate, UITextViewDelegate, ContinuousFountainParserDelegate, BeatPluginDelegate>

@property (nonatomic) iOSDocument* document;
@property (weak, readonly) BXWindow* documentWindow;

@property (nonatomic) UIDocumentBrowserViewController *documentBrowser;

@property (nonatomic) BeatEditorFormattingActions* formattingActions;

// Editor flags
@property (nonatomic) bool revisionMode;
@property (nonatomic) BeatEditorMode mode;
@property (nonatomic, readonly) bool hideFountainMarkup;

@property (nonatomic) bool showRevisions;
@property (nonatomic) bool showTags;

- (void)loadDocumentWithCallback:(void (^)(void))callback;

@property (nonatomic, weak) IBOutlet UINavigationItem* titleBar;

@property (nonatomic, weak) IBOutlet UIBarButtonItem* screenplayButton;
@property (nonatomic, weak) IBOutlet UIBarButtonItem* dismissKeyboardButton;

- (IBAction)togglePreview:(id)sender;
- (IBAction)toggleCards:(id)sender;

@end

NS_ASSUME_NONNULL_END
