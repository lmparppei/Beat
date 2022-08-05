//
//  RenderStyleReader.h
//  PrintLayoutTests
//
//  Created by Lauri-Matti Parppei on 7.7.2021.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class RenderStyle;
@interface RenderStyles : NSObject
@property (nonatomic) NSDictionary<NSString*, RenderStyle*>* styles;
+ (RenderStyles*)shared;
- (RenderStyle*)forElement:(NSString*)name;
- (RenderStyle*)page;
@end

NS_ASSUME_NONNULL_END
