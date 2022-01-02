//
//  MenuItem.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 7.3.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ValidationItem : NSObject
@property (nonatomic) NSString *title;
@property (nonatomic) SEL selector;
@property (nonatomic) NSInteger tab;
@property (nonatomic) NSString* setting;
@property (weak) id target;
+ (ValidationItem*)newItem:(NSString*)title setting:(NSString*)setting target:(id)target; // Legacy, deprecated
+ (ValidationItem*)withAction:(SEL)selector setting:(NSString*)setting target:(id)target;
- (bool)validate;
@end

NS_ASSUME_NONNULL_END
