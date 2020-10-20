//
//  BeatScriptParser.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 1.7.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ContinousFountainParser.h"

NS_ASSUME_NONNULL_BEGIN

@protocol BeatScriptingExports <JSExport>
- (NSMutableArray*)scenes;
@end

@protocol BeatScriptingDelegate <NSObject>
//- (void):(NSInteger)index;
@property (strong, nonatomic) ContinousFountainParser *parser;
@end

@interface BeatScriptParser : NSObject <BeatScriptingExports>
@property (weak) id<BeatScriptingDelegate> delegate;
@end

NS_ASSUME_NONNULL_END
