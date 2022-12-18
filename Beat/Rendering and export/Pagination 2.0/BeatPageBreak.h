//
//  BeatPageBreak.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 18.12.2022.
//  Copyright © 2022 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@class Line;

@interface BeatPageBreak : NSObject
@property (nonatomic) CGFloat y;
@property (nonatomic) Line* element;
@property (nonatomic) NSString* reason;
-(instancetype)initWithY:(CGFloat)y element:(Line*)line reason:(NSString*)reason;
-(instancetype)initWithY:(CGFloat)y element:(Line*)line;
@end

NS_ASSUME_NONNULL_END
