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
@property (strong) Line * line; // Is this overkill regarding memory?
@end
