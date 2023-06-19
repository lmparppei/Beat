//
//  BeatPageDelegate.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 3.10.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>
@class Line;

@protocol BeatPageDelegate
@property (atomic) bool livePagination;
- (CGFloat)heightForBlock:(NSArray*)block;
- (CGFloat)spaceBeforeForLine:(Line*)line;
@end
