//
//  BeatDropdown.m
//  Beat
//
//  Created by Lauri-Matti Parppei on 7.12.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import "BeatPluginUIDropdown.h"

@interface BeatPluginUIDropdown ()
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
		self.jsAction = action;
	}
	
	return self;
}

- (void)runAction {
	[_jsAction callWithArguments:@[ self.selectedItem.title ]];
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    // Drawing code here.
}

- (void)remove {
	[self removeFromSuperview];
}


#pragma mark - Interfacing

- (NSArray*)items {
	return self.itemArray;
}
- (void)setItems:(NSArray * _Nonnull)items {
	[self removeAllItems];
	[self addItemsWithTitles:items];
}
- (void)addItem:(NSString*)item {
	[self addItemWithTitle:item];
}
- (NSString*)selected {
	return self.selectedItem.title;
}

#pragma mark - Range protections

-(void)selectItemAtIndex:(NSInteger)index {
	if (index >= self.itemArray.count) return;
	[super selectItemAtIndex:index];
	
}

@end
