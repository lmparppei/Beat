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
- (void)readUserDefaultsFor:(id)target;
- (void)saveBool:(bool)value forKey:(NSString*)key;
- (bool)getBool:(NSString*)docKey;
- (void)saveSettingsFrom:(id)target;
@end

NS_ASSUME_NONNULL_END
