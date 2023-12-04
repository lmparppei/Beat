//
//  BeatDropdown.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 7.12.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatPluginUIDropdown.h"

@interface BeatPluginUIDropdown () <NSMenuDelegate>
@property (nonatomic) JSValue* jsAction;
@end

@implementation BeatPluginUIDropdown

+ (BeatPluginUIDropdown*)withItems:(NSArray<NSString*>*)items action:(id)action frame:(NSRect)frame {
	return [BeatPluginUIDropdown.alloc initWithItems:items action:action frame:frame];
}

- (instancetype)initWithItems:(NSArray<NSString*>*)items action:(id)action frame:(NSRect)frame {
	self = [super initWithFrame:frame];
		
	if (self) {
		if (items.count) [self addItemsWithTitles:items];
		self.target = self;
		self.action = @selector(runAction);
        self.menu.delegate = self;
		self.jsAction = action;
	}
	
	return self;
}

- (void)runAction {
	[_jsAction callWithArguments:@[ self.selectedItem.title ]];
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
}

- (void)remove {
	[self removeFromSuperview];
}


#pragma mark - Interfacing

- (NSArray<NSString*>*)items {
    NSMutableArray* items = NSMutableArray.new;
    for (NSMenuItem* item in self.itemArray) {
        [items addObject:item.title];
    }
    return items;
}
- (void)setItems:(NSArray<NSString*>*)items {
	[self removeAllItems];
    [self addItemsWithTitles:(items != nil) ? items : @[]];
}
- (void)addItem:(NSString*)item {
	[self addItemWithTitle:item];
}
- (NSString*)selected {
	return self.selectedItem.title;
}
-(NSInteger)selectedIndex {
    return [self.itemArray indexOfObject:self.selectedItem];
}

#pragma mark - Range protections

-(void)selectItemAtIndex:(NSInteger)index {
	if (index >= self.itemArray.count) return;
	[super selectItemAtIndex:index];
}

#pragma mark - Menu delegation

- (void)menuWillOpen:(NSMenu *)menu
{
    if (menu != self.menu) return;
    [self.onMenuOpen callWithArguments:nil];
}

@end
