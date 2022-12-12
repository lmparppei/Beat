//
//  BeatPaginationElements.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 11.12.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <BeatParsing/BeatParsing.h>

NS_ASSUME_NONNULL_BEGIN

@class Line;

@interface BeatPaginationView : NSObject

@end

@interface BeatPaginationBlock:NSObject
@property (nonatomic) NSMutableArray<Line*>* lines;
@end


NS_ASSUME_NONNULL_END
