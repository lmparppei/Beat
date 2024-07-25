//
//  OutlineItem.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 20.11.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>
@class OutlineScene;

typedef NS_OPTIONS(NSUInteger, OutlineItemOptions) {
    OutlineItemIncludeHeading       = 1 << 0,
    OutlineItemIncludeSceneNumber   = 1 << 1,
    OutlineItemIncludeSynopsis      = 1 << 2,
    OutlineItemIncludeNotes         = 1 << 3,
    OutlineItemIncludeMarkers       = 1 << 4,
    OutlineItemDarkMode             = 1 << 5
};

NS_ASSUME_NONNULL_BEGIN

@interface OutlineViewItem : NSObject

/// Returns an outline item. Here for compatibility reasons.
+ (NSAttributedString*)withScene:(OutlineScene *)scene currentScene:(OutlineScene *)current sceneNumber:(bool)includeSceneNumber synopsis:(bool)includeSynopsis notes:(bool)includeNotes markers:(bool)includeMarkers isDark:(bool)dark;

+ (NSAttributedString*)withScene:(OutlineScene *)scene currentScene:(OutlineScene *)current options:(OutlineItemOptions)options;

@end

NS_ASSUME_NONNULL_END
