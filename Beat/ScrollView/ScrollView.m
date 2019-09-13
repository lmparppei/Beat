//
//  ScrollView.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 13/09/2019.
//  Copyright © 2019 KAPITAN!. All rights reserved.
//

#import "ScrollView.h"

@implementation ScrollView

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];

	
	
    // Drawing code here.
}

- (void)setFindBarVisible:(BOOL)findBarVisible {
	[super setFindBarVisible:findBarVisible];
	
	CGFloat height = [self findBarView].frame.size.height;
	
	if (!findBarVisible) {
		_outlineButtonY.constant -= height;
	} else {
		_outlineButtonY.constant += height;
	}	
}

- (void) findBarViewDidChangeHeight {
	
}


@end
