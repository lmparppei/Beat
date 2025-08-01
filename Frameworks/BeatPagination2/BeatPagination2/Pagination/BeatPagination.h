//
//  BeatPagination.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 11.12.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <BeatParsing/BeatParsing.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import <BeatCore/BeatCore.h>

#import <BeatPagination2/BeatPaginationPage.h>
#import <BeatPagination2/BeatPaginationBlock.h>

#if TARGET_OS_IOS
    #define BXFont UIFont
    #define uuidEqualTo isEqual
    #import <UIKit/UIKit.h>
#else
    #define BXFont NSFont
    #define uuidEqualTo isEqualTo
    #import <Cocoa/Cocoa.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@class BeatFontSet;
@class BeatStylesheet;
@class BeatPagination;
@class BeatPaginationPage;
@class BeatPaginationBlock;
@class BeatPaginationManager;
@class BeatRenderer;

typedef NS_ENUM(NSInteger, BeatPageNumberingMode) {
    BeatPageNumberingModeDefault = 0,
    BeatPageNumberingModeFirstScene,
    BeatPageNumberingModeFirstPageBreak,
    BeatPageNumberingModeForcedOnly
};

typedef NS_ENUM(NSInteger, BeatParagraphPaginationMode) {
    BeatParagraphPaginationModeDefault = 0,
    BeatParagraphPaginationModeAvoid,
    BeatParagraphPaginationModeUnderFourLines
};


@protocol BeatPaginationDelegate
@property (weak, nonatomic) BeatRenderer* _Nullable renderer;
@property (nonatomic) BeatExportSettings *settings;
@property (nonatomic) id<BeatEditorDelegate> __nullable editorDelegate;
- (void)paginationFinished:(BeatPagination*)pagination;
@end

@protocol BeatPaginationExports <JSExport>
@property (nonatomic) NSMutableArray<BeatPaginationPage*>* pages;
@property (nonatomic) BeatExportSettings* settings;
@property (nonatomic) NSArray<NSDictionary<NSString*, NSArray<Line*>*>*>* __nullable titlePageContent;

@property (nonatomic) bool success;
@property (nonatomic, readonly) CGFloat maxPageHeight;

- (NSInteger)findPageIndexForLine:(Line*)line;
- (NSInteger)findPageIndexAt:(NSInteger)position;
- (CGFloat)heightForScene:(OutlineScene*)scene;
- (CGFloat)heightForRange:(NSRange)range;

- (NSInteger)pageIndexForScene:(OutlineScene*)scene;
- (NSInteger)pageNumberForScene:(OutlineScene*)scene;
- (NSInteger)pageNumberAt:(NSInteger)location;

- (NSArray<BeatPageBreak*>*)pageBreaks;

@end

@protocol BeatPageDelegate
@property (nonatomic, readonly) bool canceled;
@property (weak, nonatomic) BeatRenderer* __nullable renderer;
@property (nonatomic, readonly) BeatStylesheet* styles;
@property (nonatomic, readonly) BeatExportSettings *settings;
@property (nonatomic, readonly) BeatFontSet *fonts;
@property (nonatomic, readonly) NSMutableArray<BeatPaginationPage*>* pages;
@property (nonatomic) NSArray<NSDictionary<NSString*, NSArray<Line*>*>*>* __nullable titlePageContent;
@property (nonatomic, readonly) NSArray<Line*>* __nullable lines;
@property (nonatomic, readonly) CGFloat maxPageHeight;

- (NSParagraphStyle*)paragraphStyleFor:(Line*)line;
- (BeatParagraphPaginationMode)paragraphPaginationMode;

- (Line*)moreLineFor:(Line*)line;
- (Line*)contdLineFor:(Line*)line;
- (NSMapTable<NSUUID*, Line*>*)uuids;
@end

@interface BeatPagination : NSObject <BeatPaginationExports>
/// A class which conforms to `BeatRenderDelegate` protocol and renders paginated blocks as `NSAttributedString` objects. 
@property (weak, nonatomic) BeatRenderer* renderer;
/// Title page content for finished pagination
@property (nonatomic) NSArray<NSDictionary<NSString*, NSArray<Line*>*>*>* __nullable titlePageContent;
/// If the pagination finished successfully
@property (nonatomic) bool success;
/// When `true`, the pagination will be canceled as soon as possible
@property (nonatomic) bool canceled;
/// If the pagination is running
@property (nonatomic) bool running;
/// When the operation was invoked
@property (nonatomic) NSDate* startTime;

/// Returns the preferred way to paginate paragraphs. Can be overridden by styles, and this getter will respect that.
@property (nonatomic) BeatParagraphPaginationMode paragraphPaginationMode;

/// Export settings
@property (nonatomic) BeatExportSettings* settings;

/// Contains every page object after a finished operation
@property (nonatomic) NSMutableArray<BeatPaginationPage*>* pages;
/// Maximum page __content__ height in points (excluding margins etc.)
@property (nonatomic, readonly) CGFloat maxPageHeight;

+ (BeatPagination*)newPaginationWithLines:(NSArray<Line*>*)lines delegate:(__weak id<BeatPaginationDelegate>)delegate;
+ (BeatPagination*)newPaginationWithScreenplay:(BeatScreenplay*)screenplay delegate:(__weak id<BeatPaginationDelegate>)delegate cachedPages:(NSArray<BeatPaginationPage*>* _Nullable)cachedPages livePagination:(bool)livePagination changedRange:(NSRange)changedRange;

+ (CGFloat)lineHeight;

/// Returns a dictionary of page breaks converted to editor page breaks. Compatible with `BeatLayoutManager`. Key is a non-retained `Line` object wrapped in `NSValue`, and the value is an two-object array with `pageNumber` and `localIndex`. This should desperately be an object of its own for better readability.
/// @return `{ pageBreakObject (Line, non-retained): [pageNumber, localIndex] }
- (NSDictionary<NSValue*,NSArray<NSNumber*>*>*)editorPageBreaks;

- (void)paginate;
- (NSInteger)findPageIndexForLine:(Line*)line;
- (NSInteger)findPageIndexAt:(NSInteger)position;
- (CGFloat)heightForScene:(OutlineScene*)scene;
- (CGFloat)heightForRange:(NSRange)range;

- (NSInteger)pageIndexForScene:(OutlineScene*)scene;
- (NSInteger)pageNumberForScene:(OutlineScene*)scene;
- (NSInteger)pageNumberAt:(NSInteger)location;

- (NSMapTable<NSUUID*, Line*>*)uuids;

- (NSArray<NSDictionary<NSString*, NSArray<Line*>*>*>*)titlePage;
@end

NS_ASSUME_NONNULL_END
