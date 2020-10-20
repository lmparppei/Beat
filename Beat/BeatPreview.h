//
//  BeatPreview.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 17.5.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "OutlineScene.h"

typedef enum : NSUInteger {
	BeatPrintPreview = 0,
	BeatQuickLookPreview,
	BeatComparisonPreview
} BeatPreviewType;

@interface BeatPreview : NSObject
+ (NSString*) createNewPreview:(NSString*)rawText of:(NSDocument*)document scene:(NSString*)scene sceneNumbers:(bool)sceneNumbers type:(BeatPreviewType)previewType;
+ (NSString*) createQuickLook:(NSString*)rawText;
@end
