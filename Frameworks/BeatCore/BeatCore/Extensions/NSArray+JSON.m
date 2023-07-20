//
//  NSArray+JSON.m
//  BeatCore
//
//  Created by Lauri-Matti Parppei on 20.7.2023.
//

#import "NSArray+JSON.h"

@implementation NSArray (JSON)

-(NSString*)json
{
    NSError *error;
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:self options:0 error:&error];
    NSString *json = [NSString.alloc initWithData:jsonData encoding:NSUTF8StringEncoding];
    
    if (error) NSLog(@"JSON error: %@", error);
    
    return json;
}

@end
