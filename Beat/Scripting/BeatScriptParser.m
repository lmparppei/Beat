//
//  BeatScriptParser.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 1.7.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//

/*
 
 A fantasy side-project for creating a JavaScript scripting possibility for Beat.
 The idea is to expose the lines & scenes to JavaScript (via JSON) and let the user
 make what they want with them. The trouble is, though, that easily manipulating the
 screenplay via JS would require resetting the whole text content after it' done.
 
 Also, I want to make it possible to open a window/panel with custom HTML content to
 make it easier to build some weird analytics / statistics tools.
 
 */

#import <Cocoa/Cocoa.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import <WebKit/WebKit.h>
#import "BeatScriptParser.h"
#import "Line.h"
#import "OutlineScene.h"
#import "ApplicationDelegate.h"
#import "BeatPluginManager.h"
#import <PDFKit/PDFKit.h>

@interface BeatScriptParser ()
@property (nonatomic) JSVirtualMachine *vm;
@property (nonatomic) JSContext *context;
@property (nonatomic) NSWindow *sheet;
@property (nonatomic) JSValue *sheetCallback;
@property (nonatomic) WKWebView *sheetWebView;
@property (nonatomic) BeatPlugin *plugin;
@end

@implementation BeatScriptParser


- (id)init
{
	if ((self = [super init]) == nil) { return nil; }
		
	_vm = [[JSVirtualMachine alloc] init];
	_context = [[JSContext alloc] initWithVirtualMachine:_vm];
	[_context setExceptionHandler:^(JSContext *context, JSValue *exception) {
		NSAlert *alert = [[NSAlert alloc] init];
		alert.messageText = @"Error running script";
		alert.informativeText = [NSString stringWithFormat:@"%@", exception];
		[alert addButtonWithTitle:@"OK"];
		[alert runModal];
	}];

	[_context setObject:[Line class] forKeyedSubscript:@"Line"];
	[_context setObject:[OutlineScene class] forKeyedSubscript:@"OutlineScene"];
	[_context setObject:self forKeyedSubscript:@"Beat"];
	
	return self;
}

#pragma mark - Running Scripts

- (void)runPlugin:(BeatPlugin*)plugin {
	self.plugin = plugin;
	_pluginName = plugin.name;
	
	[BeatPluginManager.sharedManager pathForPlugin:plugin.name];
	
	[self runScript:plugin.script];
}

- (void)runScript:(NSString*)string {
	[self setJSData];
	
	JSValue *value = [_context evaluateScript:string];
	NSLog(@"result %@", value);
}


/*
if ([fileManager fileExistsAtPath:filepath isDirectory:YES]) {
	
} else {
	[plugins addObject:filepath];
}
*/


#pragma mark - File i/o

- (void)openFile:(NSArray*)formats callBack:(JSValue*)callback {
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	openPanel.allowedFileTypes = formats;
	[openPanel beginSheetModalForWindow:self.delegate.thisWindow completionHandler:^(NSModalResponse result) {
		if (result == NSModalResponseOK) {
			[openPanel close];
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC / 100), dispatch_get_main_queue(), ^(void){
				// some other method calls here
				[callback callWithArguments:@[openPanel.URL.path]];
			});
		} else {
			[callback callWithArguments:nil];
		}
	}];
}
- (NSString*)fileToString:(NSString*)path {
	NSError *error;
	NSString *result = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
	
	if (error) {
		[self alert:@"Error Opening File" withText:@"Error occurred while trying to open the file. Did you give Beat permission to acces it?"];
		return nil;
	} else {
		return result;
	}
}
- (NSString*)pdfToString:(NSString*)path {
	NSMutableString *result = [NSMutableString string];
	
	PDFDocument *doc = [[PDFDocument alloc] initWithURL:[NSURL fileURLWithPath:path]];
	if (!doc) return nil;
	
	for (int i = 0; i < doc.pageCount; i++) {
		PDFPage *page = [doc pageAtIndex:i];
		if (!page) continue;
		
		[result appendString:page.string];
	}
	
	return result;
}
- (NSString*)assetAsString:(NSString *)filename {
	if ([_plugin.files containsObject:filename]) {
		NSString *path = [[BeatPluginManager.sharedManager pathForPlugin:_plugin.name] stringByAppendingPathComponent:filename];
		return [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
	}
	return @"jee";
}

#pragma mark - Scripting methods accessible via JS

- (void)log:(NSString*)string {
	NSLog(@"# %@", string);
}

- (void)scrollTo:(NSInteger)location {
	[self.delegate scrollTo:location];
}
- (void)scrollToLineIndex:(NSInteger)index {
	[self.delegate scrollToLineIndex:index];
}
- (void)scrollToSceneIndex:(NSInteger)index {
	[self.delegate scrollToSceneIndex:index];
}
- (void)scrollToScene:(OutlineScene*)scene {
	@try {
		[self.delegate scrollToScene:scene];
	}
	@catch (NSException *e) {
		[self alert:@"Can't find scene" withText:@"Plugin tried to access an unknown scene"];
	}
}

- (void)addString:(NSString*)string toIndex:(NSUInteger)index {
	[self.delegate addString:string atIndex:index];
}
- (void)replaceRange:(NSInteger)from length:(NSInteger)length withString:(NSString*)string {
	NSRange range = NSMakeRange(from, length);
	@try {
		[self.delegate replaceRange:range withString:string];
	}
	@catch (NSException *e) {
		[self alert:@"Selection out of range" withText:@"Plugin tried to select something that was out of range. Further errors might ensue."];
	}
}
- (NSRange)selectedRange {
	return self.delegate.selectedRange;
}
- (void)setSelectedRange:(NSInteger)start to:(NSInteger)length {
	NSRange range = NSMakeRange(start, length);
	[self.delegate setSelectedRange:range];
}
- (NSString*)getText {
	NSMutableString *string = [NSMutableString string];
	
	for (Line* line in self.delegate.parser.lines) {
		if (line != self.delegate.parser.lines.lastObject) [string appendFormat:@"%@\n", line.string];
	}
	
	return string;
}

- (void)alert:(NSString*)title withText:(NSString*)info {
	if ([info isEqualToString:@"undefined"]) info = @"";
	
	NSAlert *alert = [self dialog:title withInfo:info];
	[alert addButtonWithTitle:@"OK"];
	[alert runModal];
}
- (bool)confirm:(NSString*)title withInfo:(NSString*)info {
	NSAlert *alert = [[NSAlert alloc] init];
	alert.messageText = title;
	alert.informativeText = info;
	
	[alert addButtonWithTitle:@"OK"];
	[alert addButtonWithTitle:@"Cancel"];
	
	NSModalResponse response = [alert runModal];
	if (response == NSModalResponseOK || response == NSAlertFirstButtonReturn) {
		return YES;
	} else {
		return NO;
	}
}
- (NSString*)prompt:(NSString*)prompt withInfo:(NSString*)info placeholder:(NSString*)placeholder defaultText:(NSString*)defaultText {
	if ([placeholder isEqualToString:@"undefined"]) placeholder = @"";
	if ([defaultText isEqualToString:@"undefined"]) defaultText = @"";
	
	NSAlert *alert = [self dialog:prompt withInfo:info];
	[alert addButtonWithTitle:@"OK"];
	[alert addButtonWithTitle:@"Cancel"];
	
	NSRect frame = NSMakeRect(0, 0, 300, 24);
	NSTextField *inputField = [[NSTextField alloc] initWithFrame:frame];
	inputField.placeholderString = defaultText;
	[alert setAccessoryView:inputField];
	[inputField setStringValue:defaultText];
	
	alert.window.initialFirstResponder = inputField;
	
	NSModalResponse response = [alert runModal];
	if (response == NSModalResponseOK || response == NSAlertFirstButtonReturn) {
		return inputField.stringValue;
	} else {
		return nil;
	}
}

- (NSString*)dropdownPrompt:(NSString*)prompt withInfo:(NSString*)info items:(NSArray*)items {
	NSAlert *alert = [self dialog:prompt withInfo:info];
	[alert addButtonWithTitle:@"OK"];
	[alert addButtonWithTitle:@"Cancel"];
	
	NSPopUpButton *popup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0,0, 300, 24)];
	
	[popup addItemWithTitle:@"Select..."];
	
	for (id item in items) {
		// Make sure the title becomes a string
		NSString *title = [NSString stringWithFormat:@"%@", item];
		[popup addItemWithTitle:title];
	}
	[alert setAccessoryView:popup];
	NSModalResponse response = [alert runModal];
	
	if (response == NSModalResponseOK || response == NSAlertFirstButtonReturn) {
		// Return an empty string if the user didn't select anything
		if ([popup.selectedItem.title isEqualToString:@"Select..."]) return @"";
		else return popup.selectedItem.title;
	} else {
		return nil;
	}
}

- (NSAlert*)dialog:(NSString*)title withInfo:(NSString*)info {
	if ([info isEqualToString:@"undefined"]) info = @"";

	NSAlert *alert = [[NSAlert alloc] init];
	alert.messageText = title;
	alert.informativeText = info;
	
	return alert;
}

- (void)setUserDefault:(NSString*)settingName setting:(id)value {
	if (!_pluginName) {
		[self alert:@"No plugin name" withText:@"You need to specify plugin name before trying to save settings."];
		return;
	}
	
	NSString *keyName = [NSString stringWithFormat:@"%@: %@", _pluginName, settingName];
	[[NSUserDefaults standardUserDefaults] setValue:value forKey:keyName];
}
- (id)getUserDefault:(NSString*)settingName {
	NSString *keyName = [NSString stringWithFormat:@"%@: %@", _pluginName, settingName];
	id value = [[NSUserDefaults standardUserDefaults] valueForKey:keyName];
	return value;
}

#pragma mark - HTML panel magic

- (void)htmlPanel:(NSString*)html width:(CGFloat)width height:(CGFloat)height callback:(JSValue*)callback {
	if (_delegate.thisWindow.attachedSheet) return;
	
	if (width <= 0) width = 600;
	if (width > 800) width = 1000;
	if (height <= 0) height = 400;
	if (height > 800) height = 1000;
	
	// Load template
	NSURL *templateURL = [NSBundle.mainBundle URLForResource:@"Plugin HTML template" withExtension:@"html"];
	NSString *template = [NSString stringWithContentsOfURL:templateURL encoding:NSUTF8StringEncoding error:nil];
	template = [template stringByReplacingOccurrencesOfString:@"<!-- CONTENT -->" withString:html];
	
	NSWindow *panel = [[NSWindow alloc] initWithContentRect:NSMakeRect(0,0, width, height + 35) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:YES];
	
	WKWebView *webView = [[WKWebView alloc] initWithFrame:NSMakeRect(0, 35, width, height)];
	[webView loadHTMLString:template baseURL:nil];
	[webView.configuration.userContentController addScriptMessageHandler:self name:@"sendData"];
	[webView.configuration.userContentController addScriptMessageHandler:self name:@"log"];
	[panel.contentView addSubview:webView];
	
	NSButton *okButton = [[NSButton alloc] initWithFrame:NSMakeRect(width - 90, 8, 90, 20)];
	okButton.bezelStyle = NSRoundedBezelStyle;
	[okButton setButtonType:NSMomentaryLightButton];
	[okButton setTarget:self];
	[okButton setAction:@selector(fetchHTMLPanelDataAndClose)];

	okButton.title = @"Close";
	[panel.contentView addSubview:okButton];
	
	_sheet = panel;
	_sheetWebView = webView;
	_sheetCallback = callback;
	
	[self.delegate.thisWindow beginSheet:panel completionHandler:^(NSModalResponse returnCode) {
		// Run callback here?
	}];
}
- (void)fetchHTMLPanelDataAndClose {
	[_sheetWebView evaluateJavaScript:@"sendBeatData();" completionHandler:nil];
	
	// The sheet will close automatically after that, but run an alert if the sheet didn't close in time
	// (for both the developer and the user to understand that something isn't working right)
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 2), dispatch_get_main_queue(), ^(void){
		if (self.delegate.thisWindow.attachedSheet == self.sheet && self.delegate.thisWindow.attachedSheet != nil) {
			[self alert:@"Plugin timed out" withText:@"Something went wrong with receiving data from the plugin"];
			[self closePanel:nil];
		}
	});
}
- (void)closePanel:(id)sender {
	if (self.delegate.thisWindow.attachedSheet) {
		[self.delegate.thisWindow endSheet:_sheet];
		_sheet = nil;
		_sheetWebView = nil;
	}
}
- (void)receiveDataFromHTMLPanel:(NSString*)json {
	// This method actually closes the HTML panel.
	// It is called by sending a message to the script parser via webkit message handler,
	// so this works asynchronously. Keep in mind.
	
	if ([json isEqualToString:@"(null)"]) json = @"";
	
	if (self.sheetCallback) {
		NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
		NSError *error;
		NSDictionary *jsonData = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
		
		if (!error) {
			[self closePanel:nil];
			[_sheetCallback callWithArguments:@[jsonData]];
		}
		else {
			[self closePanel:nil];
			[self alert:@"Error reading JSON data" withText:@"Plugin returned incompatible data and will terminate."];
		}
		
		_sheetCallback = nil;
	} else {
		[self closePanel:nil];
	}
}

#pragma mark - Parser data delegation

- (NSArray*)lines {
	return self.delegate.parser.lines;
}
- (NSArray*)linesForScene:(id)sceneId {
	NSMutableArray *lines = [NSMutableArray array];
	OutlineScene *scene = (OutlineScene*)sceneId;
	
	@try {
		NSRange sceneRange = NSMakeRange(scene.sceneStart, scene.sceneLength);
		
		for (Line* line in self.delegate.parser.lines) {
			if (NSLocationInRange(line.position, sceneRange)) [lines addObject:line];
		}
	}
	@catch (NSException *e) {
		[self alert:@"Scene index out of range" withText:@"Plugin tried to access an nonexistent scene"];
	}
	return lines;
}

- (NSArray*)scenes {
	return self.delegate.parser.scenes;
}
- (NSArray*)outline {
	return self.delegate.parser.outline;
}
- (void)parse {
	[self.delegate.parser createOutline];
	[self setJSData];
}
- (void)newDocument:(NSString*)string {
	if (string.length) [(ApplicationDelegate*)NSApp.delegate newDocumentWithContents:string];
	else [[NSDocumentController sharedDocumentController] newDocument:nil];
}

- (void)setJSData {
	[_context setObject:self.delegate.parser.lines forKeyedSubscript:@"Lines"];
	[_context setObject:self.delegate.parser.outline forKeyedSubscript:@"Outline"];
	[_context setObject:self.delegate.parser.scenes forKeyedSubscript:@"Scenes"];
}


- (void)userContentController:(nonnull WKUserContentController *)userContentController didReceiveScriptMessage:(nonnull WKScriptMessage *)message {
	if ([message.name isEqualToString:@"log"]) {
		[self log:message.body];
	}
	if ([message.name isEqualToString:@"sendData"]) {
		[self receiveDataFromHTMLPanel:message.body];
	}
}

@end
