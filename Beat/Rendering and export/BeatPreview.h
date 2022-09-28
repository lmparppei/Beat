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

#if TARGET_OS_IOS
	#import <UIKit/UIKit.h>
#else
	#import <Cocoa/Cocoa.h>
#endif

#import "OutlineScene.h"
#import "BeatDocumentSettings.h"
#import "BeatEditorDelegate.h"

typedef NS_ENUM(NSUInteger, BeatPreviewType) {
	BeatPrintPreview = 0,
	BeatQuickLookPreview,
	BeatComparisonPreview
};

@class BeatPaginator;

@protocol BeatPreviewExports <JSExport>
@property (nonatomic, readonly) NSString* htmlString;
@property (nonatomic, readonly) bool previewUpdated;
@property (nonatomic, readonly) BeatPaginator* paginator;
@property (nonatomic, readonly) ContinuousFountainParser* parser;
@end

@protocol BeatPreviewDelegate
@property (atomic) BeatDocumentSettings *documentSettings;
@property (nonatomic) bool printSceneNumbers;
@property (nonatomic, readonly, weak) OutlineScene *currentScene;
@property (readonly) NSAttributedString *attrTextCache;
@property (nonatomic, readonly) BeatPaperSize pageSize;
- (NSString*)text;
- (id)document;
- (void)previewDidFinish;
@end

@interface BeatPreview : NSObject <BeatPreviewExports>
@property (nonatomic, weak) IBOutlet id<BeatPreviewDelegate, BeatEditorDelegate> delegate;
@property (nonatomic) NSString* htmlString;
@property (nonatomic) NSTimer* previewTimer;
@property (nonatomic) bool previewUpdated;
@property (nonatomic, weak) IBOutlet WKWebView *previewView;
@property (nonatomic) BeatPaginator* paginator;
- (id) initWithDocument:(id)document;
- (NSString*)createPreview;
- (NSString*)createPreviewFor:(NSString*)rawScript type:(BeatPreviewType)previewType;
- (NSString*)createPreviewFromPaginator:(BeatPaginator*)paginator;
- (void)displayPreview;
- (void)updatePreviewInSync:(bool)sync;
- (void)updatePreviewWithPages:(NSArray*)pages titlePage:(NSArray*)titlePage;
- (void)updatePreviewSynchronized;
- (void)setup;
- (void)deallocPreview;
@end
