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

@interface WebPrinter : NSObject <WebFrameLoadDelegate>
@property (nonatomic, weak) NSWindow *window;
@property (strong) NSPrintInfo *printSettings;
@property (strong) NSString *testi;
@property (nonatomic, weak) NSPrintOperation *printOperation;
- (void)printHtml:(NSString *)html printInfo:(NSPrintInfo*)printSettings;
@end

NS_ASSUME_NONNULL_END
