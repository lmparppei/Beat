//
//  OutlineScene.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 18.2.2019.
//  Copyright © 2019 KAPITAN!. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ContinuousFountainParser.h"
#import "Line.h"
#import <JavaScriptCore/JavaScriptCore.h>

// JavaScript interface
@protocol OutlineSceneExports <JSExport>
@property (nonatomic, readonly) NSString * sceneNumber;
@property (nonatomic, readonly) NSString * color;
@property (nonatomic, readonly) Line * line;
@property (strong, nonatomic, readonly) NSString * string;
@property (nonatomic, readonly) NSString * stringForDisplay;
@property (nonatomic, readonly) NSArray * storylines;
@property (nonatomic, readonly) NSUInteger sceneStart;

@property (nonatomic, readonly) NSUInteger position;
@property (nonatomic, readonly) NSUInteger length;
@property (nonatomic, readonly) NSUInteger printedLength;
@property (nonatomic, readonly) NSUInteger sceneLength; // backwards compatibility
@property (nonatomic, readonly) NSInteger sectionDepth; // backwards compatibility

@property (nonatomic, readonly) bool omitted;
@property (nonatomic, readonly) bool omited; // Legacy compatibility
@property (nonatomic, readonly) NSUInteger omissionStartsAt;
@property (nonatomic, readonly) NSUInteger omissionEndsAt;

@property (nonatomic, readonly) NSMutableArray * characters;
- (NSString*)typeAsString;
- (NSInteger)timeLength;
- (NSDictionary*)forSerialization;
@end

@interface OutlineScene : NSObject <OutlineSceneExports>
+ (OutlineScene*)withLine:(Line*)line;

@property (nonatomic) id<LineDelegate> delegate;
@property (nonatomic) NSMutableArray * scenes;
@property (strong, nonatomic) NSString * string;
@property (nonatomic) LineType type;
@property (nonatomic) NSString * sceneNumber;
@property (nonatomic, readonly) NSString * color;
@property (nonatomic) NSArray * storylines;

@property (nonatomic, readonly) NSUInteger position;
@property (nonatomic) NSUInteger length;
@property (nonatomic) NSUInteger printedLength;
@property (nonatomic, readonly) NSUInteger sceneStart;  // backwards compatibility
@property (nonatomic, readonly) NSUInteger sceneLength;  // backwards compatibility

@property (nonatomic) NSUInteger omissionStartsAt;
@property (nonatomic) NSUInteger omissionEndsAt;

@property (nonatomic) NSInteger sectionDepth;
@property (nonatomic) NSMutableArray * characters;

@property (nonatomic) bool omitted;

@property (nonatomic, weak) Line * line;

- (NSString*)stringForDisplay;
- (NSRange)range;
- (NSInteger)timeLength;
- (NSString*)typeAsString;
- (NSDictionary*)forSerialization;
@end
