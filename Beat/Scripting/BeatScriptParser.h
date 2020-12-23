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
- (void)log:(NSString*)string;
@end

@protocol BeatScriptingDelegate <NSObject>
//- (void):(NSInteger)index;
@property (strong, nonatomic) ContinousFountainParser *parser;
@end

@interface BeatScriptParser : NSObject <BeatScriptingExports>
@property (weak) id<BeatScriptingDelegate> delegate;

- (void)runScriptWithString:(NSString*)string;
- (void)log:(NSString*)string;

// For testing
@property NSArray *lines;


@end

NS_ASSUME_NONNULL_END
