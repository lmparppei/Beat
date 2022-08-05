//
//  BeatPaginationSizing.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 24.7.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BeatPaginationSizing : NSObject

@property (nonatomic) NSInteger actionA4;
@property (nonatomic) NSInteger actionUS;
@property (nonatomic) NSInteger character;
@property (nonatomic) NSInteger parenthetical;
@property (nonatomic) NSInteger dialogue;

@property (nonatomic) NSInteger dualDialogueA4;
@property (nonatomic) NSInteger dualDialogueUS;
@property (nonatomic) NSInteger dualDialogueCharacterA4;
@property (nonatomic) NSInteger dualDialogueCharacterUS;
@property (nonatomic) NSInteger dualDialogueParentheticalA4;
@property (nonatomic) NSInteger dualDialogueParentheticalUS;

- (void)setWidth:(NSString*)key as:(NSInteger)value;

@end

NS_ASSUME_NONNULL_END
