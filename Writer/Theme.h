//
//  Theme.h
//  Writer
//
//  Created by Hendrik Noeller on 04.04.16.
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface Theme : NSObject

@property (strong, nonatomic) NSColor* backgroundColor;
@property (strong, nonatomic) NSColor* selectionColor;
@property (strong, nonatomic) NSColor* textColor;
@property (strong, nonatomic) NSColor* invisibleTextColor;
@property (strong, nonatomic) NSColor* caretColor;
@property (strong, nonatomic) NSColor* commentColor;

@property (strong, nonatomic) NSString* name;

@end
