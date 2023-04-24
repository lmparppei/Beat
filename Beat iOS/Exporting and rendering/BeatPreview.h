//
//  BeatPreview.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 17.5.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

#import <TargetConditionals.h>
#import <WebKit/WebKit.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import <BeatParsing/BeatParsing.h>

#if TARGET_OS_IOS
	#import <UIKit/UIKit.h>
#else
	#import <Cocoa/Cocoa.h>
#endif

#import <BeatCore/BeatEditorDelegate.h>

typedef NS_ENUM(NSUInteger, BeatPreviewType) {
	BeatPrintPreview = 0,
	BeatQuickLookPreview,
	BeatComparisonPreview
};

@class BeatPaginationManager;
@class BeatPagination;
@class BeatPreviewView;

@protocol BeatPreviewExports <JSExport>
@property (nonatomic, readonly) NSString* htmlString;
@property (nonatomic, readonly) bool previewUpdated;
@property (nonatomic, readonly) ContinuousFountainParser* parser;
@end

@protocol BeatPreviewDelegate <BeatEditorDelegate>
@property (atomic) BeatDocumentSettings *documentSettings;
@property (nonatomic) bool printSceneNumbers;
@property (nonatomic, readonly, weak) OutlineScene *currentScene;
@property (readonly) NSAttributedString *attrTextCache;
@property (readonly) BeatPaginationManager *pagination;
@property (nonatomic, readonly) BeatPreviewView* previewView;

- (NSString*)text;
- (id)document;
- (void)previewDidFinish;
@end

@interface BeatPreview : NSObject <BeatPreviewExports>
@property (nonatomic, weak) IBOutlet id<BeatPreviewDelegate> delegate;
@property (nonatomic) NSString* htmlString;
@property (nonatomic) NSTimer* previewTimer;
@property (nonatomic) bool previewUpdated;

- (id)initWithDelegate:(id<BeatPreviewDelegate>)delegate;
- (NSString*)createPreview;
- (NSString*)createPreviewFor:(NSString*)rawScript type:(BeatPreviewType)previewType;

- (void)displayPreview;

- (void)updatePreviewSynchronized;
- (void)updatePreviewAsync;
- (void)setup;
- (void)deallocPreview;
@end
