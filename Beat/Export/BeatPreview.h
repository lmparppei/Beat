//
//  BeatPreview.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 17.5.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "OutlineScene.h"
#import "BeatDocumentSettings.h"

typedef enum : NSUInteger {
	BeatPrintPreview = 0,
	BeatQuickLookPreview,
	BeatComparisonPreview
} BeatPreviewType;

@protocol BeatPreviewDelegate
@property (nonatomic) BeatDocumentSettings *documentSettings;
@property (nonatomic) bool printSceneNumbers;
@property (nonatomic) OutlineScene *currentScene;
- (NSString*) getText;

@end

@interface BeatPreview : NSObject
@property (nonatomic, weak) id delegate;
- (id) initWithDocument:(id)document;
- (NSString*) createPreview;
- (NSString*) createPreviewFor:(NSString*)rawScript type:(BeatPreviewType)previewType;
+ (NSString*) createNewPreview:(NSString*)rawText of:(NSDocument*)document scene:(NSString*)scene sceneNumbers:(bool)sceneNumbers type:(BeatPreviewType)previewType;
+ (NSString*) createQuickLook:(NSString*)rawText;
@end
