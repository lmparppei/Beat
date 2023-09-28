//
//  BeatExportSettings.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 22.6.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <TargetConditionals.h>

#if TARGET_OS_IOS
    #import <UIKit/UIKit.h>
    #define BeatHostDocument UIDocument
#else
    #import <Cocoa/Cocoa.h>
    #define BeatHostDocument NSDocument
#endif

#import "BeatPaperSizing.h"

NS_ASSUME_NONNULL_BEGIN

@class OutlineScene;
@class BeatDocumentSettings;

@protocol BeatExportSettingDelegate
@property (nonatomic) bool printSceneNumbers;
@property (nonatomic) bool showSceneNumbers;
@property (nonatomic) id document;
@property (nonatomic) BeatDocumentSettings* documentSettings;
- (NSArray<NSString*>*)shownRevisions;
- (NSString*)fileNameString;
- (BeatPaperSize)pageSize;
@end

typedef NS_ENUM(NSUInteger, BeatHTMLOperation) {
	ForPrint = 0,
	ForPreview,
	ForQuickLook
};

@interface BeatExportSettings : NSObject
@property (nonatomic, weak) id<BeatExportSettingDelegate> delegate;
@property (nonatomic) NSString *header;
@property (nonatomic) BeatHTMLOperation operation;
@property (nonatomic) NSString * _Nullable pageRevisionColor;
@property (nonatomic) bool coloredPages;

@property (nonatomic) bool printNotes;
//@property (nonatomic) bool printSections;
//@property (nonatomic) bool printSynopsis;
@property (nonatomic) bool printSceneNumbers;

@property (nonatomic) NSIndexSet* additionalTypes; // This is actually LineType

@property (nonatomic) NSString *fileName;
@property (nonatomic, weak) BeatHostDocument  * _Nullable document;

@property (nonatomic) NSArray * revisions;
@property (nonatomic) BeatPaperSize paperSize;

/// Styles for new pagination / export system
@property (nonatomic) id _Nullable styles;

/// Custom CSS for HTML rendering
@property (nonatomic) NSString * _Nullable customCSS;
/// Custom styles for the new, native rendering
@property (nonatomic) NSString * _Nullable customStyles;

+ (BeatExportSettings*)operation:(BeatHTMLOperation)operation document:(BeatHostDocument* _Nullable)doc header:(NSString*)header  printSceneNumbers:(bool)printSceneNumbers;

+ (BeatExportSettings*)operation:(BeatHTMLOperation)operation document:(BeatHostDocument*)doc header:(NSString*)header printSceneNumbers:(bool)printSceneNumbers revisions:(NSArray*)revisions;

+ (BeatExportSettings*)operation:(BeatHTMLOperation)operation document:(BeatHostDocument*)doc header:(NSString*)header printSceneNumbers:(bool)printSceneNumbers revisions:(NSArray*)revisions scene:(NSString* _Nullable )scene;

+ (BeatExportSettings*)operation:(BeatHTMLOperation)operation document:(BeatHostDocument*)doc header:(NSString*)header printSceneNumbers:(bool)printSceneNumbers printNotes:(bool)printNotes revisions:(NSArray*)revisions scene:(NSString* _Nullable )scene coloredPages:(bool)coloredPages revisedPageColor:(NSString*)revisedPagecolor;

+ (BeatExportSettings*)operation:(BeatHTMLOperation)operation delegate:(id<BeatExportSettingDelegate>)delegate;

- (BeatPaperSize)paperSize; /// Get page size. For safety reasons, the value is checked from the actual print settings

@end

NS_ASSUME_NONNULL_END
