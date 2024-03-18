//
//  SceneCards.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 8.5.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

/*
 
 This module prints out both the screen and print versions of the scene cards.
 Note that WebPrinter IS NOT agnostic or reusable anywhere, it's specifically
 customized for use with scene cards, and has forced landscape paper orientation.

 This is a very undocumented piece of code.
 AND, MIGHT I ADD some time later, this is a bunch of horrible spaghetti. I have no idea
 what I've been thinking while writing this shit. The whole class should rewritten ASAP.
 
 Update 2022:
 Yes, this is very dated and should absolutely be rethought.
 
 Update 2022/05:
 Too late.
 
 Update 2023/07:
 Yeah, please rewrite this to be compatible with both macOS and iOS.
 
 */

#import <BeatParsing/BeatParsing.h>
#import <BeatCore/BeatCore.h>
#import "SceneCards.h"
#import <BeatPlugins/BeatHTMLPrinter.h>
#import <WebKit/WebKit.h>

#define SNIPPET_LENGTH 190

@interface SceneCards ()
@property (nonatomic) NSArray* cards;
@property (nonatomic) BeatHTMLPrinter *webPrinter;
@end

@implementation SceneCards

- (void)awakeFromNib {
	[super awakeFromNib];
	
	self.webPrinter = [[BeatHTMLPrinter alloc] initWithName:@"Scene Cards"];
	[self createHTMLView];
}

- (void)setup {
	// Set up index card view
	[_cardView.configuration.userContentController addScriptMessageHandler:self name:@"cardClick"];
	[_cardView.configuration.userContentController addScriptMessageHandler:self name:@"setColor"];
	[_cardView.configuration.userContentController addScriptMessageHandler:self name:@"move"];
	[_cardView.configuration.userContentController addScriptMessageHandler:self name:@"printCards"];
	_cardView.configuration.websiteDataStore = WKWebsiteDataStore.nonPersistentDataStore;
}

- (void)removeHandlers {
	[_cardView.configuration.userContentController removeScriptMessageHandlerForName:@"cardClick"];
	[_cardView.configuration.userContentController removeScriptMessageHandlerForName:@"setColor"];
	[_cardView.configuration.userContentController removeScriptMessageHandlerForName:@"move"];
	[_cardView.configuration.userContentController removeScriptMessageHandlerForName:@"printCards"];
	self.cardView.navigationDelegate = nil;
	self.cardView = nil;
}


- (void)createHTMLView {
	// Create the HTML
	NSError *error = nil;
	
	NSString *cssPath = [[NSBundle mainBundle] pathForResource:@"CardCSS.css" ofType:@""];
	NSString *css = [NSString stringWithContentsOfFile:cssPath encoding:NSUTF8StringEncoding error:&error];
	
	NSString *jsPath = [[NSBundle mainBundle] pathForResource:@"CardView.js" ofType:@""];
	NSString *javaScript = [NSString stringWithContentsOfFile:jsPath encoding:NSUTF8StringEncoding error:&error];
	
	NSString *dragulaPath = [[NSBundle mainBundle] pathForResource:@"dragula.js" ofType:@""];
	NSString *dragula = [NSString stringWithContentsOfFile:dragulaPath encoding:NSUTF8StringEncoding error:&error];

	NSString* content = [NSString stringWithFormat:@"<html><head><title>Index Cards</title><style>%@</style>", css];
	content = [content stringByAppendingFormat:@"<script>%@</script>", dragula];
	content = [content stringByAppendingFormat:@"</head><body class='zoomLevel-2'>"];
	
	// Spinner
	content = [content stringByAppendingFormat:@"<div id='wait'><div class='lds-spinner'><div></div><div></div><div></div><div></div><div></div><div></div><div></div><div></div><div></div><div></div><div></div><div></div></div></div>"];
	
	content = [content stringByAppendingString:[self createMenu]];
	
	content = [content stringByAppendingString:@"<div id='debug'></div><div id='container'>"];
	content = [content stringByAppendingFormat:@"</div><script>let standalone = false;\n%@</script></body></html>", javaScript];
	
	// Replace placeholders
	content = [BeatLocalization localizeString:content];
		
	[_cardView loadHTMLString:content baseURL:nil];
}

- (NSString*)createMenu {
	return @"<div id='menu'>\
			 <div id='print' class='ui'>⎙ #cardView.print#</div>\
			 <div id='filters'>\
				<input type='checkbox' name='scenes' onclick='filter(this)' checked> 🎬 \
				<input type='checkbox' name='sections' onclick='filter(this)' checked> # \
				<input type='checkbox' name='lowerSections' onclick='filter(this)' checked> ## \
				<input type='checkbox' name='lowestSections' onclick='filter(this)' checked> ### \
			 </div>\
			 <div id='zoom'>\
				<button onclick='zoomOut()'>-</button>\
				<button onclick='zoomIn()'>+</button>\
			 </div>\
			<div id='debug'></div>\
			</div>";
}

- (void)reload {
	[self reloadCardsWithVisibility:NO changed:-1];
}

- (void)reloadCardsWithVisibility:(bool)alreadyVisible changed:(NSInteger)changedIndex {
	_cards = [self getSceneCards];
	
	NSError *error;
	NSData *jsonData = [NSJSONSerialization dataWithJSONObject:_cards options:NSJSONWritingPrettyPrinted error:&error];
	NSString *json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
		
	NSString *jsCode;
	
	if (alreadyVisible && changedIndex > -1) {
		// Already visible, changed index
		jsCode = [NSString stringWithFormat:@"createCards(%@, true, %lu);", json, changedIndex];
	} else if (alreadyVisible && changedIndex < 0) {
		// Already visible, no index
		jsCode = [NSString stringWithFormat:@"createCards(%@, true);", json];
	} else {
		// Fresh new view
		jsCode = [NSString stringWithFormat:@"createCards(%@);", json];
	}
	
	[_cardView evaluateJavaScript:jsCode completionHandler:nil];
}

- (NSArray *)getSceneCards {
	// Returns an array of dictionaries containing the card data
	// Remember to set up the delegate
	
	NSMutableArray *sceneCards = [NSMutableArray array];
	NSInteger index = 0;
	
	NSArray *outline = self.delegate.parser.outline;

	for (OutlineScene *scene in outline) {
		if (scene.type == synopse ||
			(scene.type == section && scene.line.sectionDepth > 3)) {
			continue;
		}
		
		NSString *title = [scene.line.stripFormatting stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];
		if (scene.type == section) title = scene.line.stripFormatting;
		
		NSDictionary *sceneCard = @{
			@"sceneNumber": (scene.sceneNumber) ? scene.sceneNumber : @"",
			@"name": (scene.string) ? title : @"",
			@"title": (scene.string) ? title : @"", // for weird backwards compatibility stuff
			@"color": (scene.color) ? [scene.color lowercaseString] : @"",
			@"snippet": [self snippet:scene],
			@"type": scene.line.typeAsString.lowercaseString,
			@"sceneIndex": @([outline indexOfObject:scene]),
			@"selected": [NSNumber numberWithBool:[self isSceneSelected:scene]],
			@"position": [NSNumber numberWithInteger:scene.position],
			@"lineIndex": [NSNumber numberWithInteger:[_delegate.parser.lines indexOfObject:scene.line]],
			@"omited": [NSNumber numberWithBool:scene.omitted],
			@"depth": [NSNumber numberWithInteger:scene.sectionDepth]
		};
		
		[sceneCards addObject:sceneCard];
		
		index++;
	}
	
	return sceneCards;
}
- (bool)isSceneSelected:(OutlineScene*)scene {
	NSInteger position = self.delegate.selectedRange.location;
	
	if (position >= scene.position && position < scene.position + scene.length) return YES;
	else return NO;
}

- (NSString *)snippet:(OutlineScene *)scene {
	NSUInteger index = [_delegate.parser.lines indexOfObject:scene.line];
	
	// If we won't reach the end of file with this, let's take out a snippet from the script for the card
	NSUInteger lineIndex = index + 1;
	NSString * snippet = @"";
	
	// Get first paragraph
	// Somebody might be just using card view to craft a step outline, so we need to check that this line is not a scene heading.
	// Also, we'll use SYNOPSIS line as the snippet in case it's the first line
	while (lineIndex < _delegate.parser.lines.count) {
		Line* line = _delegate.parser.lines[lineIndex];
		if (line.isOutlineElement) break;
		else if (line.omitted && !line.note) {
			lineIndex++;
			continue;
		}
		
		if (!line.note) snippet = line.stripFormatting;
		else {
			snippet = [line.string stringByReplacingOccurrencesOfString:@"[[" withString:@""];
			snippet = [snippet stringByReplacingOccurrencesOfString:@"]]" withString:@""];
		}
		break;
	}
	
	// If it's longer than we want, split into sentences
	if (snippet.length > SNIPPET_LENGTH) {
		NSMutableArray *sentences = [NSMutableArray arrayWithArray:[snippet matches:RX(@"(.+?[\\.\\?\\!]+\\s*)")]];
		NSString *result = @"";
		
		// If there are no real sentences in the paragraph, just cut it and add ... after the text
		if (sentences.count < 1) return [[snippet substringToIndex:SNIPPET_LENGTH - 3] stringByAppendingString:@"..."];

		// Add as many sentences as possible
		for (NSString *sentence in sentences) {
			result = [result stringByAppendingString:sentence];
			if (result.length > SNIPPET_LENGTH || result.length > SNIPPET_LENGTH - 15) break;
		}
		
		if (result.length) snippet = result; else snippet = @"";
	}
	
	return snippet;
}

- (void)printCards {
	[self printCardsWithInfo:self.delegate.printInfo.copy];
}
- (void)printCardsWithInfo:(NSPrintInfo *)printInfo {
	// This creates a HTML document for printing out the index cards
	// JEsus christ or any other human with godlike properties, what is this shit.
	
	NSWindow *window = NSApp.mainWindow;
	if (!window) window = NSApp.windows.firstObject;
	
	NSError *error = nil;
	NSString *cssPath = [NSBundle.mainBundle pathForResource:@"CardPrintCSS.css" ofType:@""];
	NSString *css = [NSString stringWithContentsOfFile:cssPath encoding:NSUTF8StringEncoding error:&error];
	
	NSMutableArray *htmlCards = [NSMutableArray array];
	
	// Retrieve cards through the delegate and put them into a dictionary
	_cards = [self getSceneCards];
		
	// Create separate html snippets from all the cards
	for (NSDictionary *scene in _cards) {
		NSString * type = scene[@"type"];
		NSString *card = @"";
		if ([type isEqualToString:@"heading"]) {
			card = [NSString stringWithFormat:
							  @"<div class='cardContainer'>"
								"<div class='card'>"
									"<div class='header'>"
										"<div class='sceneNumber'>%@</div> <h3>%@</h3>"
									"</div>"
									"<p>%@</p>"
								"</div>"
							"</div>", scene[@"sceneNumber"], scene[@"name"], scene[@"snippet"]];
		} else {
			// Do something if you want to add cards for sections etc.
		}
		if (card.length) [htmlCards addObject:card];
	}
	
	if (htmlCards.count < 1) {
        NSAlert* alert = [[NSAlert alloc] init];
        alert.messageText = @"No Printable Cards";
        alert.informativeText = @"You have no scenes set up in the script. Scene cards don't include section headers and synopses.";
		alert.alertStyle = NSAlertStyleWarning;
        [alert beginSheetModalForWindow:window completionHandler:nil];
		return;
	}
	
	NSMutableString *html = [NSMutableString stringWithFormat:@""];
	
	//NSInteger cardsPerRow = round((printInfo.paperSize.width - 20) / 165);
	NSInteger cardsPerRow = 3;

	// Orientation is ALWAYS LANDSCAPE
	NSInteger maxRows = floor(printInfo.imageablePageBounds.size.width / 165);
	
	NSInteger cardsOnRow = 0;
	NSInteger rows = 0;
	
	for (NSString *card in htmlCards) {
		[html appendString:card];
		cardsOnRow++;
		
		if (cardsOnRow >= cardsPerRow) {
			cardsOnRow = 0;
			rows++;
		}
		if (rows >= maxRows) {
			[html appendString:@"</section><div class='pageBreak'></div><section>"];

			rows = 0;
			cardsOnRow = 0;
		}
	}
	
	NSString* content = [NSString stringWithFormat:@"<html><head><style>%@</style></head><body><div id='container'><section>%@</section></div></body></html>", css, html];
	
	// I'm not sure why this fixes a bug with the page sizing
	printInfo.topMargin = 5;
	printInfo.bottomMargin = 5;
	printInfo.leftMargin = 5;
	printInfo.rightMargin = 5;
	printInfo.orientation = NSPaperOrientationLandscape;
	
	[_webPrinter printHtml:content printInfo:printInfo];
}

- (NSString *)HTMLstring:(NSString*)string {
	string = [string stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];
	string = [string stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"];
	return string;
}


#pragma mark - Public refresh methods


- (void)refreshCards {
	// Refresh cards assuming the view isn't visible
	[self reloadCardsWithVisibility:NO changed:-1];
}

- (void)refreshCards:(BOOL)alreadyVisible {
	// Just refresh cards, no change in index
	[self reloadCardsWithVisibility:alreadyVisible changed:-1];
}

- (void)refreshCards:(BOOL)alreadyVisible changed:(NSInteger)changedIndex {
	[self reloadCardsWithVisibility:alreadyVisible changed:changedIndex];
}



#pragma mark - JavaScript handler

- (void)userContentController:(nonnull WKUserContentController *)userContentController didReceiveScriptMessage:(nonnull WKScriptMessage *)message {
	// I have no fucking idea what any of this does.
	// Send in the clowns. There ought to be clowns.
	
	if ([message.name isEqualToString:@"cardClick"]) {
		[_delegate toggleCards:nil];
		
		OutlineScene *scene = self.delegate.parser.outline[[message.body intValue]];
		if (scene != nil) [_delegate scrollToLine:scene.line];

		return;
	}
	
	else if ([message.name isEqualToString:@"move"]) {
		if ([message.body rangeOfString:@","].location != NSNotFound) {
			NSArray *fromTo = [message.body componentsSeparatedByString:@","];
			if (fromTo.count < 2) return;
			
			NSInteger from = [fromTo[0] integerValue];
			NSInteger to = [fromTo[1] integerValue];
			
			NSInteger changedIndex = -1;
			if (from < to) changedIndex = to -1; else changedIndex = to;
			
			NSArray *outline = self.delegate.parser.outline;
			if (outline.count < 1) return;
			
			OutlineScene *scene = [outline objectAtIndex:from];
			
			[self.delegate moveScene:scene from:from to:to];
			
			// Refresh the view, tell it's already visible
			[self reloadCardsWithVisibility:YES changed:changedIndex];
			
			return;
		}
	}

	else if ([message.name isEqualToString:@"setColor"]) {
		if ([message.body rangeOfString:@":"].location != NSNotFound) {
			NSArray *indexAndColor = [message.body componentsSeparatedByString:@":"];
			NSUInteger index = [[indexAndColor objectAtIndex:0] integerValue];
			NSString *color = [indexAndColor objectAtIndex:1];
			
			Line *line = [_delegate.parser.lines objectAtIndex:index];
			OutlineScene *scene = [self.delegate.parser sceneAtPosition:line.position];
			
			[self.delegate.textActions setColor:color forScene:scene];
		}
	}
	
	else if ([message.name isEqualToString:@"printCards"]) {
		[self printCards];
	}
}

@end

/*
 
 i leave home at seven
 under a heavy sky
 i ride my bike up
 i ride my bike down
 
 november smoke
 and my toes go numb
 a new color on the globe
 it goes from white to red
 a little voice in my head says:
 oh, oh
 
 */
