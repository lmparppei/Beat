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

@property(nonatomic) bool contentFound;
@property(nonatomic) bool titlePage;
@property(nonatomic, strong) NSString *lastFoundElement;
@property(nonatomic, strong) NSString *lastFoundString;
@property(nonatomic, strong) NSString *lastAddedLine;
@property(nonatomic, strong) NSString *activeElement;
@property(nonatomic, strong) NSString *alignment;
@property(nonatomic, strong) NSString *style;
@property(nonatomic, strong) NSMutableString *elementText;
@property(nonatomic, strong) NSMutableArray *script;
@property(nonatomic) NSUInteger dualDialogue;

- (id)initWithURL:(NSURL*)url completion:(void(^)(void))callback;
- (NSString*)scriptAsString;

@end
