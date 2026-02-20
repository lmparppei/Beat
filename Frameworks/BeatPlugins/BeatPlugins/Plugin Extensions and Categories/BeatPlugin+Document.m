//
//  BeatPlugin+Document.m
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 12.2.2026.
//

#import "BeatPlugin+Document.h"

@implementation BeatPlugin (Document)

#pragma mark - Document utilities

/// Returns the plain-text file content used to save current screenplay (including settings block etc.)
- (NSString*)createDocumentFile
{
    return [self.delegate createDocumentFile];
}
/// Returns the plain-text file content used to save current screenplay (including settings block etc.) with additional `BeatDocumentSettings` block
- (NSString*)createDocumentFileWithAdditionalSettings:(NSDictionary*)additionalSettings
{
    return [self.delegate createDocumentFileWithAdditionalSettings:additionalSettings];
}



#pragma mark - Document

/// Creates a new document. macOS-only for now.
- (void)newDocument:(NSString*)string
{
#if TARGET_OS_OSX
    // This fixes a rare and weird NSResponder issue. Forward this call to the actual document, no questions asked.
    if (![string isKindOfClass:NSString.class]) {
        [self.delegate.document newDocument:nil];
        return;
    }
    
    id<BeatAppAPIDelegate> delegate = (id<BeatAppAPIDelegate>)NSApp.delegate;
    if (string.length) [delegate newDocumentWithContents:string];
    else [NSDocumentController.sharedDocumentController newDocument:nil];
#endif
}

/// Creates a new *document object* if you want to access that document after creating it.
- (id)newDocumentObject:(NSString*)string
{
#if !TARGET_OS_IOS
    id<BeatAppAPIDelegate> delegate = (id<BeatAppAPIDelegate>)NSApp.delegate;
    if (string.length) return [delegate newDocumentWithContents:string];
    else return [NSDocumentController.sharedDocumentController openUntitledDocumentAndDisplay:YES error:nil];
#endif
    return nil;
}


#pragma mark - Access other documents

#if !TARGET_OS_IOS
/// Returns all document instances
- (NSArray<id<BeatPluginDelegate>>*)documents
{
    return (NSArray<id<BeatPluginDelegate>>*)NSDocumentController.sharedDocumentController.documents;
}
- (BeatPlugin*)interface:(id<BeatPluginDelegate>)document
{
    BeatPlugin* interface = BeatPlugin.new;
    interface.delegate = document;
    return interface;
}
- (id<BeatPluginDelegate>)document
{
    return self.delegate.document;
}
#endif




#pragma mark - Document Settings

// Plugin-specific document settings (prefixed by plugin name)
- (id)getDocumentSetting:(NSString*)settingName
{
    NSString *key = [NSString stringWithFormat:@"%@: %@", self.pluginName, settingName];
    return [self.delegate.documentSettings get:key];
}
- (void)setDocumentSetting:(NSString*)settingName setting:(id)value
{
    NSString *key = [NSString stringWithFormat:@"%@: %@", self.pluginName, settingName];
    [self.delegate.documentSettings set:key as:value];
}

/// Returns raw document setting (NOT prefixed by plugin name)
- (id)getRawDocumentSetting:(NSString*)settingName
{
    return [self.delegate.documentSettings get:settingName];
}

/// Sets a raw document setting (NOT prefixed by plugin name)
- (void)setRawDocumentSetting:(NSString*)settingName setting:(id)value
{
    [self.delegate.documentSettings set:settingName as:value];
}

#pragma mark - Objective C value setter/getter

/// Set any value in the main document class class
- (void)setPropertyValue:(NSString*)key value:(id)value
{
    [self.delegate setPropertyValue:key value:value];
}

/// Get any value in the main document class
- (id)getPropertyValue:(NSString *)key
{
    return [self.delegate getPropertyValue:key];
}


@end
