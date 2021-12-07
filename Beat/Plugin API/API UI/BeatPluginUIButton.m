//
//  BeatPluginUIButton.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 7.12.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatPluginUIButton.h"

@interface BeatPluginUIButton ()
@property (nonatomic) JSValue *jsMethod;
@end

@implementation BeatPluginUIButton

+(instancetype)buttonWithTitle:(NSString *)title action:(JSValue*)action frame:(NSRect)frame {
	BeatPluginUIButton *button = [BeatPluginUIButton buttonWithTitle:title target:nil action:nil];

	button.target = button;
	button.action = @selector(runMethod);
	button.jsMethod = action;
	button.controlSize = NSControlSizeSmall;
	
	button.frame = frame;
	
	return button;
}

- (void)runMethod {
	[self.jsMethod callWithArguments:nil];
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    // Drawing code here.
}

-(BOOL)isFlipped {
	return YES;
}

@end
