//
//  BeatPrint.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 15.10.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class Document;
@interface BeatPrint : NSObject
+ (NSString*) createPrint:(NSString*)rawText document:(Document*)document compareWith:(NSString* _Nullable)oldScript;
@end

NS_ASSUME_NONNULL_END
