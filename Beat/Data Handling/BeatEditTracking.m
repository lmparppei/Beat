//
//  BeatEditTracking.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 9.3.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatEditTracking.h"

@implementation BeatEditTracking

-(instancetype)initWithString:(NSString*)text delegate:(id<BeatEditTrackingDelegate>)delegate {
	self = [super init];
	
	if (self) {
		/*
		NSMutableArray *lines = [NSMutableArray array];
		
		for (Line* line in array) {
			Line *copy = [line copy];
			[lines addObject:copy];
		}
		
		_origin = [NSArray arrayWithArray:lines];
		 */
		_delegate = delegate;
		_comparison = [[BeatComparison alloc] init];
		_text = [NSString stringWithString:text];
	}
	
	return self;
}

- (void)edit {
	[_comparison compare:_delegate.parser.lines with:self.delegate.getText];
	
	for (Line* line in _delegate.parser.lines) {
		if (line.changed) NSLog(@"changed");
	}
}

@end
