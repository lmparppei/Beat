//
//  Theme.h
//  Writer / Beat
//
//  Parts Copyright © 2019 Lauri-Matti Parppei. All rights reserved.
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
@property (strong, nonatomic) NSColor* marginColor;

@property (strong, nonatomic) NSString* name;

@end
