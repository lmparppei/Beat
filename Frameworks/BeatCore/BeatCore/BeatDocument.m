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
#import <BeatCore/BeatCore.h>

@interface BeatDocument ()
@end

@implementation BeatDocument

- (instancetype)initWithURL:(NSURL*)url {
    NSError* error;
    NSString* string = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:&error];
    
    self.url = url;
    
    if (error) {
        NSLog(@"ERROR: Failed to open URL");
        return nil;
    }
        
    return [BeatDocument.alloc initWithString:string url:url];
}

- (instancetype)initWithString:(NSString*)string url:(NSURL* _Nullable)url
{
    self = [super init];
    if (self) {
        self.url = url;
        
        self.settings = BeatDocumentSettings.new;
        NSRange settingRange = [self.settings readSettingsAndReturnRange:string];
        
        string = [string stringByRemovingRange:settingRange];
        self.parser = [ContinuousFountainParser.alloc initWithString:string];
        
        [BeatRevisions bakeRevisionsIntoLines:self.parser.lines revisions:[self.settings get:DocSettingRevisions] string:self.parser.rawText];
    }
    return self;
}


@end
