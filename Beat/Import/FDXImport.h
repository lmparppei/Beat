//
//  FDXImport.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 8.1.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FDXImport : NSObject

@property(nonatomic, strong) NSMutableArray *results;
@property(nonatomic, strong) NSMutableString *parsedString;
@property(nonatomic, strong) NSMutableString *resultScript;

@property(nonatomic, strong) NSMutableArray *script;
@property(nonatomic, strong) NSMutableArray *attrScript;

- (id)initWithURL:(NSURL*)url completion:(void(^)(void))callback;
- (NSString*)scriptAsString;

@end
