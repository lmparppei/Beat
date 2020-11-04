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

@interface OutlineScene : NSObject
{
}
@property NSMutableArray * scenes;
@property (strong, nonatomic) NSString * string;
@property LineType type;
@property NSString * sceneNumber;
@property NSString * color;
@property NSArray * storylines;
@property NSUInteger sceneStart;
@property NSUInteger sceneLength;
@property NSInteger sectionDepth;

@property bool omited;
@property bool noOmitIn;
@property bool noOmitOut;

@property (strong) Line * line; // Is this overkill regarding memory? Isn't this just a pointer?

- (NSRange)range;

@end
