//
//  BeatPlugin+Document.h
//  BeatPlugins
//
//  Created by Lauri-Matti Parppei on 12.2.2026.
//

#import <BeatPlugins/BeatPlugins.h>
#import <JavaScriptCore/JavaScriptCore.h>

#if TARGET_OS_OSX
@class Document;
#endif

@protocol BeatPluginDocumentExports <JSExport>

/// Creates a new document with given string
/// - note: The string can contain a settings block
- (void)newDocument:(NSString*)string;

/// Creates a new `Document` object without actually opening the window
- (id)newDocumentObject:(NSString*)string;

#pragma mark - Document utilities

#if TARGET_OS_OSX
/// Returns the main Document object
- (Document*)document;

/// Returns all document instances
- (NSArray<Document*>*)documents;

/// Returns a plugin interface for given document
- (Document*)interface:(Document*)document;
#endif


/// Returns the plain-text file content used to save current screenplay (including settings block etc.)
- (NSString*)createDocumentFile;
/// Returns the plain-text file content used to save current screenplay (including settings block etc.) with additional `BeatDocumentSettings` block
- (NSString*)createDocumentFileWithAdditionalSettings:(NSDictionary*)additionalSettings;


#pragma mark - Document settings
/// Returns a document setting prefixed by current plugin name
- (id)getDocumentSetting:(NSString*)key;
/// Returns a non-prefixed document setting
- (id)getRawDocumentSetting:(NSString*)key;
/// For those who REALLY know what they're doing
- (id)getPropertyValue:(NSString*)key;
/// Sets a document setting without plugin prefix. Can be used to tweak actual document data.
JSExportAs(setRawDocumentSetting, - (void)setRawDocumentSetting:(NSString*)settingName setting:(id)value);
/// Sets a document setting, prefixed by plugin name, so you won't mess up settings for other plugins.
JSExportAs(setDocumentSetting, - (void)setDocumentSetting:(NSString*)settingName setting:(id)value);


#pragma mark - Objective C value setter/getter

/// Set any value in the main document class class
- (void)setPropertyValue:(NSString*)key value:(id)value;

/// Get any value in the main document class
- (id)getPropertyValue:(NSString *)key;

@end

@interface BeatPlugin (Document) <BeatPluginDocumentExports>

@end

