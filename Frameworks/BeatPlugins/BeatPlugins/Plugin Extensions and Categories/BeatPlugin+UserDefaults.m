//
//  BeatPlugin+UserDefaults.m
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 3.12.2025.
//

#import "BeatPlugin+UserDefaults.h"
#import "BeatPlugin+Logging.h"

@implementation BeatPlugin (UserDefaults)


#pragma mark - User settings

/// Defines user setting value for the given key.
- (void)setUserDefault:(NSString*)settingName setting:(id)value
{
    if (self.pluginName == nil || self.pluginName.length == 0) {
        [self reportError:@"setUserDefault: No plugin name" withText:@"You need to specify plugin name before trying to save settings."];
        return;
    }
    
    NSString *keyName = [NSString stringWithFormat:@"%@: %@", self.pluginName, settingName];
    [[NSUserDefaults standardUserDefaults] setValue:value forKey:keyName];
}

/// Gets  user setting value for the given key.
- (id)getUserDefault:(NSString*)settingName
{
    NSString *keyName = [NSString stringWithFormat:@"%@: %@", self.pluginName, settingName];
    id value = [[NSUserDefaults standardUserDefaults] valueForKey:keyName];
    return value;
}

- (id)getRawUserDefault:(NSString*)settingName
{
    return [BeatUserDefaults.sharedDefaults get:settingName];
}

- (void)setRawUserDefault:(NSString*)settingName value:(id)value
{
    [BeatUserDefaults.sharedDefaults save:value forKey:settingName];
}



@end

