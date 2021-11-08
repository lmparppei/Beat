//
//  BeatPieGraph.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 25.10.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface BeatPieGraph : NSView
- (void)pieChartForData:(NSArray*)items;
@end

NS_ASSUME_NONNULL_END
