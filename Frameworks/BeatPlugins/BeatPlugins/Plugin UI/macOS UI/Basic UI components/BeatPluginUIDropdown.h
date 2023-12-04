//
//  BeatDropdown.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 7.12.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import <BeatPlugins/BeatPluginUIExports.h>

NS_ASSUME_NONNULL_BEGIN

@protocol BeatDropdownExports <JSExport>
@property (nonatomic) NSArray<NSString*>* items;
@property (nonatomic, readonly) NSString *selected;
@property (nonatomic) bool enabled;
@property (nonatomic, readonly) NSInteger selectedIndex;
@property (nonatomic) JSValue* onMenuOpen;

- (void)selectItemWithTitle:(NSString *)title;
- (void)selectItemAtIndex:(NSInteger)index;
- (void)setItems:(NSArray<NSString*>*)items;
- (void)addItem:(NSString*)item;
@end

@interface BeatPluginUIDropdown : NSPopUpButton <BeatDropdownExports, BeatPluginUIExports>
@property (nonatomic) NSArray<NSString*>* items;
@property (nonatomic, readonly) NSString *selected;
@property (nonatomic) JSValue* onMenuOpen;

+ (BeatPluginUIDropdown*)withItems:(NSArray<NSString*>*)items action:(id)action frame:(NSRect)frame;
@end

NS_ASSUME_NONNULL_END
