//
//  BeatHTMLScript.m
//	Modified for Beat from FNHTMLScript
//
//  Copyright (c) 2012-2013 Nima Yousefi & John August
//  Parts copyright © 2019-2020 Lauri-Matti Parppei / KAPITAN!
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
 
 This piece of code outputs the screenplay as HTML. It is based on FNHTMLScript.m.
 It now natively uses the Beat data structure (Line) and the Continuous Fountain Parser
 instead of the old, open source Fountain stuff. It's now about 10 times faster and
 more reliable.
  
 Note that HTML output links to either screen or print CSS depending on the target format.
 Print & PDF versions rely on PrintCSS.css and preview mode uses ScriptCSS.css.
 Pagination is a bit messy, but generally speaking, it inherits print settings
 and page size either from the original Document class or defaults to A4.
 
 The old open source stuff was very, very dated, and in late 2019 I ran into pretty
 big problems, which had to do with computer architecture stuff. I was ill prepared
 for my little programming project requiring any understanding of that. The code
 used a library called RegexKitLite and I had to rewrite everything referring to it.
 
 I saved the rant below from those days, because it's fairly funny and touching:
 
 - As I'm writing this, some functions in RegexKitLite.h have been deprecated in
   macOS 10.12+. Fair enough - it was apparently last updated in 2010.
 
   Back then, I hadn't made any films. In 2010, I was young, madly in love and
   had dreams and aspirations. I had just recently started my studies in a film school.
   In 9 years, I figured back then, I'd be making films that really communicated the
   pain I had gone through. My films would reach out to other lonely people, confined
   in their gloomy tomb, assured of their doom.
 
   Well.
 
   Instead, I'm reading about fucking C enumerators and OS spin locks to be able to
   build my own fucking software, which - mind you - ran just fine a few weeks ago.
 
   Hence, I tried to replace the deprecated spin locks of RegexKitLite.h with modern ones.
   It was about to destroy my inner child. I just wanted to write nice films, I wasn't
   planning on fucking learning any motherfucking C!!!!!!
 
   SO, if you are reading this: Beat now relies on a customized RegexKitLite, which might
   work or not. It could crash systems all around the world. It could consume your
   computer's soul and kill any glimpse of hope.
 
   I could have spent these hours with my dear friends, my lover or just watching flowers
   grow and maybe talking to them. Or even writing my film. I didn't. Here I am, typing
   this message to some random fucker who, for whatever reason, decides to take a look at
   my horrible code sometime in the future.
 
   Probably it's me, though.
 
   What can I say. STOP WASTING YOUR LIFE AND GO FUCK YOURSELF.

 ---
 
 UPDATE 21th Jan 2020:
 References to RegexKitLite have been removed. Totally.
 It has resulted in some pretty strange solutions, and self-customizing a Regex library,
 but for now it works - also on modern systems.
 
 UPDATE 17th May 2020:
 This could be rewritten to conform with our Line* class instead of FNElement / FNScript.
 I also stumbled upon the message written above, and omg past me, I'd send you some hugs and kisses
 if I could, but I'm writing this amidst the COVID-19 pandemic so I have to keep my distance.
 
 UPDATE 4th September 2020:
 I implemented the idea presented above. It now works like a charm and is a lot faster.
 At first, it was used only for the previews, but now every single reference to the old
 Fountain stuff has been removed!
 
 UPDATE sometime in November 2020:
 The code has been cleaned up a bit.
 
*/

#import "BeatHTMLScript.h"
#import "Line.h"
#import "FountainRegexes.h"
#import "BeatPaginator.h"
#import "RegExCategories.h"
#import "BeatUserDefaults.h"

#define BOLD_OPEN @"<b>"
#define BOLD_CLOSE @"</b>"
#define ITALIC_OPEN @"<i>"
#define ITALIC_CLOSE @"</i>"
#define UNDERLINE_OPEN @"<u>"
#define UNDERLINE_CLOSE @"</u>"
#define STRIKEOUT_OPEN @"<del>"
#define STRIKEOUT_CLOSE @"</del>"

@interface BeatHTMLScript ()

@property (readonly, copy, nonatomic) NSString *cssText;
@property (nonatomic) NSInteger numberOfPages;
@property (nonatomic) NSString *currentScene;
@property (nonatomic) NSString *header;
@property (nonatomic) bool print;
@property (nonatomic) BeatHTMLOperation operation;
@property (nonatomic) bool printSceneNumbers;
@property (nonatomic) bool coloredPages;
@property (nonatomic) NSString* revisionColor;
@end

@implementation BeatHTMLScript

// The new, modernized way
- (id)initWithScript:(NSDictionary*)script settings:(BeatExportSettings*)settings {
	self = [super init];
	
	if (settings) {
		_script = script[@"script"];
		_titlePage = script[@"title page"];
		
		_document = settings.document;
		
		_header = settings.header;
		_currentScene = settings.currentScene;
		_operation = settings.operation;
		_printSceneNumbers = settings.printSceneNumbers;
		
		_revisionColor = settings.revisionColor;
		_coloredPages = settings.coloredPages;
		
		// Simple boolean for later checks
		if (_operation == ForPrint) _print = YES;
	}
	
	return self;
}

// The old methods should be abolished for the sake of clarity,
// but they remain here for the sake of compatibility, for now:

- (id)initForPreview:(NSDictionary *)script document:(NSDocument*)document scene:(NSString*)scene printSceneNumbers:(bool)printSceneNumbers
{
	return [self initWithScript:script document:document scene:scene operation:ForPreview printSceneNumbers:printSceneNumbers];
}
- (id)initForQuickLook:(NSDictionary *)script {
	return [self initWithScript:script document:nil scene:nil operation:ForQuickLook printSceneNumbers:YES];
}
- (id)initForPrint:(NSDictionary *)script document:(NSDocument*)document printSceneNumbers:(bool)printSceneNumbers
{
	return [self initWithScript:script document:document scene:nil operation:ForPrint printSceneNumbers:printSceneNumbers];
}

- (id)initWithScript:(NSDictionary*)script document:(NSDocument*)document scene:(NSString*)currentScene operation:(BeatHTMLOperation)operation printSceneNumbers:(bool)printSceneNumbers {
	self = [super init];
	
	if (self) {
		_script = script[@"script"];
		_titlePage = script[@"title page"];
		_header = script[@"header"];
		_currentScene = currentScene;
		
		_font = [NSFont fontWithName:@"Courier" size:12];
		_document = document;
		_operation = operation;
		
		_printSceneNumbers = printSceneNumbers;
		
		if (_operation == ForPrint) _print = YES;
	}
	
	return self;
}


#pragma mark - HTML content

- (NSInteger)pages {
	return _numberOfPages + 1;
}

- (NSString *)html
{	
	NSMutableString *html = [NSMutableString string];
	[html appendString:[self htmlHeader]];
	[html appendString:[self content]];
	[html appendString:[self htmlFooter]];

	return html;
}

- (NSString *)htmlHeader {
	NSMutableString *html = [NSMutableString string];
	
	NSString *bodyClasses = @"";
	if (_operation == ForQuickLook) bodyClasses = [bodyClasses stringByAppendingString:@" quickLook"];

	[html appendString:@"<!DOCTYPE html>\n"];
	[html appendString:@"<html>\n"];
	[html appendString:@"<head><title>Print Preview</title>\n"];
	[html appendString:@"<meta name='viewport' content='width=device-width, initial-scale=1.2'/>\n"];
	
	[html appendString:@"<style type='text/css'>\n"];
	[html appendString:self.cssText];
	[html appendString:@"</style>\n"];
	[html appendString:@"</head>\n"];
	[html appendFormat:@"<body class='%@'>", bodyClasses];
	
	return html;
}

- (NSString *)htmlFooter {
	NSMutableString *html = [NSMutableString string];
	[html appendString:[self previewJS]];
	[html appendString:@"<script name='scrolling'></script>"];
	[html appendString:@"</body>\n"];
	[html appendString:@"</html>"];

	return html;
}

- (NSString *)content {
	// N.B. this method can be called alone by itself to return pure content,
	// as can bodyForScript. Dont' include anything that could break that functionality.
	
	if (!self.bodyText) {
		self.bodyText = [self bodyForScript];
	}
	
	NSMutableString *html = [NSMutableString string];
	[html appendString:@"<article>\n"];
	if (_operation == ForPreview) [html appendString:[self previewUI]];	// Adds the 'close' button
	[html appendString:self.bodyText];
	[html appendString:@"</article>\n"];
	
	return html;
}


- (NSString *)cssText
{    
	NSString *cssFile;
	if (!_print) cssFile = @"ScriptCSS.css";
	else cssFile = @"PrintCSS.css";

	NSError *error;
	NSString *path = [[NSBundle mainBundle] pathForResource:cssFile ofType:@""];
	NSString *css = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];

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
    
	// Styles
	bool boldedHeading = [BeatUserDefaults.sharedDefaults getBool:@"headingStyleBold"];
	bool underlinedHeading = [BeatUserDefaults.sharedDefaults getBool:@"headingStyleUnderline"];
	
	for (NSDictionary *dict in self.titlePage) {
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
			
            [body appendFormat:@"<p class='%@'>%@</p>", @"title", [self format:values]];
			[titlePage removeObjectForKey:@"title"];
        }
        else {
            [body appendFormat:@"<p class='%@'>%@</p>", @"title", @"Untitled"];
        }

		// Credit
		// Add support for "author" (without the plural)
        if (titlePage[@"credit"] || titlePage[@"authors"] || titlePage[@"author"]) {
            if (titlePage[@"credit"]) {
                NSArray *obj = titlePage[@"credit"];
                NSMutableString *values = [NSMutableString string];
                for (NSString *val in obj) {
                    [values appendFormat:@"%@<br>", val];
                }
				[body appendFormat:@"<p class='%@'>%@</p>", @"credit", [self format:values]];
				[titlePage removeObjectForKey:@"credit"];
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
                [body appendFormat:@"<p class='%@'>%@</p>", @"authors", [self format:values]];
				[titlePage removeObjectForKey:@"authors"];
            }
			else if (titlePage[@"author"]) {
                NSArray *obj = titlePage[@"author"];
                NSMutableString *values = [NSMutableString string];
                for (NSString *val in obj) {
                    [values appendFormat:@"%@<br>", val];
                }
                [body appendFormat:@"<p class='%@'>%@</p>", @"authors", [self format:values]];
				[titlePage removeObjectForKey:@"author"];
            }
            else {
                [body appendFormat:@"<p class='%@'>%@</p>", @"authors", @""];
            }
        }
		// Source
		if (titlePage[@"source"]) {
			NSArray *obj = titlePage[@"source"];
			NSMutableString *values = [NSMutableString string];
			for (NSString *val in obj) {
				[values appendFormat:@"%@<br>", val];
			}
			[body appendFormat:@"<p class='%@'>%@</p>", @"source", [self format:values]];
			[titlePage removeObjectForKey:@"source"];
		}
		
		[body appendFormat:@"</div>"];
		
		// Draft date
		[body appendFormat:@"<div class='versionInfo'>"];
		if (titlePage[@"draft date"]) {
			NSArray *obj = titlePage[@"draft date"];
			NSMutableString *values = [NSMutableString string];
			for (NSString *val in obj) {
				[values appendFormat:@"%@<br>", val];
			}
			[body appendFormat:@"<p class='%@'>%@</p>", @"draft-date", [self format:values]];
			[titlePage removeObjectForKey:@"draft date"];
		}
		[body appendFormat:@"</div>"];
		
		
		[body appendFormat:@"<div class='info'>"];
        
        // Contact
        if (titlePage[@"contact"]) {
            NSArray *obj = titlePage[@"contact"];
            NSMutableString *values = [NSMutableString string];
            for (NSString *val in obj) {
                [values appendFormat:@"%@<br>", val];
            }
            [body appendFormat:@"<p class='%@'>%@</p>", @"contact", [self format:values]];
			[titlePage removeObjectForKey:@"contact"];
        }
		
		// Notes
		if (titlePage[@"notes"]) {
			NSArray *obj = titlePage[@"notes"];
			NSMutableString *values = [NSMutableString string];
			for (NSString *val in obj) {
				[values appendFormat:@"%@<br>", val];
			}
			[body appendFormat:@"<p class='%@'>%@</p>", @"notes", [self format:values]];
			[titlePage removeObjectForKey:@"notes"];
		}
		
		// Append rest of the stuff
		for (NSString* key in titlePage) {
			NSArray *obj = titlePage[key];
			NSMutableString *values = [NSMutableString string];

			for (NSString *val in obj) {
				[values appendFormat:@"%@<br>", val];
			}
			// We won't set a class value based on the custom key, because it might conflict with existing css styles
			[body appendFormat:@"<p>%@</p>", [self format:values]];
		}
		
		[body appendFormat:@"</div>"];
		
        [body appendString:@"</section>"];
    }
    
    NSInteger dualDialogueCharacterCount = 0;
    NSSet *ignoringTypes = [NSSet setWithObjects:@"Boneyard", @"Comment", @"Synopsis", @"Section Heading", nil];
	
	BeatPaginator *paginator = [[BeatPaginator alloc] initWithScript:_script document:_document];
    NSUInteger maxPages = paginator.numberOfPages;
	
	_numberOfPages = maxPages;
	
	// Header string (make sure it's not null)
	NSString *header = (self.header) ? self.header : @"";
	if (header.length) header = [header stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];
	
	for (NSInteger pageIndex = 0; pageIndex < maxPages; pageIndex++) { @autoreleasepool {
        NSArray *elementsOnPage = [paginator pageAtIndex:pageIndex];
		
		NSString *pageClass = @"";
		
		// If we are coloring the revised pages, check for any changed lines here
		if (_coloredPages && _revisionColor.length && self.operation == ForPrint) {
			bool revised = NO;
			for (Line* line in elementsOnPage) {
				if (line.changed) {
					revised = YES; break;
				}
			}
			
			if (revised) pageClass = [NSString stringWithFormat:@"revised %@", _revisionColor];
		}
		
        
        // Begin page
		[body appendFormat:@"<section class='%@'>", pageClass];
		
		int index = (int)pageIndex+1;
		int elementCount = 0;
		
        if (self.customPage != nil) {
            if ([self.customPage integerValue] == 0) {
				if (self.print) {
					[body appendFormat:@"<p class='page-break-render'><span class='header-top'>%@</span></p>\n", header];
                } else {
                    [body appendFormat:@"<p class='page-break'></p>\n"];
                }
            } else {
                if (self.print) {
					// I don't understand this part. For some reason certain elements are cut off the page and have a random page number there when rendering. So, as a rational and solution-oriented person, I just removed the page number altogether if this happens.
					// - Lauri-Matti
					if (index < 2) {
                    	[body appendFormat:@"<p class='page-break-render'><span class='header-top'>%@</span> %d.</p>\n", header, [self.customPage intValue]];
					}
                } else {
                    [body appendFormat:@"<p class='page-break'>%d.</p>\n", [self.customPage intValue]];
                }
            }
        } else {
			int pageNumber = (int)pageIndex + 1;
			// Only print page numbers after first page
			
			if (self.print) {
				if (pageNumber > 1)
					[body appendFormat:@"<p class='page-break-render'><span class='header-top'>%@</span> %d.</p>\n", header, (int)pageIndex+1];
				else
					[body appendFormat:@"<p class='page-break-render'><span class='header-top'>%@</span> &nbsp;</p>\n", header];
            } else {
				if (pageNumber > 1) [body appendFormat:@"<p class='page-break'>%d.</p>\n", (int)pageIndex+1];
				else [body appendFormat:@"<p class='page-break'></p>\n"];
            }
        }
		
		// We need to catch lyrics not to make them fill up a paragraph
		bool isLyrics = false;
	
        for (Line *line in elementsOnPage) {
			bool beginBlock = false;
			
			if ([ignoringTypes containsObject:line.typeAsFountainString]) {
				// Close possible blocks
				if (isLyrics) {
					// Close lyrics block
					[body appendFormat:@"</p>\n"];
					isLyrics = false;
				}
                continue;
            }
			
			if ([line.typeAsFountainString isEqualToString:@"Page Break"]) {
				// Close possible blocks
				if (isLyrics) {
					// Close lyrics block
					[body appendFormat:@"</p>\n"];
					isLyrics = false;
				}
                continue;
            }
			
			// Stop dual dialogue
			if (dualDialogueCharacterCount == 2 &&
				!(line.type == dualDialogueParenthetical ||
				 line.type == dualDialogue || line.type == dualDialogueMore)) {
				[body appendString:@"</div></div>\n"];
				dualDialogueCharacterCount = 0;
			}
			
			// Catch dual dialogue
			if (line.type == character && line.nextElementIsDualDialogue) {
				dualDialogueCharacterCount++;
				[body appendString:@"<div class='dual-dialogue'>\n"];
				[body appendString:@"<div class='dual-dialogue-left'>\n"];
            }
			
			if (line.type == dualDialogueCharacter && dualDialogueCharacterCount == 1) {
				dualDialogueCharacterCount++;
                    [body appendString:@"</div>\n<div class='dual-dialogue-right'>\n"];
			}
            
            NSMutableString *text = [NSMutableString string];
		

			// Begin lyrics block
			if (line.type == lyrics) {
				if (!isLyrics) {
					beginBlock = true;
					isLyrics = true;
				}
			} else {
				// Close lyrics block
				if (isLyrics) {
					[body appendFormat:@"</p>\n"];
					isLyrics = false;
				}
			}
            
			// Format string for HTML (if it's not a heading)
			[text setString:[self htmlStringFor:line]];
			
			// To avoid underlining heading tails, let's trim the text if needed
			if (line.type == heading && underlinedHeading) [text setString:[text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet]];

			
			// Preview shortcuts
			if (line.type == heading && _operation == ForPreview) {
				[text setString:[NSString stringWithFormat:@"<a href='#' onclick='selectScene(this);' sceneIndex='%lu'>%@</a>", line.sceneIndex, text]];
			}

			NSMutableString *additionalClasses = [NSMutableString string];
			
			if (line.type == heading && line.sceneNumber) {
				// Add scene number ID to HTML, but don't print it if it's toggled off
				NSString *printedSceneNumber;
				if (self.printSceneNumbers) printedSceneNumber = line.sceneNumber;
				else printedSceneNumber = @"";
				
				NSString *sceneNumberLeft = [NSString stringWithFormat:@"<span id='scene-%@' class='scene-number-left'>%@</span>", line.sceneNumber, printedSceneNumber];
				NSString *sceneNumberRight = [NSString stringWithFormat:@"<span class='scene-number-right'>%@</span>", printedSceneNumber];
				[text setString:[NSString stringWithFormat:@"%@%@%@", sceneNumberLeft, text, sceneNumberRight]];
				
				if (boldedHeading) [additionalClasses appendString:@" bold"];
				if (underlinedHeading) [additionalClasses appendString:@" underline"];
			}
			
            if (![text isEqualToString:@""]) {
				if (line.type == centered) {
                    [additionalClasses appendString:@" center"];
                }
				if (elementCount == 0) [additionalClasses appendString:@" first"];
				
				// Mark as changed, if comparing against another file or the line contains added/removed text
				if (line.changed || line.additionRanges.count || line.removalRanges.count) [additionalClasses appendString:@" changed"];
				
				// If this line isn't part of a larger block, output it as paragraph
				if (!beginBlock && !isLyrics) {
					[body appendFormat:@"<p class='%@%@'>%@</p>\n", [self htmlClassForType:line.typeAsFountainString], additionalClasses, text];
				} else {
					if (beginBlock) {
						// Begin new block
						[body appendFormat:@"<p class='%@%@'>%@<br>", [self htmlClassForType:line.typeAsFountainString], additionalClasses, text];
					} else {
						// Continue the block
						// note: we can't use \n after the lines to make it more easy read, because we want to preserve the white space
						[body appendFormat:@"%@<br>", text];
					}
				}
			} else {
				// Just in case
				if (isLyrics) {
					// Close lyrics block
					[body appendFormat:@"</p>\n"];
					isLyrics = false;
				}
			}
			
			elementCount++;
		} }
		
		[body appendFormat:@"</section>"];
    }
	
    return body;
}

#pragma mark - JavaScript functions

- (NSString*)previewUI {
	return @"<div id='close' class='ui' onclick='closePreview();'>✕</div>";
}

- (NSString*)previewJS {
	return @"" \
	"<script>function scrollToScene(scene) { console.log('scroll to: ' + scene); var el = document.getElementById('scene-' + scene); el.scrollIntoView({ behavior:'auto',block:'center',inline:'center' }); }</script>" \
	"<script>var zoomLevel = 100;" \
		"function zoomIn() { if (zoomLevel < 200) { zoomLevel += 10; document.body.style.zoom = zoomLevel + '%'; } }" \
		"function zoomOut() { if (zoomLevel > 50) { zoomLevel -= 10;  document.body.style.zoom = zoomLevel + '%'; } }" \
	"</script>" \
	"<script>function selectScene(e) { window.webkit.messageHandlers.selectSceneFromScript.postMessage(e.getAttribute('sceneIndex')); }</script>" \
	"<script>function closePreview () { window.webkit.messageHandlers.closePrintPreview.postMessage('close'); } </script>";
}

#pragma mark - Helper methods

- (NSString *)htmlClassForType:(NSString *)elementType
{
	return [[elementType lowercaseString] stringByReplacingOccurrencesOfString:@" " withString:@"-"];
}

- (NSString*)format:(NSString*) string {
	string = [RX(BOLD_ITALIC_UNDERLINE_PATTERN) stringByReplacingMatchesInString:string options:0 range:NSMakeRange(0, string.length) withTemplate:@"<u><em><strong>$2</strong></em></u>"];
	string = [RX(BOLD_ITALIC_PATTERN) stringByReplacingMatchesInString:string options:0 range:NSMakeRange(0, string.length) withTemplate:@"<strong><em>$2</em></strong>"];
	string = [RX(BOLD_UNDERLINE_PATTERN) stringByReplacingMatchesInString:string options:0 range:NSMakeRange(0, string.length) withTemplate:@"<strong><u>$2</u></strong>"];
	string = [RX(ITALIC_UNDERLINE_PATTERN) stringByReplacingMatchesInString:string options:0 range:NSMakeRange(0, string.length) withTemplate:@"<u><em>$2</em></u>"];
	string = [RX(BOLD_PATTERN) stringByReplacingMatchesInString:string options:0 range:NSMakeRange(0, string.length) withTemplate:@"<strong>$2</strong>"];
	string = [RX(ITALIC_PATTERN) stringByReplacingMatchesInString:string options:0 range:NSMakeRange(0, string.length) withTemplate:@"<em>$2</em>"];
	string = [RX(UNDERLINE_PATTERN) stringByReplacingMatchesInString:string options:0 range:NSMakeRange(0, string.length) withTemplate:@"<u>$2</u>"];
	
	// Remove escape characters
	string = [string stringByReplacingOccurrencesOfString:@"\\*" withString:@"*"];
	string = [string stringByReplacingOccurrencesOfString:@"\\_" withString:@"_"];
	string = [string stringByReplacingOccurrencesOfString:@"\\@" withString:@"@"];
	string = [string stringByReplacingOccurrencesOfString:@"\\**" withString:@"**"];

	return string;
}
- (NSString*)htmlStringFor:(Line*)line {
	// We use the FDX attributed string to create a HTML representation of Line objects
	NSAttributedString *string = line.attributedStringForFDX;
	
	// Ignore any formatting and only include CONTENT ranges
	NSMutableAttributedString *result = [[NSMutableAttributedString alloc] init];
	[line.contentRanges enumerateRangesUsingBlock:^(NSRange range, BOOL * _Nonnull stop) {
		[result appendAttributedString:[string attributedSubstringFromRange:range]];
	}];
		
	NSMutableString *htmlString = [NSMutableString string];
	
	// Get stylization in the current attribute range
	[result enumerateAttributesInRange:(NSRange){0, result.length} options:0 usingBlock:^(NSDictionary<NSAttributedStringKey,id> * _Nonnull attrs, NSRange range, BOOL * _Nonnull stop) {
		NSMutableString* text = [result.string substringWithRange:range].mutableCopy;
		// Opening and closing tags
		NSString *open = @"";
		NSString *close = @"";
		
		NSString *styleString = attrs[@"Style"];

		// Append corresponding HTML tags to opening & closing strings, ie. open = "<b>", close = "</b>"
		if (styleString.length) {
			NSMutableArray *styleArray = [NSMutableArray arrayWithArray:[styleString componentsSeparatedByString:@","]];
			[styleArray removeObject:@""];
						
			if ([styleArray containsObject:@"Bold"]) {
				open = [open stringByAppendingString:BOLD_OPEN];
				close = [close stringByAppendingString:BOLD_CLOSE];
			}
			if ([styleArray containsObject:@"Italic"]) {
				open = [open stringByAppendingString:ITALIC_OPEN];
				close = [close stringByAppendingString:ITALIC_CLOSE];
			}
			if ([styleArray containsObject:@"Underline"]) {
				open = [open stringByAppendingString:UNDERLINE_OPEN];
				close = [close stringByAppendingString:UNDERLINE_CLOSE];
			}
			if ([styleArray containsObject:@"Strikeout"]) {
				open = [open stringByAppendingString:STRIKEOUT_OPEN];
				close = [close stringByAppendingString:STRIKEOUT_CLOSE];
			}
			if ([styleArray containsObject:@"Removal"]) {
				open = [open stringByAppendingString:STRIKEOUT_OPEN];
				close = [close stringByAppendingString:STRIKEOUT_CLOSE];
			}
		}
		
		// Append snippet to paragraph
		[htmlString appendString:[NSString stringWithFormat:@"%@%@%@", open, [self escapeString:text], close]];
	}];
	
	// Create HTML line breaks
	[htmlString replaceOccurrencesOfString:@"\n" withString:@"<br>" options:0 range:(NSRange){0,htmlString.length}];
	
	return htmlString;
}

- (NSString*)escapeString:(NSString*)stringToEscape
{
	NSMutableString *string = [NSMutableString stringWithString:stringToEscape];
	[string replaceOccurrencesOfString:@"&"  withString:@"&amp;"  options:NSLiteralSearch range:NSMakeRange(0, [string length])];
	[string replaceOccurrencesOfString:@"\"" withString:@"&quot;" options:NSLiteralSearch range:NSMakeRange(0, [string length])];
	[string replaceOccurrencesOfString:@"'"  withString:@"&#x27;" options:NSLiteralSearch range:NSMakeRange(0, [string length])];
	[string replaceOccurrencesOfString:@">"  withString:@"&gt;"   options:NSLiteralSearch range:NSMakeRange(0, [string length])];
	[string replaceOccurrencesOfString:@"<"  withString:@"&lt;"   options:NSLiteralSearch range:NSMakeRange(0, [string length])];
	
	return string;
}

@end

/*
 
 Li Po crumbles his poems
 sets them on
 fire
 floats them down the
 river.
 
 'what have you done?' I
 ask him.
 
 Li passes the
 bottle: 'they are
 going to end
 no matter what
 happens...
 
 I drink to his knowledge
 pass the bottle back
 
 sit tightly upon my poems
 which I have
 jammed halfway up my crotch
 
 I help him burn
 some more of his poems
 
 it floats well
 down
 the river
 lighting up the night
 as good words
 shoul.
 
 */
