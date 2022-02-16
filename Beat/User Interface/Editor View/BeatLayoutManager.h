//
//  BeatLayoutManager.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 11.2.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "BeatTextView.h"

NS_ASSUME_NONNULL_BEGIN

@interface BeatLayoutManager : NSLayoutManager
@property (nonatomic) BeatTextView * textView;
@end

NS_ASSUME_NONNULL_END
