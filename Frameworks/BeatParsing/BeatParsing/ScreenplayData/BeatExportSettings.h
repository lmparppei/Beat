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

#import <BeatParsing/BeatPaperSizing.h>

typedef NS_ENUM(NSUInteger, BeatExportOperation) {
    ForPrint = 0,
    ForPreview,
    ForQuickLook
};

typedef NS_ENUM(NSUInteger, BeatExportRevisionHighlightMode) {
    BeatExportRevisionHighlightNone = 0,
    BeatExportRevisionHighlightColor,
    BeatExportRevisionHighlightBackground
};

// For future generations
typedef NS_OPTIONS(NSUInteger, BeatExportSettingIncludedElementMask) {
    BeatExportSettingIncludeNotes       = 1 << 0,
    BeatExportSettingIncludeSynopsis    = 1 << 1,
    BeatExportSettingIncludeSections    = 1 << 2
};

NS_ASSUME_NONNULL_BEGIN

// These will be used for the new dictionary-based setting delivery in the future
FOUNDATION_EXPORT NSString *const BeatExportSettingOperation;
FOUNDATION_EXPORT NSString *const BeatExportSettingPrintSceneNumbers;
FOUNDATION_EXPORT NSString *const BeatExportSettingStyles;
FOUNDATION_EXPORT NSString *const BeatExportSettingHidePageNumbers;
FOUNDATION_EXPORT NSString *const BeatExportSettingDocumentSettings;
FOUNDATION_EXPORT NSString *const BeatExportSettingInvisibleElements;

@class OutlineScene;
@class BeatDocumentSettings;

@protocol BeatExportStyleProvider
- (bool)shouldPrintSections;
- (bool)shouldPrintSynopses;
- (bool)overrideParagraphPaginationMode;
@end

@protocol BeatExportSettingDelegate
@property (nonatomic) bool printSceneNumbers;
@property (nonatomic) bool hidePageNumbers;
@property (nonatomic) bool showSceneNumberLabels;
@property (nonatomic) id styles;
@property (nonatomic) BeatDocumentSettings* documentSettings;
- (id)document; // We shouldn't need this anymore?
- (NSIndexSet*)shownRevisions;
- (NSString*)fileNameString;
- (BeatPaperSize)pageSize;
@end

@interface BeatExportSettings : NSObject

@property (nonatomic, weak) id<BeatExportSettingDelegate> delegate;
@property (nonatomic) BeatExportOperation operation;

@property (nonatomic) NSString* header;
@property (nonatomic) NSInteger headerAlignment;

@property (nonatomic) BeatExportSettingIncludedElementMask invisibleElements;

@property (nonatomic) bool printNotes;
@property (nonatomic) bool printSceneNumbers;
@property (nonatomic) bool hidePageNumbers;

@property (nonatomic) NSIndexSet* additionalTypes; // LineType enums in an index set

@property (nonatomic) NSString* fileName;
@property (nonatomic, weak) BeatHostDocument  * _Nullable document;

@property (nonatomic) NSIndexSet* revisions;
@property (nonatomic) BeatPaperSize paperSize;

/// When set `true`, scene headings are rendered as simply text, without the table-like layout. Used by RTF/DOC export.
@property (nonatomic) bool simpleSceneHeadings;

/// Set `true` if you want to print the heading color
@property (nonatomic) bool printSceneHeadingColors;

/// Styles for new pagination / export system
@property (nonatomic) id _Nullable styles;

/// Custom CSS for HTML rendering
@property (nonatomic) NSString * _Nullable customCSS;
/// Custom styles for the new, native rendering
@property (nonatomic) NSString * _Nullable customStyles;
/// Raw document settings 
@property (nonatomic) BeatDocumentSettings* documentSettings;

@property (nonatomic) NSInteger firstPageNumber;

@property (nonatomic) BeatExportRevisionHighlightMode revisionHighlightMode;

+ (BeatExportSettings*)operation:(BeatExportOperation)operation document:(BeatHostDocument* _Nullable)doc header:(NSString*)header printSceneNumbers:(bool)printSceneNumbers;

+ (BeatExportSettings*)operation:(BeatExportOperation)operation document:(BeatHostDocument* _Nullable)doc header:(NSString*)header printSceneNumbers:(bool)printSceneNumbers revisions:(NSIndexSet*)revisions;

+ (BeatExportSettings*)operation:(BeatExportOperation)operation document:(BeatHostDocument* _Nullable)doc header:(NSString*)header printSceneNumbers:(bool)printSceneNumbers revisions:(NSIndexSet*)revisions scene:(NSString* _Nullable )scene;

+ (BeatExportSettings*)operation:(BeatExportOperation)operation document:(BeatHostDocument* _Nullable)doc header:(NSString*)header printSceneNumbers:(bool)printSceneNumbers printNotes:(bool)printNotes revisions:(NSIndexSet*)revisions scene:(NSString* _Nullable )scene;

+ (BeatExportSettings*)operation:(BeatExportOperation)operation delegate:(id<BeatExportSettingDelegate>)delegate;

- (BeatPaperSize)paperSize; /// Get page size. For safety reasons, the value is checked from the actual print settings

@end

NS_ASSUME_NONNULL_END
