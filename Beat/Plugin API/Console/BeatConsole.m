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

@interface BeatConsole ()
@property (nonatomic) IBOutlet NSTextView *consoleTextView;
@property (nonatomic) IBOutlet NSPopUpButton* contextSeletor;
@property (nonatomic) IBOutlet NSButton* wat;
@property (nonatomic) id<BeatEditorDelegate> currentContext;
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
		[self.window setFrame:NSMakeRect(0, 0, 450, 150) display:true];
		
		//[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(switchContext) name:NSWindowDidResignMainNotification object:nil];
		[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(switchContext:) name:@"Document changed" object:nil];
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
	NSPopUpButton* button = sender;
	
	//NSString* name = button.stringValue;
	NSInteger i = button.indexOfSelectedItem;
	if (i >= NSDocumentController.sharedDocumentController.documents.count || i != NSNotFound) {
		[button selectItem:nil];
		return;
	}
	
	id doc = NSDocumentController.sharedDocumentController.documents[i];
	self.currentContext = doc;
	
	
}

- (void)reloadContexts {
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
}

-(void)setCurrentContext:(id<BeatEditorDelegate>)currentContext
{
	_currentContext = currentContext;
	
	[self reloadContexts];
	[self loadBufferForContext:currentContext];
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

#pragma mark - Popup menu delegate

- (void)menuWillOpen:(NSMenu *)menu {
	[self reloadContexts];
}

@end
