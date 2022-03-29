//
//  BeatClipView.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 9.10.2021.
//  Copyright © 2021-2022 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatClipView.h"

@implementation BeatClipView

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
}

-(void)layout {
	// We are not laying out the clip view, because it can cause an endless layout loop on some systems.
	// No idea about the possible reprecussions, but this is the way now. Uncomment if needed, but you'll
	// probably kill support for many computers. Greetings from March 2022.
	
	// [super layout];
}

@end
