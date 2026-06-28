//
//  BeatPluginUICheckbox.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 7.12.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatPluginUICheckbox.h"
#import <BeatCore/BeatCompatibility.h>

@interface BeatPluginUICheckbox ()
@property (nonatomic) JSValue *jsAction;
@end

@implementation BeatPluginUICheckbox

+ (BeatPluginUICheckbox*)withTitle:(NSString*)title action:(JSValue*)action frame:(NSRect)frame {
	return [[BeatPluginUICheckbox alloc] initWithTitle:title action:action frame:frame];
}
- (instancetype)initWithTitle:(NSString*)title action:(JSValue*)action frame:(NSRect)frame {
	self = [super init];
	
	if (self) {
		//[self setButtonType:NSSwitchButton];
        [self setButtonType:NSButtonTypeSwitch];
		
		if (!NSIsEmptyRect(frame)) self.frame = frame;
		
		self.title = title;
		self.jsAction = action;
		self.target = self;
		self.action = @selector(runAction);
	}
	
	return self;
}

- (bool)checked {
    return (self.state == BXOnState);
}

- (void)setChecked:(bool)checked {
    self.state = BXState(checked);
}

- (void)runAction {
	bool checked = [self checked];
	[self.jsAction callWithArguments:@[ @(checked), self.title ]];
}

- (void)remove {
	[self removeFromSuperview];
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    // Drawing code here.
}

@end
