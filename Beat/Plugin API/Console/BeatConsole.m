//
//  BeatConsole.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 25.7.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatConsole.h"
#import <os/log.h>
#import <BeatCore/BeatCore.h>
#import "BeatPlugin.h"

#define ConsolePluginName @"Console"

@interface BeatConsole ()
@property (nonatomic) IBOutlet NSTextView *consoleTextView;
@property (nonatomic) IBOutlet NSPopUpButton* contextSeletor;
@property (nonatomic) IBOutlet NSButton* wat;
@property (nonatomic, weak) id<BeatEditorDelegate> currentContext;
@property (nonatomic) NSMutableDictionary<NSUUID*, NSMutableAttributedString*>* logs;
@end

@implementation BeatConsole

+ (BeatConsole*)shared
{
	static BeatConsole* console;
	if (!console) {
		console = BeatConsole.new;
	}
	return console;
}

- (instancetype)init
{
	self = [super initWithWindowNibName:self.className owner:self];

	if (self) {
		self.logs = NSMutableDictionary.new;
		self.currentContext = NSDocumentController.sharedDocumentController.currentDocument;
		
		self.window.title = @"";
		//[self.window setFrame:NSMakeRect(0, 0, 450, 150) display:true];
		self.window.minSize = NSMakeSize(300, 100);
		
		[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(switchContext:) name:@"Document changed" object:nil];
		[self updateTitle];
	}
	
	return self;
}

-(void)switchContext:(NSNotification*)notification
{
	id doc = notification.object;
	if (self.currentContext != doc) self.currentContext = doc;
}

-(void)awakeFromNib
{
	[self reloadContexts];
	[self updateTitle];
}

-(void)openConsole
{
	if (!NSThread.isMainThread) {
		dispatch_async(dispatch_get_main_queue(), ^(void) {
			[self createAndOpenConsoleWindow];
		});
	} else {
		[self createAndOpenConsoleWindow];
	}
}

-(void)createAndOpenConsoleWindow
{
	[self.window makeKeyAndOrderFront:nil];
}

-(void)logToConsole:(NSString*)string pluginName:(NSString*)pluginName context:(id<BeatEditorDelegate> _Nullable)context
{
	if (self.window == nil) return;
	
	os_log(OS_LOG_DEFAULT, "[plugin] %@: %@", pluginName, string);
	
	NSAttributedString* name;
	if (pluginName.length > 0) {
		name = [NSAttributedString.alloc initWithString:[NSString stringWithFormat:@"%@: ", pluginName] attributes:@{ NSForegroundColorAttributeName: NSColor.secondaryLabelColor }];
	} else {
		name = NSAttributedString.new;
	}
	
	string = [string stringByAppendingString:@"\n"];
	NSAttributedString* message = [NSAttributedString.alloc initWithString:string attributes:@{ NSForegroundColorAttributeName: NSColor.whiteColor }];
	
	NSMutableAttributedString* result = NSMutableAttributedString.new;
	[result appendAttributedString:name];
	[result appendAttributedString:message];
	
	if (@available(macOS 10.15, *)) {
		[result addAttribute:NSFontAttributeName value:[NSFont monospacedSystemFontOfSize:10.0 weight:NSFontWeightRegular] range:NSMakeRange(0, result.length)];
	}
	
	// Ensure main thread
	if (!NSThread.isMainThread) {
		dispatch_async(dispatch_get_main_queue(), ^(void) {
			[self logMessage:result context:context];
		});
	} else {
		[self logMessage:result context:context];
	}
}

- (void)logMessage:(NSAttributedString*)message context:(id<BeatEditorDelegate> _Nullable)context
{
	// Store to context if set
	if (context != nil) {
		if (_logs[context.uuid] == nil) _logs[context.uuid] = NSMutableAttributedString.new;
		[_logs[context.uuid] appendAttributedString:message];
	}
	
	if (_currentContext == context || context == nil) {
		[self.consoleTextView.textStorage appendAttributedString:message];
		[self.consoleTextView.layoutManager ensureLayoutForTextContainer:self.consoleTextView.textContainer];
		self.consoleTextView.frame = [self.consoleTextView.layoutManager usedRectForTextContainer:self.consoleTextView.textContainer];
		
		[self scrollToEnd];
	}
}

- (void)logError:(id)error context:(id)context {
	[self logError:error context:context pluginName:@""];
}
- (void)logError:(id)error context:(id)context pluginName:(NSString*)name
{
	if (context == nil) context = _currentContext;
	
	NSFont* font;
	if (@available(macOS 10.15, *)) {
		font = [NSFont monospacedSystemFontOfSize:10.0 weight:NSFontWeightBold];
	} else {
		font = [NSFont systemFontOfSize:10.0];
	}
	
	if (name.length > 0) name = [NSString stringWithFormat:@"%@: ", name];
	else name = @"";
	
	NSAttributedString* string = [NSAttributedString.alloc initWithString:[NSString stringWithFormat:@"%@%@\n", name, error] attributes:@{
		NSForegroundColorAttributeName: NSColor.redColor,
		NSFontAttributeName: font
	}];
	[self logMessage:string context:context];
}

-(void)scrollToEnd
{
	NSClipView *clipView = self.consoleTextView.enclosingScrollView.contentView;
	CGFloat scrollTo = self.consoleTextView.frame.size.height - clipView.frame.size.height;

	[clipView setBoundsOrigin:NSMakePoint(0, scrollTo)];
}

-(IBAction)clearConsole:(id)sender {
	[self clearConsole];
}

-(void)clearConsole
{
	if (self.window == nil) return;
	
	[_consoleTextView.textStorage replaceCharactersInRange:(NSRange){0, _consoleTextView.string.length} withString:@""];
	
	if (_logs[_currentContext.uuid] != nil) {
		_logs[_currentContext.uuid] = NSMutableAttributedString.new;
	}
}

- (IBAction)selectContext:(id)sender {
	/*
	NSPopUpButton* button = sender;
	
	NSInteger i = button.indexOfSelectedItem;
	if (i >= NSDocumentController.sharedDocumentController.documents.count || i != NSNotFound) {
		[button selectItem:nil];
		return;
	}
	
	id doc = NSDocumentController.sharedDocumentController.documents[i];
	self.currentContext = doc;
	*/
}

- (void)reloadContexts {
	return;
	/*
	// Let's not allow the user to select context for now.
	 
	[_contextSeletor removeAllItems];
	NSMenuItem* selected;
	
	for (id<BeatEditorDelegate> doc in NSDocumentController.sharedDocumentController.documents) {
		NSString* name = doc.fileNameString;
		
		if ([_contextSeletor.itemTitles containsObject:doc.fileNameString]) {
			name = [NSString stringWithFormat:@"%@ (%@)", name, doc.uuid];
		}
		[_contextSeletor addItemWithTitle:name];
		
		if (doc == _currentContext) {
			_contextSeletor.itemArray.lastObject.state = NSOnState;
			selected = _contextSeletor.itemArray.lastObject;
		}
	}
	
	[_contextSeletor selectItem:selected];
	 */
}

-(void)setCurrentContext:(id<BeatEditorDelegate>)currentContext
{
	_currentContext = currentContext;
	
	[self reloadContexts];
	[self loadBufferForContext:currentContext];
	
	
	// Create a plugin interface if needed
	if (currentContext.runningPlugins[ConsolePluginName] == nil) {
		[self createConsolePlugin];
	}
	
	[self updateTitle];
}

- (void)updateTitle {
	NSString* title = (_currentContext.fileNameString != nil) ? _currentContext.fileNameString : @"Untitled";
	self.window.title = [NSString stringWithFormat:@"Console — %@", title];
}

- (void)createConsolePlugin {
	[_currentContext loadPluginWithName:ConsolePluginName script:[self consolePlugin]];
	
	BeatPlugin* plugin = self.currentContext.runningPlugins[ConsolePluginName];
	[plugin replaceErrorHandler:^(JSValue *exception) {
		[self logError:exception context:nil];
	}];
}


-(NSString*)consolePlugin {
	return @"Beat.makeResident()";
}

-(void)loadBufferForContext:(id<BeatEditorDelegate>)context {
	NSMutableAttributedString* log;
	if (self.logs[_currentContext.uuid] != nil) {
		log = self.logs[_currentContext.uuid];
	} else {
		log = NSMutableAttributedString.new;
	}

	_consoleTextView.string = @"";
		
	[_consoleTextView.textStorage replaceCharactersInRange:(NSRange){0, _consoleTextView.string.length} withAttributedString:log];
	[_consoleTextView.layoutManager ensureLayoutForTextContainer:_consoleTextView.textContainer];
	[self scrollToEnd];
}

#pragma mark - Console execution

- (IBAction)runCommand:(id)sender {
	NSTextField* textField = sender;
	NSString* script = textField.stringValue.copy;
	textField.stringValue = @"";
		
	NSFont* font;
	if (@available(macOS 10.15, *)) {
		font = [NSFont monospacedSystemFontOfSize:10.0 weight:NSFontWeightRegular];
	} else {
		font = [NSFont systemFontOfSize:10.0];
	}
	
	NSString* feedback = [NSString stringWithFormat:@"> %@\n", script];
	NSMutableAttributedString* message = [NSAttributedString.alloc initWithString:feedback attributes:@{
		NSForegroundColorAttributeName: NSColor.tertiaryLabelColor,
		NSFontAttributeName: font
	}].mutableCopy;
	[self logMessage:message context:self.currentContext];
	
	// Don't do anything if no document is open.
	if (_currentContext == nil) {
		[self logToConsole:@"Error: No document open." pluginName:@"" context:nil];
		return;
	}
	
	BeatPlugin* plugin = self.currentContext.runningPlugins[ConsolePluginName];
	JSValue* value = [plugin call:script];
	
	if (!value.isUndefined && !value.isNull) {
		NSString* r = [NSString stringWithFormat:@"< %@\n", value];
		NSAttributedString* result = [NSAttributedString.alloc initWithString:r attributes:@{
			NSForegroundColorAttributeName: NSColor.whiteColor,
			NSFontAttributeName: font
		}];
		
		[self logMessage:result context:self.currentContext];
	}
	
}

#pragma mark - Popup menu delegate

- (void)menuWillOpen:(NSMenu *)menu {
	[self reloadContexts];
}

@end
