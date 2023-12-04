//
//  BeatConsole.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 25.7.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//
/**
 
 The console is a singleton, which can be opened from any document.
 
 Each context (document) has its own log. Whenever an editor context is accessed via the console, a one-line plugin is created.
 The plugin, called `Console` acts as a bridge between the console and the document, allowing access to a `JSContext`
 attached to the editor context. Console is strictly used for plugin/extension development, and it doesn't have to access  the editor directly.
 
 This means that you can't use the console without a context. It's very possible to crash the bridging plugin from within the console,
 causing the link to disappear. You probably can crash Beat too.
 
 */

#import "BeatConsole.h"
#import <os/log.h>
#import <BeatCore/BeatCore.h>
#import <BeatPlugins/BeatPlugin.h>
#import <BeatPlugins/BeatPluginAgent.h>

#define ConsolePluginName @"Console"

@interface BeatConsole ()
#if !TARGET_OS_IOS
@property (nonatomic) IBOutlet NSTextView *consoleTextView;
@property (nonatomic) IBOutlet NSPopUpButton* contextSeletor;
#endif

@property (nonatomic, weak) id<BeatEditorDelegate> currentContext;
@property (nonatomic) NSMutableDictionary<NSString*, NSMutableAttributedString*>* logs;

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
#if TARGET_OS_IOS
    self = [super initWithNibName:nil bundle:nil];
    return self;
#else
	self = [super initWithWindowNibName:self.className owner:self];

	if (self) {
		self.logs = NSMutableDictionary.new;
		self.currentContext = NSDocumentController.sharedDocumentController.currentDocument;
		
		[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(switchContext:) name:@"Document changed" object:nil];
        
        // Oh well. We need to do this in main thread, if the console was opened from another thread.
        dispatch_async(dispatch_get_main_queue(), ^{
            self.window.minSize = NSMakeSize(300, 100);
            [self updateTitle];
        });
	}
	
    return self;
#endif
}

-(void)switchContext:(NSNotification*)notification
{
	id doc = notification.object;
	if (self.currentContext != doc) self.currentContext = doc;
}

-(void)awakeFromNib
{
    [super awakeFromNib];
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
#if !TARGET_OS_IOS
	[self.window makeKeyAndOrderFront:nil];
#endif
}

-(void)logToConsole:(NSString*)string pluginName:(NSString*)pluginName context:(id<BeatEditorDelegate> _Nullable)context
{
#if !TARGET_OS_IOS
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
#endif
}

- (void)logMessage:(NSAttributedString*)message context:(id<BeatEditorDelegate> _Nullable)context
{
#if !TARGET_OS_IOS
	// Store to context if set
	if (context != nil) {
		if (_logs[context.uuid.UUIDString] == nil) _logs[context.uuid.UUIDString] = NSMutableAttributedString.new;
		[_logs[context.uuid.UUIDString] appendAttributedString:message];
	}
	
	if (_currentContext == context || context == nil) {
		[self.consoleTextView.textStorage appendAttributedString:message];
		[self.consoleTextView.layoutManager ensureLayoutForTextContainer:self.consoleTextView.textContainer];
		self.consoleTextView.frame = [self.consoleTextView.layoutManager usedRectForTextContainer:self.consoleTextView.textContainer];
		
		[self scrollToEnd];
	}
#endif
}

- (void)logError:(id)error context:(id)context {
	[self logError:error context:context pluginName:@""];
}
- (void)logError:(id)error context:(id)context pluginName:(NSString*)name
{
    NSLog(@"ERROR: %@: %@", name, error);
    
#if !TARGET_OS_IOS
	if (context == nil) context = _currentContext;
	
	NSFont* font;
	if (@available(macOS 10.15, *)) {
		font = [NSFont monospacedSystemFontOfSize:10.0 weight:NSFontWeightBold];
	} else {
		font = [NSFont systemFontOfSize:10.0];
	}
	
	if (name.length > 0) name = [NSString stringWithFormat:@"%@: ", name];
	else name = @"";
	
    NSMutableAttributedString* msg = NSMutableAttributedString.new;
	[msg appendAttributedString: [NSAttributedString.alloc initWithString:[NSString stringWithFormat:@"%@", name] attributes:@{
		NSForegroundColorAttributeName: NSColor.redColor, NSFontAttributeName: font
	}]];
    [msg appendAttributedString: [NSAttributedString.alloc initWithString:[NSString stringWithFormat:@"%@\n", error] attributes:@{
        NSForegroundColorAttributeName: NSColor.textColor, NSFontAttributeName: font
    }]];
    
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            [self logMessage:msg context:context];
        });
    } else {
        [self logMessage:msg context:context];
    }
#endif
}

-(void)scrollToEnd
{
#if !TARGET_OS_IOS
	NSClipView *clipView = self.consoleTextView.enclosingScrollView.contentView;
	CGFloat scrollTo = self.consoleTextView.frame.size.height - clipView.frame.size.height;

	[clipView setBoundsOrigin:NSMakePoint(0, scrollTo)];
#endif
}

-(IBAction)clearConsole:(id)sender {
	[self clearConsole];
}

-(void)clearConsole
{
#if !TARGET_OS_IOS
	if (self.window == nil) return;
	
	[_consoleTextView.textStorage replaceCharactersInRange:(NSRange){0, _consoleTextView.string.length} withString:@""];
	
	if (_logs[_currentContext.uuid.UUIDString] != nil) {
		_logs[_currentContext.uuid.UUIDString] = NSMutableAttributedString.new;
	}
#endif
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
    
    if (NSThread.isMainThread) {
        [self loadBufferForContext:currentContext];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self loadBufferForContext:currentContext];
        });
    }
	
	
	// Create a plugin interface if needed
	if (currentContext.runningPlugins[ConsolePluginName] == nil) {
		[self createConsolePlugin];
	}
	
	[self updateTitle];
}

- (void)updateTitle {
#if !TARGET_OS_IOS
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString* title = (self.currentContext.fileNameString != nil) ? self.currentContext.fileNameString : @"Untitled";
        self.window.title = [NSString stringWithFormat:@"Console — %@", title];
    });
#endif
}

- (void)createConsolePlugin {
	[_currentContext.pluginAgent loadPluginWithName:ConsolePluginName script:[self consolePlugin]];
	
	BeatPlugin* plugin = self.currentContext.runningPlugins[ConsolePluginName];
	[plugin replaceErrorHandler:^(JSValue *exception) {
		[self logError:exception context:nil];
	}];
}


-(NSString*)consolePlugin {
	return @"Beat.makeResident()";
}

-(void)loadBufferForContext:(id<BeatEditorDelegate>)context {
#if !TARGET_OS_IOS
	NSMutableAttributedString* log;
	if (self.logs[_currentContext.uuid.UUIDString] != nil) {
		log = self.logs[_currentContext.uuid.UUIDString];
	} else {
		log = NSMutableAttributedString.new;
	}

	_consoleTextView.string = @"";
		
	[_consoleTextView.textStorage replaceCharactersInRange:(NSRange){0, _consoleTextView.string.length} withAttributedString:log];
	[_consoleTextView.layoutManager ensureLayoutForTextContainer:_consoleTextView.textContainer];
	[self scrollToEnd];
#endif
}

#pragma mark - Console execution

- (IBAction)runCommand:(id)sender {
#if !TARGET_OS_IOS
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
#endif
}

- (NSArray*)consoleCommands {
	static NSArray* commands;
	if (commands == nil) commands = @[@"help", @"close"];
	
	return commands;
}

#pragma mark - Popup menu delegate

#if !TARGET_OS_IOS
- (void)menuWillOpen:(NSMenu *)menu {
	[self reloadContexts];
}
#endif

@end
