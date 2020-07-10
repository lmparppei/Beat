//
//  BeatPreview.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 17.5.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "OutlineScene.h"
#import "FNScript.h"

NS_ASSUME_NONNULL_BEGIN

@interface BeatPreview : NSObject
+ (NSString*) createNewPreview:(NSString*)rawText of:(NSDocument*)document scene:(NSString*)scene;
+ (FNScript*) createPreview:(NSString*)rawText;
@end

NS_ASSUME_NONNULL_END
