//
//  BeatModalItem.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 7.8.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatModalAccessoryView.h"
#import "BeatConsole.h"

#define WIDTH 350

@interface BeatModalAccessoryView ()
#if !TARGET_OS_IOS
@property (nonatomic) NSMutableArray *items;
@property (nonatomic, weak) NSView *lastField;
#endif
@end

@implementation BeatModalAccessoryView
#if !TARGET_OS_IOS
- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    // Drawing code here.
}

-(BOOL)isFlipped { return YES; }

- (void)addView:(NSView *)view {
	CGFloat y = 0;
	if (_items == nil) _items = [NSMutableArray array];
	if (_items.lastObject) {
		NSView *previousView = (NSView*)_items.lastObject;
		y = previousView.frame.origin.y + previousView.frame.size.height + 5;
	}
	
	NSRect frame = view.frame;
	frame.origin.y = y;
	[view setFrame:frame];
	
	[_items addObject:view];
	[super addSubview:view];
}
- (void)addField:(NSDictionary*)item {
	if (_fields == nil) _fields = [NSMutableDictionary dictionary];
	
	NSString *type = item[@"type"];
	NSString *name = item[@"name"];
	NSString *labelText = (item[@"label"]) ? item[@"label"] : @"";
	
	NSView *view = [[NSView alloc] init];
	CGFloat height = 0;
	
	NSView *field;
	
	if ([type isEqualToString:@"text"]) {
		NSTextField *label = [self label:labelText];
		[view addSubview:label];
		
		NSString *placeholder = (item[@"placeholder"]) ? item[@"placeholder"] : @"";
		NSRect frame = NSMakeRect(90, 0, 250, 24);
		NSTextField *inputField = [[NSTextField alloc] initWithFrame:frame];
		inputField.placeholderString = placeholder;
		
		height = 24;
		
		field = inputField;
		[view addSubview:inputField];
		
		if (name) [_fields setValue:inputField forKey:name];
	}
	else if ([type isEqualToString:@"dropdown"]) {
		NSTextField *label = [self label:labelText];
		[view addSubview:label];
		
		NSPopUpButton *popup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(90,0, 250, 24)];
		NSArray<NSString*> *dropdownItems = item[@"items"];
		if (dropdownItems.count) [popup addItemsWithTitles:dropdownItems];
		
		field = popup;
		[view addSubview:popup];
		
		height = 24;
		
		if (name) [_fields setValue:popup forKey:name];
	}
	else if ([type isEqualToString:@"space"]) {
		height = 10;
	}
	else if ([type isEqualToString:@"checkbox"]) {
		NSTextField *label = [self label:labelText];
		NSRect labelRect = label.frame;
		label.alignment = NSTextAlignmentLeft;
		labelRect.origin.x = 90;
		labelRect.origin.y = 0;
		labelRect.size.width = 250;
		labelRect.size.height = 18;
		label.frame = labelRect;
		[view addSubview:label];
		
		NSButton *checkbox = [[NSButton alloc] initWithFrame:(NSRect){ 80 - 18, 0, 18, 18 }];
		[checkbox setButtonType:NSSwitchButton];
		field = checkbox;
		[view addSubview:checkbox];
		
		height = 18;
		
		if (name) [_fields setValue:checkbox forKey:name];
	} else {
		[BeatConsole.shared logToConsole:[NSString stringWithFormat:@"'%@' is not a valid modal type. Ignoring.", type] pluginName:@"NOTE:" context:nil];
		return;
	}
	
	// Chain inputs together
	if (field) {
		[_lastField setNextKeyView:field];
		_lastField = field;
	}
	
	// Add view into accessory view
	NSRect frame = (NSRect){ 0,0, 340, height };
	view.frame = frame;
	[self addView:view];
}

- (CGFloat)heightForItems {
	NSView *lastView = (NSView*)_items.lastObject;
	return lastView.frame.origin.y + lastView.frame.size.height;
}

- (NSTextField*)label:(NSString*)labelText {
	NSTextField *label = [[NSTextField alloc] initWithFrame:(NSRect){ 0, 0, 80, 18 }];
	label.font = [NSFont systemFontOfSize:NSFont.smallSystemFontSize];
	label.editable = NO;
	label.selectable = NO;
	label.drawsBackground = NO;
	label.stringValue = labelText;
	label.bordered = NO;
	label.alignment = NSTextAlignmentRight;
	return label;
}

- (NSDictionary*)valuesForFields {
	NSMutableDictionary *result = [NSMutableDictionary dictionary];
	for (NSString* name in _fields.allKeys) {
		id item = _fields[name];
		
		if ([item isKindOfClass:NSTextField.class]) {
			[result setValue:[(NSTextField*)item stringValue] forKey:name];
		}
		else if ([item isKindOfClass:NSPopUpButton.class]) {
			[result setValue:[(NSPopUpButton*)item selectedItem].title forKey:name];
		}
		else if ([item isKindOfClass:NSButton.class]) {
			NSButton *checkbox = item;
			if (checkbox.state == NSOnState) [result setValue:@(true) forKey:name];
			else [result setValue:@(false) forKey:name];
		}
	}
	
	return result;
}
#endif

@end
