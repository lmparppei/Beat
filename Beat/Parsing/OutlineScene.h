//
//  OutlineScene.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 18.2.2019.
//  Copyright © 2019 KAPITAN!. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ContinousFountainParser.h"
#import "Line.h"
#import <JavaScriptCore/JavaScriptCore.h>

// JavaScript interface
@protocol OutlineSceneExports <JSExport>
@property (nonatomic) NSString * sceneNumber;
@property (nonatomic) NSString * color;
@property (nonatomic) Line * line;
@property (strong, nonatomic) NSString * string;
@property (nonatomic) NSArray * storylines;
@property (nonatomic) NSUInteger sceneStart;
@property (nonatomic) NSUInteger sceneLength;
@property (nonatomic) NSInteger sectionDepth;
@property (nonatomic) bool omited;
@property (nonatomic) NSMutableArray * characters;
- (NSString*)typeAsString;
- (NSInteger)timeLength;
@end

@interface OutlineScene : NSObject <OutlineSceneExports>
@property (nonatomic) NSMutableArray * scenes;
@property (strong, nonatomic) NSString * string;
@property (nonatomic) LineType type;
@property (nonatomic) NSString * sceneNumber;
@property (nonatomic) NSString * color;
@property (nonatomic) NSArray * storylines;
@property (nonatomic) NSUInteger sceneStart;
@property (nonatomic) NSUInteger sceneLength;
@property (nonatomic) NSInteger sectionDepth;
@property (nonatomic) NSMutableArray * characters;

@property (nonatomic) bool omited;
@property (nonatomic) bool noOmitIn;
@property (nonatomic) bool noOmitOut;

@property (nonatomic) Line * line; // Is this overkill regarding memory? Isn't this just a pointer?

- (NSString*)stringForDisplay;
- (NSRange)range;
- (NSInteger)timeLength;
- (NSString*)typeAsString;
@end
