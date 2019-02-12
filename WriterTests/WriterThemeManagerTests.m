//
//  WriterThemeManagerTests.m
//  Writer
//
//  Created by Hendrik Noeller on 05.04.16.
//  Copyright © 2016 Hendrik Noeller. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "ThemeManager.h"

@interface WriterThemeManagerTests : XCTestCase

@end

@implementation WriterThemeManagerTests


//Allways start tests with no plist file, so that the default on is copied from the bundle
- (void)setUp
{
    NSLog(@"Set up");
    [super setUp];
    [[NSFileManager defaultManager] moveItemAtPath:[self supportDirPath]
                                            toPath:[self supportDirBackupPath]
                                             error:nil];
}

- (void)tearDown
{
    NSLog(@"Tear down");
    [[NSFileManager defaultManager] removeItemAtPath:[self supportDirPath]
                                               error:nil];
    [[NSFileManager defaultManager] moveItemAtPath:[self supportDirBackupPath]
                                            toPath:[self supportDirPath]
                                             error:nil];
    [super tearDown];
}

- (NSString*)supportDirPath
{
    NSArray<NSString*>* searchPaths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                                                          NSUserDomainMask,
                                                                          YES);
    NSString* applicationSupportDir = searchPaths[0];
    NSString* appName = @"Writer";
    NSString* writerAppSupportDir = [applicationSupportDir stringByAppendingPathComponent:appName];
    
    return writerAppSupportDir;
}

- (NSString*)supportDirBackupPath
{
    return [[self supportDirPath] stringByAppendingString:@".testbackup"];
}

- (void)testSharing
{
    ThemeManager* managerOne = [ThemeManager sharedManager];
    ThemeManager* managerTwo = [ThemeManager sharedManager];
    
    XCTAssertEqual(managerOne, managerTwo);
}

- (void)testDefaultFile
{
    ThemeManager* manager = [[ThemeManager alloc] init];
    
    XCTAssertEqual([manager numberOfThemes], 5);
    
    XCTAssertEqualObjects([manager nameForThemeAtIndex:0], @"Light (Default)");
    XCTAssertEqualObjects([manager nameForThemeAtIndex:1], @"Dark");
    XCTAssertEqualObjects([manager nameForThemeAtIndex:2], @"Solarized Light");
    XCTAssertEqualObjects([manager nameForThemeAtIndex:3], @"Solarized Dark");
    XCTAssertEqualObjects([manager nameForThemeAtIndex:4], @"Monokai");
    XCTAssertEqualObjects([manager nameForThemeAtIndex:5], @"");
    XCTAssertEqualObjects([manager nameForThemeAtIndex:-1], @"");
    
    XCTAssertNotNil([manager currentBackgroundColor]);
    XCTAssertNotNil([manager currentSelectionColor]);
    XCTAssertNotNil([manager currentTextColor]);
    XCTAssertNotNil([manager currentInvisibleTextColor]);
    XCTAssertNotNil([manager currentCommentColor]);
    XCTAssertNotNil([manager currentCaretColor]);
    
    XCTAssertEqual([manager selectedTheme], 0);
    
    [manager selectThemeWithName:@"Dark"];
    XCTAssertEqual([manager selectedTheme], 1);
    [manager selectThemeWithName:@"Solarized Light"];
    XCTAssertEqual([manager selectedTheme], 2);
    [manager selectThemeWithName:@"Solarized Dark"];
    XCTAssertEqual([manager selectedTheme], 3);
    [manager selectThemeWithName:@"Monokai"];
    XCTAssertEqual([manager selectedTheme], 4);
    [manager selectThemeWithName:@"Light (Default)"];
    XCTAssertEqual([manager selectedTheme], 0);
    
    [manager selectThemeWithName:@"blabediblup"];
    XCTAssertEqual([manager selectedTheme], 0);
    [manager selectThemeWithName:@"Dark"];
    [manager selectThemeWithName:@"blabediblup"];
    XCTAssertEqual([manager selectedTheme], 1);
    
    XCTAssertNotNil([manager currentBackgroundColor]);
    XCTAssertNotNil([manager currentSelectionColor]);
    XCTAssertNotNil([manager currentTextColor]);
    XCTAssertNotNil([manager currentInvisibleTextColor]);
    XCTAssertNotNil([manager currentCommentColor]);
    XCTAssertNotNil([manager currentCaretColor]);
}

- (void)testInvalidFile
{
    //Test with a file with invalid data, e.g. missing rgb values or names for things. it should copy the original file from resources
    [[NSFileManager defaultManager] createDirectoryAtPath:[self supportDirPath]
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    
    NSString* themeFile = [[self supportDirPath] stringByAppendingPathComponent:@"Themes.plist"];
    [invalidPlistFile writeToFile:themeFile
                       atomically:YES
                         encoding:NSUTF8StringEncoding
                            error:nil];
    
    ThemeManager* manager = [[ThemeManager alloc] init];
    
    XCTAssertEqual([manager numberOfThemes], 5);
    
    XCTAssertEqualObjects([manager nameForThemeAtIndex:0], @"Light (Default)");
    XCTAssertEqualObjects([manager nameForThemeAtIndex:1], @"Dark");
    XCTAssertEqualObjects([manager nameForThemeAtIndex:2], @"Solarized Light");
    XCTAssertEqualObjects([manager nameForThemeAtIndex:3], @"Solarized Dark");
    XCTAssertEqualObjects([manager nameForThemeAtIndex:4], @"Monokai");
    XCTAssertEqualObjects([manager nameForThemeAtIndex:5], @"");
    XCTAssertEqualObjects([manager nameForThemeAtIndex:-1], @"");
    
    XCTAssertNotNil([manager currentBackgroundColor]);
    XCTAssertNotNil([manager currentSelectionColor]);
    XCTAssertNotNil([manager currentTextColor]);
    XCTAssertNotNil([manager currentInvisibleTextColor]);
    XCTAssertNotNil([manager currentCommentColor]);
    XCTAssertNotNil([manager currentCaretColor]);
    
    XCTAssertEqual([manager selectedTheme], 0);
    
    [manager selectThemeWithName:@"Dark"];
    XCTAssertEqual([manager selectedTheme], 1);
    [manager selectThemeWithName:@"Solarized Light"];
    XCTAssertEqual([manager selectedTheme], 2);
    [manager selectThemeWithName:@"Solarized Dark"];
    XCTAssertEqual([manager selectedTheme], 3);
    [manager selectThemeWithName:@"Monokai"];
    XCTAssertEqual([manager selectedTheme], 4);
    [manager selectThemeWithName:@"Light (Default)"];
    XCTAssertEqual([manager selectedTheme], 0);
    
    [manager selectThemeWithName:@"blabediblup"];
    XCTAssertEqual([manager selectedTheme], 0);
    [manager selectThemeWithName:@"Dark"];
    [manager selectThemeWithName:@"blabediblup"];
    XCTAssertEqual([manager selectedTheme], 1);
    
    XCTAssertNotNil([manager currentBackgroundColor]);
    XCTAssertNotNil([manager currentSelectionColor]);
    XCTAssertNotNil([manager currentTextColor]);
    XCTAssertNotNil([manager currentInvisibleTextColor]);
    XCTAssertNotNil([manager currentCommentColor]);
    XCTAssertNotNil([manager currentCaretColor]);
}

- (void)testCorruptFile
{
    //Test with a complete wordjumble file. it should copy over the original file from ressources
    [[NSFileManager defaultManager] createDirectoryAtPath:[self supportDirPath]
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    NSString* themeFile = [[self supportDirPath] stringByAppendingPathComponent:@"Themes.plist"];
    [@"akjdfkaweuhfiou8w3hfio3hfoi<joi>Oijeogi4joijOI" writeToFile:themeFile
                                                        atomically:YES
                                                          encoding:NSUTF8StringEncoding
                                                             error:nil];
    
    ThemeManager* manager = [[ThemeManager alloc] init];
    
    XCTAssertEqual([manager numberOfThemes], 5);
    
    XCTAssertEqualObjects([manager nameForThemeAtIndex:0], @"Light (Default)");
    XCTAssertEqualObjects([manager nameForThemeAtIndex:1], @"Dark");
    XCTAssertEqualObjects([manager nameForThemeAtIndex:2], @"Solarized Light");
    XCTAssertEqualObjects([manager nameForThemeAtIndex:3], @"Solarized Dark");
    XCTAssertEqualObjects([manager nameForThemeAtIndex:4], @"Monokai");
    XCTAssertEqualObjects([manager nameForThemeAtIndex:5], @"");
    XCTAssertEqualObjects([manager nameForThemeAtIndex:-1], @"");
    
    XCTAssertNotNil([manager currentBackgroundColor]);
    XCTAssertNotNil([manager currentSelectionColor]);
    XCTAssertNotNil([manager currentTextColor]);
    XCTAssertNotNil([manager currentInvisibleTextColor]);
    XCTAssertNotNil([manager currentCommentColor]);
    XCTAssertNotNil([manager currentCaretColor]);
    
    XCTAssertEqual([manager selectedTheme], 0);
    
    [manager selectThemeWithName:@"Dark"];
    XCTAssertEqual([manager selectedTheme], 1);
    [manager selectThemeWithName:@"Solarized Light"];
    XCTAssertEqual([manager selectedTheme], 2);
    [manager selectThemeWithName:@"Solarized Dark"];
    XCTAssertEqual([manager selectedTheme], 3);
    [manager selectThemeWithName:@"Monokai"];
    XCTAssertEqual([manager selectedTheme], 4);
    [manager selectThemeWithName:@"Light (Default)"];
    XCTAssertEqual([manager selectedTheme], 0);
    
    [manager selectThemeWithName:@"blabediblup"];
    XCTAssertEqual([manager selectedTheme], 0);
    [manager selectThemeWithName:@"Dark"];
    [manager selectThemeWithName:@"blabediblup"];
    XCTAssertEqual([manager selectedTheme], 1);
    
    XCTAssertNotNil([manager currentBackgroundColor]);
    XCTAssertNotNil([manager currentSelectionColor]);
    XCTAssertNotNil([manager currentTextColor]);
    XCTAssertNotNil([manager currentInvisibleTextColor]);
    XCTAssertNotNil([manager currentCommentColor]);
    XCTAssertNotNil([manager currentCaretColor]);
    
}

NSString* invalidPlistFile = @""
@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
@"<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">"
@"<plist version=\"1.0\">"
@"<dict>"
@"<key>version</key>"
@"<integer>0</integer>"
@"<key>selectedTheme</key>"
@"<integer>2</integer>"
@"<key>themes</key>"
@"<array>"
@"<dict>"
@"<key>Name</key>"
@"<string>Light</string>"
@"<key>Background</key>"
@"<array>"
@"<integer>255</integer>"
@"<integer>255</integer>"
@"<integer>255</integer>"
@"</array>"
@"<key>Selection</key>"
@"<array>"
@"<integer>212</integer>"
@"<integer>212</integer>"
@"<integer>212</integer>"
@"</array>"
@"<key>Text</key>"
@"<array>"
@"<integer>0</integer>"
@"<integer>0</integer>"
@"</array>"
@"<key>InvisibleText</key>"
@"<array>"
@"<integer>170</integer>"
@"</array>"
@"<key>Caret</key>"
@"<array>"
@"<integer>50</integer>"
@"<integer>50</integer>"
@"<integer>50</integer>"
@"</array>"
@"<key>Comment</key>"
@"<array/>"
@"</dict>"
@"<dict>"
@"<key>Background</key>"
@"<array>"
@"<integer>40</integer>"
@"<integer>40</integer>"
@"<integer>40</integer>"
@"</array>"
@"<key>Text</key>"
@"<array>"
@"<integer>255</integer>"
@"<integer>255</integer>"
@"<integer>255</integer>"
@"</array>"
@"<key>Caret</key>"
@"<array>"
@"<integer>200</integer>"
@"<integer>200</integer>"
@"<integer>200</integer>"
@"</array>"
@"<key>Comment</key>"
@"<array>"
@"<integer>102</integer>"
@"<integer>217</integer>"
@"<integer>239</integer>"
@"</array>"
@"</dict>"
@"</array>"
@"</dict>"
@"</plist>";
@end
