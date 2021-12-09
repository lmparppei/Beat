//
//  BeatPluginUIExports.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 7.12.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <JavaScriptCore/JavaScriptCore.h>

@protocol BeatPluginUIExports <JSExport>

@property (nonatomic) NSRect frame;
- (void)remove;
- (void)setFrame:(NSRect)frame;

@end
