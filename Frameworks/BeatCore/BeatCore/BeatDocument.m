//
//  BeatDocument.m
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 20.2.2023.
//
/**
 
 This class is a draft to create a cross-platform document class. 
 
 */

#import "BeatDocument.h"

@implementation BeatDocument

- (instancetype)initWithURL:(NSURL*)url {
    NSError* error;
    NSString* string = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:&error];
    
    if (error) {
        NSLog(@"ERROR: Failed to open URL");
        return nil;
    }
    
    return [BeatDocument.alloc initWithString:string];
}

- (instancetype)initWithString:(NSString*)string
{
    self = [super init];
    if (self) {
        
        self.settings = BeatDocumentSettings.new;
        NSRange settingRange = [self.settings readSettingsAndReturnRange:string];
        
        string = [string stringByRemovingRange:settingRange];
        self.parser = [ContinuousFountainParser.alloc initWithString:string];
    }
    return self;
}

@end
