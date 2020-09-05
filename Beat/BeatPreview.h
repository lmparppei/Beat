//
//  BeatPreview.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 17.5.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "OutlineScene.h"

NS_ASSUME_NONNULL_BEGIN

@interface BeatPreview : NSObject
+ (NSString*) createPrint:(NSString*)rawText document:(NSDocument*)document;
+ (NSString*) createNewPreview:(NSString*)rawText of:(NSDocument* _Nullable)document scene:(NSString* _Nullable)scene;
+ (NSString*) createQuickLook:(NSString*)rawText;
@end

NS_ASSUME_NONNULL_END
