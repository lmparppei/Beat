//
//  BeatDocumentSettings+Shorthands.m
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 8.11.2024.
//

#import <BeatParsing/BeatDocumentSettings.h>
#import "BeatDocumentSettings+Shorthands.h"

@implementation BeatDocumentSettings (Shorthands)

- (void)setRevisionLevel:(NSInteger)level { [self setInt:DocSettingRevisionLevel as:level]; }
- (NSInteger)revisionLevel { return [self getInt:DocSettingRevisionLevel]; }

- (void)setRevisionMode:(NSInteger)mode { [self setInt:DocSettingRevisionMode as:mode]; }
- (NSInteger)revisionMode { return [self getInt:DocSettingRevisionMode]; }

- (void)setPrintSceneNumbers:(bool)print { [self setBool:DocSettingPrintSceneNumbers as:print]; }
- (bool)printSceneNumbers { return [self getBool:DocSettingPrintSceneNumbers]; }

- (void)setHeaderString:(NSString *)header { [self setString:DocSettingHeader as:header]; }
- (NSString *)headerString { return [self getString:DocSettingHeader]; }

// ... and so on

@end
