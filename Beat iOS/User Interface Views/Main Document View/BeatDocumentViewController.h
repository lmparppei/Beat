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

@interface BeatDocumentViewController : UIViewController <BeatEditorDelegate, UITextViewDelegate, ContinuousFountainParserDelegate, BeatPluginDelegate>

@property (nonatomic) iOSDocument* document;
@property (weak, readonly) BXWindow* documentWindow;

@property (nonatomic) BeatDocumentSettings *documentSettings;

@property (nonatomic) UIDocumentBrowserViewController *documentBrowser;

@property (nonatomic) bool printSceneNumbers;
@property (nonatomic) BeatEditorFormattingActions* formattingActions;

// Editor flags
@property (nonatomic) bool revisionMode;
@property (nonatomic) bool characterInput;
@property (nonatomic) Line* _Nullable characterInputForLine;
@property (nonatomic) BeatEditorMode mode;
@property (nonatomic, readonly) bool hideFountainMarkup;

@property (nonatomic) ContinuousFountainParser *parser;

@property (nonatomic) BeatPaperSize pageSize;

@property (nonatomic, weak) Line* currentLine; // Current line has to be weak so we don't keep anything weird in memory
@property (nonatomic) bool moving;

@property (nonatomic) bool showSceneNumberLabels;
@property (nonatomic) bool showRevisions;
@property (nonatomic) bool showTags;
@property (nonatomic) NSString* revisionColor;

@property (nonatomic) NSDictionary<NSString*,NSString*>* characterGenders;


// Fonts
@property (strong, nonatomic) BXFont* _Nonnull courier;
@property (strong, nonatomic) BXFont* _Nonnull boldCourier;
@property (strong, nonatomic) BXFont* _Nonnull boldItalicCourier;
@property (strong, nonatomic) BXFont* _Nonnull italicCourier;


@property (nonatomic) bool skipSelectionChangeEvent;

@property (nonatomic) NSInteger sceneNumberingStartsFrom;

- (void)loadDocumentWithCallback:(void (^)(void))callback;

@end

NS_ASSUME_NONNULL_END
