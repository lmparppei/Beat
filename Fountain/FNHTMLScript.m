//
//  FNHTMLScript.m
//	Modified for Beat
//
//  Copyright (c) 2012-2013 Nima Yousefi & John August
//  Parts copyright © 2019 Lauri-Matti Parppei / KAPITAN!
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy 
//  of this software and associated documentation files (the "Software"), to 
//  deal in the Software without restriction, including without limitation the 
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or 
//  sell copies of the Software, and to permit persons to whom the Software is 
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in 
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING 
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS 
//  IN THE SOFTWARE.
//

/*
 
 N.B. This version of FNHTMLScript.m is customized for Beat. It still outputs HTML
 for printing out screenplays.
 
 There are certain differences:
 
 - the English language default "written by" has been removed:
 [body appendFormat:@"<p class='%@'>%@</p>", @"credit", @""];
 
 - HTML output links to either screen or print CSS depending on the target format.
 Print & PDF versions rely on PrintCSS.css and preview mode uses a modified ScriptCSS.css.
 
 - And - as I'm writing this, some functions in RegexKitLite.h have been deprecated
 in macOS 10.12+. Fair enough - it was apparently last updated in 2010.
 
 I hadn't  made any films then. In 2010, I was young, madly in love and had dreams
 and aspirations. I had just recently started my studies in a film school.
 In 9 years, I figured back then, I'd be making films that really communicated
 the pain I had gone through. My films would reach out to other lonely people,
 confined in their gloomy tomb, assured of their doom.
 
 Well.
 
 Instead, I'm reading about fucking C enumerators and OS spin locks to be able
 to build my own fucking software, which - mind you - ran just fine a few weeks ago.
 
 Hence, I tried to replace the deprecated spin locks of RegexKitLite.h with modern ones.
 It was about to destroy my inner child. I just wanted to write nice films, I wasn't
 planning on fucking learning any motherfucking C!!!
 
 SO, if you are reading this: Beat now relies on a customized RegexKitLite,
 which might work or not. It could crash systems all around the world. It could
 consume your computer's soul and kill any glimpse of hope.
 
 I could have spent these hours with my dear friends, my lover or just watching
 flowers grow and maybe talking to them. Or even writing my film.
 I didn't. Here I am, typing this message to some random fucker who, for
 whatever reason, decides to take a look at my horrible code sometime in the
 future.
 
 Probably it's me, though.
 
 What can I say. STOP WASTING YOUR LIFE AND GO FUCK YOURSELF.

 
*/

#import "FNHTMLScript.h"
#import "FNScript.h"
#import "FNElement.h"
#import "FountainRegexes.h"
#import "FNPaginator.h"
// #import "NSMutableString+Regex.h"

// FUCK YOU REGEXKITLITE.H
 #import "RegexKitLite.h"

@interface FNHTMLScript ()

@property (readonly, copy, nonatomic) NSString *cssText;
@property (copy, nonatomic) NSString *bodyText;
@property (nonatomic) NSInteger numberOfPages;

@end

@implementation FNHTMLScript

- (id)initWithScript:(FNScript *)aScript
{
    self = [super init];
    if (self) {
        _script = aScript;
        _font = [QUQFont fontWithName:@"Courier" size:12];
    }
    return self;
}

- (id)initWithScript:(FNScript *)aScript print:(bool)print {
	self = [super init];
	if (self) {
		_script = aScript;
		_font = [QUQFont fontWithName:@"Courier" size:12];
		_print = print;
	}
	return self;
}

- (id)initWithScript:(FNScript *)aScript document:(NSDocument*)aDocument
{
    self = [super init];
    if (self) {
        _script = aScript;
        _font = [QUQFont fontWithName:@"Courier" size:12];
        _document = aDocument;
    }
    return self;
}

- (id)initWithScript:(FNScript *)aScript document:(NSDocument*)aDocument print:(bool)print
{
	self = [super init];
	if (self) {
		_script = aScript;
		_font = [QUQFont fontWithName:@"Courier" size:12];
		_document = aDocument;
		_print = print;
	}
	return self;
}

- (NSInteger)pages {
	return _numberOfPages + 1;
}

- (NSString *)html
{
    if (!self.bodyText) {
        self.bodyText = [self bodyForScript];
    }
    
    NSMutableString *html = [NSMutableString string];
    [html appendString:@"<!DOCTYPE html>\n"];
    [html appendString:@"<html>\n"];
    [html appendString:@"<head>\n"];
	//[html appendString:@"<meta name='viewport' content='width=device-width, initial-scale=1.1'/>\n"];
	
    [html appendString:@"<style type='text/css'>\n"];
    [html appendString:self.cssText];
    [html appendString:@"</style>\n"];
    [html appendString:@"</head>\n"];
    [html appendString:@"<body>\n<article>\n"];
    [html appendString:self.bodyText];
    [html appendString:@"</section>\n</article>\n</body>\n"];
    [html appendString:@"</html>"];        
    return html;
}

- (NSString *)htmlClassForType:(NSString *)elementType
{
    return [[elementType lowercaseString] stringByReplacingOccurrencesOfString:@" " withString:@"-"];
}

- (NSString *)cssText
{    
    NSError *error = nil;
	NSString *css;
	
	if (!_print) {
		NSString *path = [[NSBundle mainBundle] pathForResource:@"ScriptCSS.css" ofType:@""];
		css = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
	} else {
		NSString *path = [[NSBundle mainBundle] pathForResource:@"PrintCSS.css" ofType:@""];
		css = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
	}

	if (error) {
		NSLog(@"Couldn't load CSS");
		css = @"";
	}

    return css;
}

- (NSString *)bodyForScript
{
    NSMutableString *body = [NSMutableString string];
    
    // Add title page
    NSMutableDictionary *titlePage = [NSMutableDictionary dictionary];
    for (NSDictionary *dict in self.script.titlePage) {
        [titlePage addEntriesFromDictionary:dict];
    }
    
    if ([titlePage count] > 0) {
        [body appendString:@"<section id='script-title' class='page'>"];
		
		[body appendFormat:@"<div class='mainTitle'>"];
        
        // Title
        if (titlePage[@"title"]) {
            NSArray *obj = titlePage[@"title"];
            NSMutableString *values = [NSMutableString string];
            for (NSString *val in obj) {
                [values appendFormat:@"%@<br>", val];
            }
            [body appendFormat:@"<p class='%@'>%@</p>", @"title", values];
        }
        else {
            [body appendFormat:@"<p class='%@'>%@</p>", @"title", @"Untitled"];
        }
        
        // Credit
        if (titlePage[@"credit"] || titlePage[@"authors"]) {
            if (titlePage[@"credit"]) {
                NSArray *obj = titlePage[@"credit"];
                NSMutableString *values = [NSMutableString string];
                for (NSString *val in obj) {
                    [values appendFormat:@"%@<br>", val];
                }
                [body appendFormat:@"<p class='%@'>%@</p>", @"credit", values];
            }
            else {
                [body appendFormat:@"<p class='%@'>%@</p>", @"credit", @""];
            }
            
            // Authors
            if (titlePage[@"authors"]) {
                NSArray *obj = titlePage[@"authors"];
                NSMutableString *values = [NSMutableString string];
                for (NSString *val in obj) {
                    [values appendFormat:@"%@<br>", val];
                }
                [body appendFormat:@"<p class='%@'>%@</p>", @"authors", values];
            }
            else {
                [body appendFormat:@"<p class='%@'>%@</p>", @"authors", @"Anonymous"];
            }
        }
		[body appendFormat:@"</div>"];
		[body appendFormat:@"<div class='info'>"];
        // Source
        if (titlePage[@"source"]) {
            NSArray *obj = titlePage[@"source"];
            NSMutableString *values = [NSMutableString string];
            for (NSString *val in obj) {
                [values appendFormat:@"%@<br>", val];
            }
            [body appendFormat:@"<p class='%@'>%@</p>", @"source", values];
        }
        
        
        // Draft date
        if (titlePage[@"draft date"]) {
            NSArray *obj = titlePage[@"draft date"];
            NSMutableString *values = [NSMutableString string];
            for (NSString *val in obj) {
                [values appendFormat:@"%@<br>", val];
            }
            [body appendFormat:@"<p class='%@'>%@</p>", @"draft-date", values];
        }
        
        // Contact
        if (titlePage[@"contact"]) {
            NSArray *obj = titlePage[@"contact"];
            NSMutableString *values = [NSMutableString string];
            for (NSString *val in obj) {
                [values appendFormat:@"%@<br>", val];
            }
            [body appendFormat:@"<p class='%@'>%@</p>", @"contact", values];
        }
		[body appendFormat:@"</div>"];
		
        [body appendString:@"</section>"];
    }
    
    NSInteger dualDialogueCharacterCount = 0;
    NSSet *dialogueTypes = [NSSet setWithObjects:@"Character", @"Dialogue", @"Parenthetical", nil];
    NSSet *ignoringTypes = [NSSet setWithObjects:@"Boneyard", @"Comment", @"Synopsis", @"Section Heading", nil];
    
    FNPaginator *paginator = [[FNPaginator alloc] initWithScript:self.script document:self.document];
    NSUInteger maxPages = [paginator numberOfPages];
	_numberOfPages = maxPages;
	
	bool pageBreak = false;
	
    for (NSInteger pageIndex = 0; pageIndex < maxPages; pageIndex++) {
        NSArray *elementsOnPage = [paginator pageAtIndex:pageIndex];
        
        // Print what page we're on -- used for page jumper
		[body appendFormat:@"<section>"];
		
		int index = (int)pageIndex+1;
		
        if (self.customPage) {
            if ([self.customPage integerValue] == 0) {
                if ([self.forRendering boolValue]) {
                    [body appendFormat:@"<p class='page-break-render'></p>\n"];
                } else {
                    [body appendFormat:@"<p class='page-break'></p>\n"];
                }
            } else {
                if ([self.forRendering boolValue]) {
					// I don't understand this part. For some reason certain elements are cut off the page and have a random page number there when rendering. So, as a rational and solution-oriented person, I just removed the page number altogether if this happens.
					if (index < 2) {
                    	[body appendFormat:@"<p class='page-break-render'>%d.</p>\n", [self.customPage intValue]];
					}
                } else {
                    [body appendFormat:@"<p class='page-break'>%d.</p>\n", [self.customPage intValue]];
                }
            }
        } else {
            if ([self.forRendering boolValue]) {
                [body appendFormat:@"<p class='page-break-render'>render %d.</p>\n", (int)pageIndex+1];
            } else {
                [body appendFormat:@"<p class='page-break'>%d.</p>\n", (int)pageIndex+1];
            }
        }
        
        for (FNElement *element in elementsOnPage) {
            if ([ignoringTypes containsObject:element.elementType]) {
                continue;
            }
			

            if ([element.elementType isEqualToString:@"Page Break"]) {
                //[body appendString:@"</section>\n<section>\n"];
				// [body appendString:@"</section>\n"];
				pageBreak = true;
                continue;
            }
			
            if ([element.elementType isEqualToString:@"Character"] && element.isDualDialogue) {
                dualDialogueCharacterCount++;
                if (dualDialogueCharacterCount == 1) {
                    [body appendString:@"<div class='dual-dialogue'>\n"];
                    [body appendString:@"<div class='dual-dialogue-left'>\n"];
                }
                else if (dualDialogueCharacterCount == 2) {
                    [body appendString:@"</div>\n<div class='dual-dialogue-right'>\n"];
				} else if (dualDialogueCharacterCount == 3) {
					[body appendString:@"</div></div>\n"];
					dualDialogueCharacterCount = 0;
				}
            }
            
            if (dualDialogueCharacterCount >= 2 && ![dialogueTypes containsObject:element.elementType]) {
                dualDialogueCharacterCount = 0;
                [body appendString:@"</div>\n</div>\n"];
            }
            
            NSMutableString *text = [NSMutableString string];            
            if ([element.elementType isEqualToString:@"Scene Heading"] && element.sceneNumber) {
                [text appendFormat:@"<span class='scene-number-left'>%@</span>", element.sceneNumber];
                [text appendString:element.elementText];
                [text appendFormat:@"<span class='scene-number-right'>%@</span>", element.sceneNumber];
            }
            else {
                [text appendString:element.elementText];
            }
            
            if ([element.elementType isEqualToString:@"Character"] && element.isDualDialogue) {
                // Remove any carets
                [text replaceOccurrencesOfString:@"^" withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, text.length)];
            }
            
            if ([element.elementType isEqualToString:@"Character"]) {
                [text replaceOccurrencesOfRegex:@"^@" withString:@""];
            }
            
            if ([element.elementType isEqualToString:@"Scene Heading"]) {
                [text replaceOccurrencesOfRegex:@"^\\." withString:@""];
            }
            
            if ([element.elementType isEqualToString:@"Lyrics"]) {
                [text replaceOccurrencesOfRegex:@"^~" withString:@""];
            }
            
            if ([element.elementType isEqualToString:@"Action"]) {
                [text replaceOccurrencesOfRegex:@"^\\!" withString:@""];
            }
            
            
            [text replaceOccurrencesOfRegex:BOLD_ITALIC_UNDERLINE_PATTERN withString:@"<strong><em><u>$2</strong></em></u>"];
            [text replaceOccurrencesOfRegex:BOLD_ITALIC_PATTERN withString:@"<strong><em>$2</strong></em>"];
            [text replaceOccurrencesOfRegex:BOLD_UNDERLINE_PATTERN withString:@"<strong><u>$2</u></strong>"];
            [text replaceOccurrencesOfRegex:ITALIC_UNDERLINE_PATTERN withString:@"<em><u>$2</em></u>"];
            [text replaceOccurrencesOfRegex:BOLD_PATTERN withString:@"<strong>$2</strong>"];
            [text replaceOccurrencesOfRegex:ITALIC_PATTERN withString:@"<em>$2</em>"];
            [text replaceOccurrencesOfRegex:UNDERLINE_PATTERN withString:@"<u>$2</u>"];
            
            [text replaceOccurrencesOfRegex:@"\\[{2}(.*?)\\]{2}" withString:@""];
            
            //Find newlines and replace them with <br/>
            text = [[text stringByReplacingOccurrencesOfString:@"\n" withString:@"<br>"] mutableCopy];
            
            if (![text isEqualToString:@""]) {
                NSMutableString *additionalClasses = [NSMutableString string];
                if (element.isCentered) {
                    [additionalClasses appendString:@" center"];
                }
                [body appendFormat:@"<p class='%@%@'>%@</p>\n", [self htmlClassForType:element.elementType], additionalClasses, text];
            }            
        }
		//if (!pageBreak) [body appendFormat:@"</section>"];
		[body appendFormat:@"</section>"];
    }

    return body;
}

@end
