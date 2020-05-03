//
//  LivePagination.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 1.5.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Line.h"

NS_ASSUME_NONNULL_BEGIN

@interface LivePagination : NSObject

@property (nonatomic) NSMutableArray *lines;
@property (nonatomic) CGSize paperSize;
@property (nonatomic) NSFont *font;
@property (nonatomic) CGFloat lineHeight;

- (NSArray*)paginate:(NSArray*)lines;

@end

NS_ASSUME_NONNULL_END
