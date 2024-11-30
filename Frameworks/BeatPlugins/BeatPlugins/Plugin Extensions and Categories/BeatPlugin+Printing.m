//
//  BeatPlugin+Printing.m
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 27.11.2024.
//

#import "BeatPlugin+Printing.h"

@implementation BeatPlugin (Printing)

#pragma mark - Printing interface

#if !TARGET_OS_IOS
- (NSDictionary*)printInfo
{
    NSPrintInfo* printInfo = NSPrintInfo.sharedPrintInfo;
    return @{
        @"paperSize": @(printInfo.paperSize),
        @"imageableSize": @{
            @"width": @(printInfo.imageablePageBounds.size.width),
            @"height": @(printInfo.imageablePageBounds.size.height)
        }
    };
}
- (void)printHTML:(NSString*)html settings:(NSDictionary*)settings callback:(JSValue*)callback
{
    NSPrintInfo *printInfo = NSPrintInfo.sharedPrintInfo.copy;
    
    dispatch_async(dispatch_get_main_queue(), ^(void){
        self.printer = BeatHTMLPrinter.new;
        
        if (settings[@"orientation"]) {
            NSString *orientation = [(NSString*)settings[@"orientation"] lowercaseString];
            if ([orientation isEqualToString:@"landscape"]) printInfo.orientation = NSPaperOrientationLandscape;
            else printInfo.orientation = NSPaperOrientationPortrait;
        } else printInfo.orientation = NSPaperOrientationPortrait;
        
        if (settings[@"paperSize"]) {
            NSString *paperSize = [(NSString*)settings[@"paperSize"] lowercaseString];
            if ([paperSize isEqualToString:@"us letter"]) [BeatPaperSizing setPageSize:BeatUSLetter printInfo:printInfo];
            else if ([paperSize isEqualToString:@"a4"]) [BeatPaperSizing setPageSize:BeatA4 printInfo:printInfo];
        }
        
        if (settings[@"margins"]) {
            NSArray* margins = settings[@"margins"];
            
            for (NSInteger i=0; i<margins.count; i++) {
                NSNumber* n = margins[i];
                if (i == 0) printInfo.topMargin = n.floatValue;
                else if (i == 1) printInfo.rightMargin = n.floatValue;
                else if (i == 2) printInfo.bottomMargin = n.floatValue;
                else if (i == 3) printInfo.leftMargin = n.floatValue;
            }
        }
        
        [self.printer printHtml:html printInfo:printInfo callback:^{
            if (callback) [callback callWithArguments:nil];
        }];
    });
}
#endif

@end
