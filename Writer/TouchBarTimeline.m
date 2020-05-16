//
//  TouchBarTimeline.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 15.5.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//

#import "TouchBarTimeline.h"

@implementation TouchBarTimeline

- (void)awakeFromNib {
	self.dataSource = self;
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    // Drawing code here.
}

- (NSInteger)numberOfItemsForScrubber:(NSScrubber *)scrubber {
	return [_scenes count];
}

- (__kindof NSScrubberItemView *)scrubber:(NSScrubber *)scrubber viewForItemAtIndex:(NSInteger)index {
	NSRect rect = NSMakeRect(0, 0, 150, self.frame.size.height);
	NSScrubberItemView *view = [[NSScrubberItemView alloc] initWithFrame:rect];
	NSScrubberTextItemView *textView = [[NSScrubberTextItemView alloc] initWithFrame:rect];
	NSString *title = [[_scenes objectAtIndex:index] valueForKey:@"text"];
	
	[textView setTitle:title];
	[view addSubview:textView];

	return view;
}


- (void)reload:(NSString *)json {
	NSError *error = nil;
	
	id data = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error];
	
	if ([data isKindOfClass:[NSArray class]]) {
		_scenes = data;
		[self reloadData];
	}
}

@end
