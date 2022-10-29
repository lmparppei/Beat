//
//  NSDictionary+Values.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 7.8.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSDictionary (Values)

-(void)setBool:(BOOL)value key:(NSString*)key;
-(bool)boolFor:(NSString*)key;
-(void)setInt:(NSInteger)value key:(NSString*)key;
-(NSInteger)intFor:(NSString*)key;
-(void)setFloat:(CGFloat)value key:(NSString*)key;
-(CGFloat)floatFor:(NSString*)key;

@end

NS_ASSUME_NONNULL_END
