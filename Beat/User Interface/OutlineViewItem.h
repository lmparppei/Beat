//
//  OutlineItem.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 20.11.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>
@class OutlineScene;

NS_ASSUME_NONNULL_BEGIN

@interface OutlineViewItem : NSObject

+(NSMutableAttributedString*)withScene:(OutlineScene*)scene currentScene:(OutlineScene*_Nullable)currentScene withSynopsis:(bool)includeSynopsis isDark:(bool)dark;

@end

NS_ASSUME_NONNULL_END
