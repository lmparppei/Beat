//
//  BeatScriptParser.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 1.7.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol BeatScriptDelegate <NSObject>
//- (void):(NSInteger)index;
@end

@interface BeatScriptParser : NSScriptCommand

@end

NS_ASSUME_NONNULL_END
