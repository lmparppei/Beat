//
//  BeatDocument.m
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 20.2.2023.
//

#import "BeatDocument.h"

@implementation BeatDocument

- (instancetype)initWithString:(NSString*)string
{
    self = [super init];
    if (self) {
        
        self.settings = BeatDocumentSettings.new;
        NSRange settingRange = [self.settings readSettingsAndReturnRange:string];
        
        string = [string stringByRemovingRange:settingRange];

    }
    return self;
}

@end
