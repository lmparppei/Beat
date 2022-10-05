//
//  BeatPageDelegate.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 3.10.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol BeatPageDelegate
@property (atomic) bool livePagination;
- (NSInteger)heightForBlock:(NSArray*)block;
@end
