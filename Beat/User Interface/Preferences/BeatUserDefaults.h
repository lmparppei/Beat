//
//  BeatUserDefaults.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 2.10.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BeatUserDefaults : NSObject
+ (BeatUserDefaults*)sharedDefaults;
+ (NSDictionary*)userDefaults;
- (void)readUserDefaultsFor:(id)target;
- (void)save:(id)value forKey:(NSString*)key;
- (BOOL)isSuppressed:(NSString*)key;
- (void)setSuppressed:(NSString*)key value:(bool)value;
- (void)saveBool:(bool)value forKey:(NSString*)key;
- (id)get:(NSString*)docKey;
- (BOOL)getBool:(NSString*)docKey;
- (CGFloat)getFloat:(NSString*)docKey;
- (void)saveSettingsFrom:(id)target;
- (NSInteger)getInteger:(NSString*)docKey;
- (void)saveInteger:(NSInteger)value forKey:(NSString*)key;
- (void)saveFloat:(CGFloat)value forKey:(NSString*)key;
- (id)defaultValueFor:(NSString*)key;
@end

NS_ASSUME_NONNULL_END
