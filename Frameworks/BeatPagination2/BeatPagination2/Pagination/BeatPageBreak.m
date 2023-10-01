//
//  BeatPageBreak.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 18.12.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatPageBreak.h"
#import <BeatParsing/BeatParsing.h>

@implementation BeatPageBreak

-(instancetype)initWithY:(CGFloat)y element:(Line*)line lineHeight:(CGFloat)lineHeight
{
	return [BeatPageBreak.alloc initWithY:y element:line lineHeight:lineHeight reason:@""];
}

-(instancetype)initWithY:(CGFloat)y element:(Line*)line lineHeight:(CGFloat)lineHeight reason:(NSString*)reason
{
	self = [super init];
	if (self) {
		self.y = y;
		self.element = line;
		self.reason = reason;
        self.lineHeight = lineHeight;
	}
	
	return self;
}

@end
