//
//  BeatPluginUITextField.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 4.4.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <BeatPlugins/BeatPluginUIExports.h>

@protocol BeatPluginUITextFieldExports <JSExport>
@property (nonatomic) JSValue* jsAction;
@property (nonatomic) NSString* stringValue;
@property (nonatomic) bool editable;
- (NSString*)value;
@end

@interface BeatPluginUITextField : NSTextField <BeatPluginUIExports, BeatPluginUITextFieldExports, NSTextFieldDelegate>
@property (nonatomic) JSValue* jsAction;
+ (BeatPluginUITextField*)withText:(NSString*)title frame:(NSRect)frame onChange:(JSValue*)action color:(NSString*)colorName size:(CGFloat)fontSize font:(NSString*)fontName;

@end
