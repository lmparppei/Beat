//
//  BeatExportSettings.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 22.6.2021.
//  Copyright © 2021 KAPITAN!. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
	ForPrint = 0,
	ForPreview,
	ForQuickLook
} BeatHTMLOperation;

@interface BeatExportSettings : NSObject
@property (nonatomic) NSString *header;
@property (nonatomic) BeatHTMLOperation operation;
@property (nonatomic)  NSString * _Nullable revisionColor;
@property (nonatomic) bool coloredPages;
@property (nonatomic) bool printSceneNumbers;
@property (nonatomic, weak) NSDocument *document;
@property (nonatomic) NSString * _Nullable currentScene;
@property (nonatomic) NSString * _Nullable oldScript;

+ (BeatExportSettings*)operation:(BeatHTMLOperation)operation document:(NSDocument*)doc header:(NSString*)header  printSceneNumbers:(bool)printSceneNumbers;
+ (BeatExportSettings*)operation:(BeatHTMLOperation)operation document:(NSDocument*)doc header:(NSString*)header printSceneNumbers:(bool)printSceneNumbers revisionColor:(NSString*)revisionColor coloredPages:(bool)coloredPages;
+ (BeatExportSettings*)operation:(BeatHTMLOperation)operation document:(NSDocument*)doc header:(NSString*)header printSceneNumbers:(bool)printSceneNumbers revisionColor:(NSString*)revisionColor coloredPages:(bool)coloredPages scene:(NSString*)scene;
+ (BeatExportSettings*)operation:(BeatHTMLOperation)operation document:(NSDocument*)doc header:(NSString*)header printSceneNumbers:(bool)printSceneNumbers revisionColor:(NSString*)revisionColor coloredPages:(bool)coloredPages compareWith:(NSString*)oldScript;

@end

NS_ASSUME_NONNULL_END
