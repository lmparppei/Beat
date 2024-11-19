//
//  TrelbyImport.m
//  BeatFileExport
//
//  Created by Lauri-Matti Parppei on 3.9.2024.
//

#import "TrelbyImport.h"

@implementation TrelbyImport

- (id)initWithURL:(NSURL *)url options:(NSDictionary *)options completion:(void (^)(id _Nullable))callback
{
    self = [super init];
    if (self) {
        self.callback = callback;
        [self readFromURL:url];
    }

    return self;
}

- (void)readFromURL:(NSURL*)url
{
    NSString* lines = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:nil];
    
    NSMutableString* script = NSMutableString.new;
    bool contentFound = false;
        
    for (NSString* l in [lines componentsSeparatedByString:@"\n"]) {
        if ([[l stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet] isEqualToString:@"#Start-Script"]) {
            contentFound = true;
            continue;
        }
        if (!contentFound || l.length == 0) continue;
        
        unichar control = [l characterAtIndex:0];
        unichar type = [l characterAtIndex:1];
        
        NSMutableString* content = [l substringFromIndex:2].mutableCopy;
         
        // Broken paragraphs
        if (control == '>') {
            [content appendString:@" "];
        }
        
        // Control line breaks
        if (control == '.' && (type == '.' || type == ':')) {
            [content appendString:@"\n\n"];
        }
        else if (control == '.' && type == '_') {
            [content setString:content.uppercaseString];
            [content appendString:@"\n"];
        }
        else if (control == '.' && type == '\\') {
            [content setString:content.uppercaseString];
            [content appendString:@"\n\n"];
        }
        else if (control == '.' && type == '(') {
            // This is a hack, let's remove the earlier double-line break if required
            if (script.length > 2 && [[script substringWithRange:NSMakeRange(script.length-2, 2)] isEqualToString:@"\n\n"]) {
                [script setString:[script substringToIndex:script.length-1]];
            }
            [content appendString:@"\n"];
        }
        
        [script appendString:content];
    }
    
    _script = script;
    self.callback(self);
}

- (NSString *)fountain { return self.script; }

@end
