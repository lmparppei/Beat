//
//  BeatComparison.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 15.10.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PrintView.h"
#import "Line.h"

@class Document;

@interface BeatComparison : NSObject
- (void)compare:(NSArray*)script with:(NSString*)olderFilePath;
- (NSDictionary*)changeListFrom:(NSString*)oldScript to:(NSString*)newScript;
@end
