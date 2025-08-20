//
//  BeatPlugin+Modals.m
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 27.11.2024.
//

#import "BeatPlugin+Modals.h"
#import <BeatPlugins/BeatPlugins-Swift.h>

@implementation BeatPlugin (Modals)

#pragma mark - Modals

/// Presents an alert box
- (void)alert:(NSString*)title withText:(NSString*)info
{
#if TARGET_OS_IOS
    // Do something on iOS
    UIViewController* vc = (UIViewController*)self.delegate;
    UIAlertController* ac = [UIAlertController alertControllerWithTitle:title message:info preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [ac dismissViewControllerAnimated:false completion:nil];
    }]];
    [vc presentViewController:ac animated:false completion:^{
        //
    }];
    
#else
    // Send back to main thread
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^(void){
            [self alert:title withText:info];
        });
        return;
    }
    if ([info isEqualToString:@"undefined"]) info = @"";
    
    NSAlert *alert = [self dialog:title withInfo:info];
    [alert addButtonWithTitle:[BeatLocalization localizedStringForKey:@"general.OK"]];
    [alert runModal];
#endif
}

/// Presents a confirmation box, returning `true` if the user clicked `OK`.
- (bool)confirm:(NSString*)title withInfo:(NSString*)info
{
#if TARGET_OS_IOS
    // Do something on iOS
    NSLog(@"WARNING: Beat.confirm missing on iOS");
    return false;
#else
    NSAlert *alert = NSAlert.new;
    alert.messageText = title;
    alert.informativeText = info;
    
    [alert addButtonWithTitle:[BeatLocalization localizedStringForKey:@"general.OK"]];
    [alert addButtonWithTitle:[BeatLocalization localizedStringForKey:@"general.cancel"]];
    
    NSModalResponse response = [alert runModal];
    
    return (response == NSModalResponseOK || response == NSAlertFirstButtonReturn);
#endif
}

/**
 Displays a more elaborate modal window. You can add multiple types of inputs, define their values and names.
 This is how you create the settings dictionary in JavaScript:
 ```
 Beat.modal({
     title: "This is a test modal",
     info: "You can input stuff into multiple types of fields",
     items: [
         {
             type: "text",
             name: "characterName",
             label: "Character Name",
             placeholder: "First Name"
         },
         {
             type: "dropdown",
             name: "characterRole",
             label: "Role",
             items: ["Protagonist", "Supporting Character", "Other"]
         },
         {
             type: "space"
         },
         {
             type: "checkbox",
             name: "important",
             label: "This is an important character"
         },
         {
             type: "checkbox",
             name: "recurring",
             label: "Recurring character"
         }
     ]
 }, function(response) {
     if (response) {
         // The user clicked OK
         Beat.log(JSON.stringify(response))
     } else {
         // The user clicked CANCEL
     }
 })
 ```
 @param settings Dictionary of modal window settings. Return value dictionary contains corresponding control names.
 */
- (NSDictionary*)modal:(NSDictionary*)settings callback:(JSValue*)callback {
#if !TARGET_OS_IOS
    if (!NSThread.isMainThread) {
        [self log:@"ERROR: Trying to create a modal from background thread"];
        return nil;
    }
    
    // We support both return & callback in modal windows
    
    NSString *title = (settings[@"title"] != nil) ? settings[@"title"] : @"";
    NSString *info  = (settings[@"info"] != nil) ? settings[@"info"] : @"";
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = title;
    alert.informativeText = info;
    
    [alert addButtonWithTitle:[BeatLocalization localizedStringForKey:@"general.OK"]];
    [alert addButtonWithTitle:[BeatLocalization localizedStringForKey:@"general.cancel"]];
    
    BeatModalAccessoryView *itemView = [[BeatModalAccessoryView alloc] init];
    
    if ([settings[@"items"] isKindOfClass:NSArray.class]) {
        NSArray *items = settings[@"items"];
        
        for (NSDictionary* item in items) {
            [itemView addField:item];
        }
    }
    
    [itemView setFrame:(NSRect){ 0, 0, 350, itemView.heightForItems }];
    [alert setAccessoryView:itemView];
    NSModalResponse response = [alert runModal];
    
    if (response == NSModalResponseOK || response == NSAlertFirstButtonReturn) {
        NSDictionary *values = itemView.valuesForFields;
        [self runCallback:callback withArguments:@[values]];
        return values;
    } else {
        [self runCallback:callback withArguments:nil];
        return nil;
    }
#else
    // Do something on iOS
    NSLog(@"WARNING: Beat.modal missing on iOS");
    return @{};
#endif
}

/** Simple text input prompt.
 @param prompt Title of the dialog
 @param info Further info  displayed under the title
 @param placeholder Placeholder string for text input
 @param defaultText Default value for text input
 @param callback Callback when not presenting in sync
 */
- (NSString*)prompt:(NSString*)prompt withInfo:(NSString*)info placeholder:(NSString*)placeholder defaultText:(NSString*)defaultText callback:(JSValue*)callback
{
#if !TARGET_OS_IOS
    if (!NSThread.isMainThread) {
        [self log:@"ERROR: Trying to create a prompt from background thread"];
        return nil;
    }
    
    if ([placeholder isEqualToString:@"undefined"]) placeholder = @"";
    if ([defaultText isEqualToString:@"undefined"]) defaultText = @"";
    
    NSAlert *alert = [self dialog:prompt withInfo:info];
    [alert addButtonWithTitle:[BeatLocalization localizedStringForKey:@"general.OK"]];
    [alert addButtonWithTitle:[BeatLocalization localizedStringForKey:@"general.cancel"]];
    
    NSRect frame = NSMakeRect(0, 0, 300, 24);
    NSTextField *inputField = [[NSTextField alloc] initWithFrame:frame];
    inputField.placeholderString = placeholder;
    [alert setAccessoryView:inputField];
    [inputField setStringValue:defaultText];
    
    alert.window.initialFirstResponder = inputField;
    
    NSModalResponse response = [alert runModal];
    if (response == NSModalResponseOK || response == NSAlertFirstButtonReturn) {
        return inputField.stringValue;
    } else {
        return nil;
    }
    
#else
    NSLog(@"WARNING: Most Beat.prompt functionality is missing on iOS");
    
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:prompt message:info preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = placeholder;
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [callback callWithArguments:@[alert.textFields.firstObject.text]];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        [callback callWithArguments:nil];
    }]];
    
    if (self.container != nil) {
        UIViewController* vc = [self.container getViewController];
        [vc presentViewController:alert animated:false completion:^{  }];
    }
        
    /*
     let alert = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)

             alert.addTextField { (textField) in
                 textField.text = defaultText
             }

             alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: { (action) in
                 if let text = alert.textFields?.first?.text {
                     completionHandler(text)
                 } else {
                     completionHandler(defaultText)
                 }

             }))

             alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { (action) in

                 completionHandler(nil)

             }))

             self.present(alert, animated: true, completion: nil)
     */
    
    return @"";
#endif
}

/** Presents a dropdown box. Returns either the selected option or `null` when the user clicked on *Cancel*.
 @param prompt Title of the dropdown dialog
 @param info Further information presented to the user below the title
 @param items Items in the dropdown box as array of strings
*/
- (NSString*)dropdownPrompt:(NSString*)prompt withInfo:(NSString*)info items:(NSArray*)items
{
#if !TARGET_OS_IOS
    if (!NSThread.isMainThread) {
        [self log:@"ERROR: Trying to create a dropdown prompt from background thread"];
        return nil;
    }
    
    NSAlert *alert = [self dialog:prompt withInfo:info];
    [alert addButtonWithTitle:[BeatLocalization localizedStringForKey:@"general.OK"]];
    [alert addButtonWithTitle:[BeatLocalization localizedStringForKey:@"general.cancel"]];
    
    NSPopUpButton *popup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0,0, 300, 24)];
    
    [popup addItemWithTitle:[BeatLocalization localizedStringForKey:@"plugins.input.select"]];
    
    for (id item in items) {
        // Make sure the title becomes a string
        NSString *title = [NSString stringWithFormat:@"%@", item];
        [popup addItemWithTitle:title];
    }
    [alert setAccessoryView:popup];
    NSModalResponse response = [alert runModal];
    
    if (response == NSModalResponseOK || response == NSAlertFirstButtonReturn) {
        // Return an empty string if the user didn't select anything
        if ([popup.selectedItem.title isEqualToString: [BeatLocalization localizedStringForKey:@"plugins.input.select"]]) return @"";
        else return popup.selectedItem.title;
    } else {
        return nil;
    }
#else
    NSLog(@"WARNING: Beat.dropdownPrompt missing on iOS");
    return @"";
#endif
}

#if !TARGET_OS_IOS
/// Displays a simple alert box.
- (NSAlert*)dialog:(NSString*)title withInfo:(NSString*)info
{
    if (!NSThread.isMainThread) {
        [self log:@"ERROR: Trying to create a dialog from background thread"];
        return nil;
    }
    
    if ([info isEqualToString:@"undefined"]) info = @"";

    NSAlert *alert = NSAlert.new;
    alert.messageText = title;
    alert.informativeText = info;
    
    return alert;
}
#endif

@end
