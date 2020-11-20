//
//  OutlineItem.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 20.11.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OutlineScene.h"

NS_ASSUME_NONNULL_BEGIN

@interface OutlineViewItem : NSObject

+(NSMutableAttributedString*)withScene:(OutlineScene*)scene currentScene:(OutlineScene*)currentScene;

@end

NS_ASSUME_NONNULL_END
