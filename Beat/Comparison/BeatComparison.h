//
//  BeatComparison.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 15.10.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PrintView.h"

@class Document;

@interface BeatComparison : NSObject <PrintViewDelegate>
@property (weak) NSWindow *window;
@property (weak) NSArray *currentScript;
@property (weak) Document *document;

- (void)compare:(NSArray*)script with:(NSString*)olderFilePath;
- (IBAction)open:(id)sender;
@end
