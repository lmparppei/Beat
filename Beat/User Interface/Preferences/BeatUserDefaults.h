//
//  BeatUserDefaults.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 2.10.2021.
//  Copyright © 2021 KAPITAN!. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BeatUserDefaults : NSObject
+ (BeatUserDefaults*)sharedDefaults;
+ (NSDictionary*)userDefaults;
- (void)readUserDefaultsFor:(id)target;
- (void)saveBool:(bool)value forKey:(NSString*)key;
- (BOOL)getBool:(NSString*)docKey;
- (void)saveSettingsFrom:(id)target;
- (NSInteger)getInteger:(NSString*)docKey;
- (void)saveInteger:(NSInteger)value forKey:(NSString*)key;
@end

NS_ASSUME_NONNULL_END
