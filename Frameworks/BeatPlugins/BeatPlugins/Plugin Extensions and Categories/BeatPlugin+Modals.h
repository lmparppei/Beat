//
//  BeatPlugin+Modals.h
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 27.11.2024.
//

#import <BeatPlugins/BeatPlugins.h>
#import <JavaScriptCore/JavaScriptCore.h>

@protocol BeatPluginModalExports <JSExport>

#pragma mark Modal windows
/// Displays a simple modal alert box
JSExportAs(alert, - (void)alert:(NSString*)title withText:(NSString*)info);
/// Displays a text input prompt.
/// - returns String value. Value is `nil` if the user pressed cancel.
JSExportAs(prompt, - (NSString*)prompt:(NSString*)prompt withInfo:(NSString*)info placeholder:(NSString*)placeholder defaultText:(NSString*)defaultText callback:(JSValue*)callback);
/// Displays a confirmation modal. Returns `true` if the user pressed OK.
JSExportAs(confirm, - (bool)confirm:(NSString*)title withInfo:(NSString*)info);
/// Displays a dropdown prompt with a list of strings. Returns the selected string. Return value is `nil` if the user pressed cancel.
JSExportAs(dropdownPrompt, - (NSString*)dropdownPrompt:(NSString*)prompt withInfo:(NSString*)info items:(NSArray*)items);
/// Displays a modal with given settings. Consult the wiki for correct dictionary keys and values.
JSExportAs(modal, -(NSDictionary*)modal:(NSDictionary*)settings callback:(JSValue*)callback);

@end

@interface BeatPlugin (Modals) <BeatPluginModalExports>

/// Presents an alert box
- (void)alert:(NSString*)title withText:(NSString*)info;

@end
