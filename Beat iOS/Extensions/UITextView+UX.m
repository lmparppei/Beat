//
//  UITextView+UX.m
//  Beat iOS
//
//  Created by Lauri-Matti Parppei on 26.4.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//
//  Provides basic interop between text views

#import "UITextView+UX.h"

@implementation UITextView (UX)

-(NSString *)string {
	return self.text;
}
-(void)setString:(NSString *)string {
	self.text = string;
}

@end
