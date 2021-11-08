[![Build Status](https://travis-ci.org/abbeycode/UnzipKit.svg?branch=master)](https://travis-ci.org/abbeycode/UnzipKit)
[![Documentation Coverage](https://img.shields.io/cocoapods/metrics/doc-percent/UnzipKit.svg)](http://cocoadocs.org/docsets/UnzipKit)

# About

UnzipKit is an Objective-C `zlib` wrapper for compressing and decompressing Zip files on OS X and iOS. It's based on the [AgileBits fork](https://github.com/AgileBits/objective-zip) of [Objective-Zip](http://code.google.com/p/objective-zip/), developed by [Flying Dolphin Studio](http://www.flyingdolphinstudio.com).

It provides the following over Objective-Zip:

* A simpler API, with only a handful of methods, and no incantations to remember
* The ability to delete files in an archive, including overwriting an existing file
* Pervasive use of blocks, making iteration simple
* Full documentation for all methods
* Pervasive use of `NSError`, instead of throwing exceptions

# Installation

UnzipKit supports both [CocoaPods](https://cocoapods.org/) and [Carthage](https://github.com/Carthage/Carthage). CocoaPods does not support dynamic framework targets (as of v0.39.0), so in that case, please use Carthage.

Cartfile:

    github "abbeycode/UnzipKit"

Podfile:

    pod "UnzipKit"

# Deleting files

Using the method `-deleteFile:error:` currently creates a new copy of the archive in a temporary location, without the deleted file, then replaces the original archive. By default, all methods to write data perform a delete on the file name they write before archiving the new data. You can turn this off by calling the overload with an `overwrite` argument, setting it to `NO`. This will not remove the original copy of that file, though, causing the archive to grow with each write of the same file name.

If that's not a concern, such as when creating a new archive from scratch, it would improve performance, particularly for archives with a large number of files.

```Objective-C
NSError *archiveError = nil;
UZKArchive *archive = [UZKArchive zipArchiveAtPath:@"An Archive.zip" error:&archiveError];
BOOL deleteSuccessful = [archive deleteFile:@"dir/anotherFilename.jpg"
                                      error:&error];
```

# Detecting Zip files

You can quickly and efficiently check whether a file at a given path or URL is a Zip archive:

```Objective-C
BOOL fileAtPathIsArchive = [UZKArchive pathIsAZip:@"some/file.zip"];

NSURL *url = [NSURL fileURLWithPath:@"some/file.zip"];
BOOL fileAtURLIsArchive = [UZKArchive urlIsAZip:url];
```

# Reading Zip contents

```Objective-C
NSError *archiveError = nil;
UZKArchive *archive = [UZKArchive zipArchiveAtPath:@"An Archive.zip" error:&archiveError];
NSError *error = nil;
```

You can use UnzipKit to perform these read-only operations:

* List the contents of the archive
    ```Objective-C
    NSArray<NSString*> *filesInArchive = [archive listFilenames:&error];
    ```
    
* Extract all files to disk

    ```Objective-C
    BOOL extractFilesSuccessful = [archive extractFilesTo:@"some/directory"
                                                overWrite:NO
                                                    error:&error];
    ```

* Extract each archived file into memory

    ```Objective-C
    NSData *extractedData = [archive extractDataFromFile:@"a file in the archive.jpg"
                                                   error:&error];
    ```

# Modifying archives

```Objective-C
NSError *archiveError = nil;
UZKArchive *archive = [UZKArchive zipArchiveAtPath:@"An Archive.zip" error:&archiveError];
NSError *error = nil;
NSData *someFile = // Some data to write
```

You can also modify Zip archives:

* Write an in-memory `NSData` into the archive

    ```Objective-C
    BOOL success = [archive writeData:someFile
                             filePath:@"dir/filename.jpg"
                                error:&error];
    ```
* Write data as a stream to the archive (from disk or over the network), using a block:

    ```Objective-C
    BOOL success = [archive writeIntoBuffer:@"dir/filename.png"
                                      error:&error
                                      block:
        ^BOOL(BOOL(^writeData)(const void *bytes, unsigned int length), NSError**(actionError)) {
            for (NSUInteger i = 0; i <= someFile.length; i += bufferSize) {
                const void *bytes = // some data
                unsigned int length = // length of data

                if (/* Some error occurred reading the data */) {
                    *actionError = // Any error that was produced, or make your own
                    return NO;
                }

                if (!writeData(&bytes, length)) {
                    return NO;
                }
            }

            return YES;
        }];
    ```
* Delete files from the archive

    ```Objective-C
    BOOL success = [archive deleteFile:@"No-good-file.txt" error:&error];
    ```


# Progress Reporting

The following methods support `NSProgress` and `NSProgressReporting`:

* `extractFilesTo:overwrite:error:`
* `extractData:error:`
* `extractDataFromFile:error:`
* `performOnFilesInArchive:error:`
* `performOnDataInArchive:error:`
* `extractBufferedDataFromFile:error:action:`
* `writeData:filePath:error:`*
* `writeData:filePath:fileDate:error:`*
* `writeData:filePath:fileDate:compressionMethod:password:error:`*
* `writeData:filePath:fileDate:compressionMethod:password:overwrite:error:`*

_* the `writeData...` methods don't support cancellation like the read-only methods do

## Using implicit `NSProgress` hierarchy

You can create your own instance of `NSProgress` and observe its `fractionCompleted` property with KVO to monitor progress like so:

```Objective-C
    static void *ExtractDataContext = &ExtractDataContext;

    UZKArchive *archive = [[UZKArchive alloc] initWithURL:aFileURL error:nil];

    NSProgress *extractDataProgress = [NSProgress progressWithTotalUnitCount:1];
    [extractDataProgress becomeCurrentWithPendingUnitCount:1];
    
    NSString *observedSelector = NSStringFromSelector(@selector(fractionCompleted));
    
    [extractDataProgress addObserver:self
                          forKeyPath:observedSelector
                             options:NSKeyValueObservingOptionInitial
                             context:ExtractDataContext];
    
    NSError *extractError = nil;
    NSData *data = [archive extractDataFromFile:firstFile error:&extractError];

    [extractDataProgress resignCurrent];
    [extractDataProgress removeObserver:self forKeyPath:observedSelector];
```

## Using your own explicit `NSProgress` instance

If you don't have a hierarchy of `NSProgress` instances, or if you want to observe more details during progress updates in `extractFilesTo:overwrite:error:`, you can create your own instance of `NSProgress` and set the `UZKArchive` instance's `progress` property, like so:

```Objective-C
    static void *ExtractFilesContext = &ExtractFilesContext;

    UZKArchive *archive = [[UZKArchive alloc] initWithURL:aFileURL error:nil];
    
    NSProgress *extractFilesProgress = [NSProgress progressWithTotalUnitCount:1];
    archive.progress = extractFilesProgress;
    
    NSString *observedSelector = NSStringFromSelector(@selector(localizedDescription));
    
    [self.descriptionsReported removeAllObjects];
    [extractFilesProgress addObserver:self
                           forKeyPath:observedSelector
                              options:NSKeyValueObservingOptionInitial
                              context:ExtractFilesContext];
    
    NSError *extractError = nil;
    BOOL success = [archive extractFilesTo:extractURL.path
                                 overwrite:NO
                                     error:&extractError];
    
    [extractFilesProgress removeObserver:self forKeyPath:observedSelector];
```

## Cancellation with `NSProgress`

Using either method above, you can call `[progress cancel]` to stop the operation in progress. It will cause the operation to fail, returning `nil` or `NO` (depending on the return type, and give an error with error code `UZKErrorCodeUserCancelled`.

Note: Cancellation is only supported on extraction methods, not write methods.


# Documentation

Full documentation for the project is available on [CocoaDocs](http://cocoadocs.org/docsets/UnzipKit).

# Logging

For all OS versions from 2016 onward (macOS 10.12, iOS 10, tvOS 10, watchOS 3), UnzipKit uses the new [Unified Logging framework](https://developer.apple.com/documentation/os/logging) for logging and Activity Tracing. You can view messages at the Info or Debug level to view more details of how UnzipKit is working, and use Activity Tracing to help pinpoint the code path that's causing a particular error.

As a fallback, regular `NSLog` is used on older OSes, with all messages logged at the same level.

When debugging your own code, if you'd like to decrease the verbosity of the UnzipKit framework, you can run the following command:

    sudo log config --mode "level:default" --subsystem com.abbey-code.UnzipKit

The available levels, in order of increasing verbosity, are `default`, `info`, `debug`, with `debug` being the default.

## Logging guidelines

These are the general rules governing the particulars of how activities and log messages are classified and written. They were written after the initial round of log messages were, so there may be some inconsistencies (such as an incorrect log level). If you think you spot one, open an issue or a pull request!

### Logging

Log messages should follow these conventions.

1. Log messages don't have final punctuation (like these list items)
1. Messages that note a C function is about to be called, rather than a higher level UnzipKit or Cocoa method, end with "...", since it's not expected for them to log any details of their own

#### Default log level

There should be no messages at this level, so that it's possible for a consumer of the API to turn off _all_ diagnostic logging from it, as detailed above. It's only possible to `log config --mode "level:off"` for a process, not a subsystem.

#### Info log level

Info level log statements serve the following specific purposes.

1. Major action is taken, such as initializing an archive object, or deleting a file from an archive
1. Noting each public method has been called, and the arguments with which it was called
1. Signposting the major actions a public method takes
1. Notifying that an atypical condition has occurred (such as an action causing an early stop in a block or a NO return value)
1. Noting that a loop is about to occur, which will contain debug-level messages for each iteration

#### Debug log level

Most messages fall into this category, making it extremely verbose. All non-error messages that don't fall into either of the other two categories should be debug-level, with some examples of specific cases below.

1. Any log message in a private method
1. Noting variable and argument values in a method
1. Indicating that everything is working as expected
1. Indicating what happens during each iteration of a loop (or documenting that an iteration has happened at all)

#### Error log level

1. Every `NSError` generated should get logged with the same detail message as the `NSError` object itself
1. `NSError` log messages should contain the string of the error code's enumeration value (e.g. `"UZKErrorCodeArchiveNotFound"`) when it is known at design time
1. Errors should reported everywhere they're encountered, making it easier to trace their flows through the call stack
1. Early exits that result in desired work not being performed

#### Fault log level

So far, there is only one case that gets logged at Fault-level: when a Cocoa framework methods that come back with an error

### Activities
1. Public methods have English activity names with spaces, and are title-case
1. Private methods each have an activity with the method's name
1. Sub-activities are created for significant scope changes, such as when inside an action block, but not if no significant work is done before entering that action
1. Top-level activities within a method have variables named `activity`, with more specific labels given to sub-activities
1. If a method is strictly an overload that calls out to another overload without doing anything else, it should not define its own activity

# Pushing a new CocoaPods version

New tagged builds (in any branch) get pushed to CocoaPods automatically, provided they meet the following criteria:

1. All builds and tests succeed
2. The library builds successfully for CocoaPods and for Carthage
3. The build is tagged with something resembling a version number (`#.#.#(-beta#)`, e.g. **2.9** or **2.9-beta5**)
4. `pod spec lint` passes, making sure the CocoaPod is 100% valid

Before pushing a build, you must:

1. Add the release notes to the [CHANGELOG.md](CHANGELOG.md), and commit
2. Run [set-version](Scripts/set-version.sh), like so:

    `./Scripts/set-version.sh <version number>`

    This does the following:

    1. Updates the various Info.plist files to indicate the new version number, and commits them
    2. Makes an annotated tag whose message contains the release notes entered in Step 1

Once that's done, you can call `git push --follow-tags` [<sup id=a1>1</sup>](#f1), and let [Travis CI](https://travis-ci.org/abbeycode/UnzipKit/builds) take care of the rest.

# License

* UnzipKit: [See LICENSE (BSD)](LICENSE)
* MiniZip: [See MiniZip website](http://www.winimage.com/zLibDll/minizip.html)



<hr>

<span id="f1">1</span>: Or set `followTags = true` in your git config to always get this behavior:

    git config --global push.followTags true

[↩](#a1)
