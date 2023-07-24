//
//  WebPrinter.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 8.5.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface BeatHTMLPrinter : NSView <WebFrameLoadDelegate>
//@property (nonatomic, weak) NSPrintOperation *printOperation;
@property (nonatomic) NSString *name;
- (instancetype)initWithName:(NSString*)name;
- (void)printHtml:(NSString *)html printInfo:(NSPrintInfo*)printSettings;
- (void)printHtml:(NSString *)html printInfo:(NSPrintInfo*)printSettings callback:(void (^ _Nullable)(void))callbackBlock;
@end

NS_ASSUME_NONNULL_END
