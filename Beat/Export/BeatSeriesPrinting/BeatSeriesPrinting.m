//
//  BeatSeriesPrinting.m
//  TableReorganizeTest
//
//  Created by Lauri-Matti Parppei on 24.11.2020.
//

/*
 
 This class allows printing multiple scripts at once while also providing
 a nice UI for the process.
 
 */

#import "BeatSeriesPrinting.h"
#import "NSMutableArray+MoveItem.h"
#import <Cocoa/Cocoa.h>

@interface BeatSeriesPrinting ()
@property (weak) IBOutlet NSTableView *table;
@property (nonatomic) NSMutableArray<NSURL*> *urls;
@end

@implementation BeatSeriesPrinting

- (void)awakeFromNib {
    _urls = [NSMutableArray array];
    [_table registerForDraggedTypes:@[NSPasteboardTypeString, NSPasteboardTypeFileURL]];
}

#pragma mark - Table view data source & delegate

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return _urls.count;
}

-(NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSString *identifier = tableColumn.identifier;
    NSTableCellView *cell = [tableView makeViewWithIdentifier:identifier owner:tableView];
    
    NSURL *url = self.urls[row];
    NSString *name = url.path.lastPathComponent.stringByDeletingPathExtension;
    
    cell.textField.stringValue = name;
    
    return cell;
}

- (id<NSPasteboardWriting>)tableView:(NSTableView *)tableView pasteboardWriterForRow:(NSInteger)row {
    NSString *stringRep = self.urls[row].path.lastPathComponent.stringByDeletingPathExtension;
    NSPasteboardItem *pboardItem = [[NSPasteboardItem alloc] init];

    [pboardItem setString:stringRep forType:NSPasteboardTypeString];

    return pboardItem;
}
-(NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id<NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)dropOperation {
    if (dropOperation == NSTableViewDropAbove) {
        tableView.draggingDestinationFeedbackStyle = NSTableViewDraggingDestinationFeedbackStyleSourceList;
        return NSDragOperationMove;
    } else {
        return NSDragOperationNone;
    }
}
- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id<NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)dropOperation {
    NSArray *items = info.draggingPasteboard.pasteboardItems;
    if (!items.count) return NO;
    
    NSPasteboardItem *item = items.firstObject;
    if ([item.types containsObject:@"public.file-url"]) {
        bool newFilesAdded = NO;
        
        for (NSPasteboardItem *newFile in items) {
            NSString *urlString = [newFile stringForType:NSPasteboardTypeFileURL];
            NSURL *url = [NSURL URLWithString:urlString];

            if (![_urls containsObject:url]) {
                [_urls addObject:url];
                newFilesAdded = YES;
            }
        }
        
        if (newFilesAdded) {
            [self.table reloadData];
            return YES;
        }
    }
    
    // When dragging we need to handle strings for some reason.
    // This shouldn't be so, but what can I say.
    
    NSString *filenameStub =  [item stringForType:NSPasteboardTypeString];
    NSURL *url = [self urlForFilename:filenameStub];
    NSInteger index = [self.urls indexOfObject:url];
    
    if (index >= 0) {
        [_urls moveObjectAtIndex:index toIndex:row];
        [_table reloadData];
        return YES;
    } else {
        return NO;
    }

}

-(id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    return self.urls[row];
}

-(NSURL*)urlForFilename:(NSString*)filenameStub {
    bool found = NO;
    NSInteger index = 0;
    
    for (NSURL *url in self.urls) {
        NSString *filename = url.path.lastPathComponent.stringByDeletingPathExtension;
        if ([filename isEqualToString:filenameStub]) {
            found = YES;
            break;
        }
        index++;
    }
    
    if (found) return self.urls[index];
    else return nil;
}

# pragma mark - UI functions

-(IBAction)removeFile:(id)sender {
    NSInteger index = _table.selectedRow;
    
    if (index >= 0) {
        NSURL *url = self.urls[index];
        [_urls removeObject:url];
        [_table removeRowsAtIndexes:[NSIndexSet indexSetWithIndex:index] withAnimation:NSTableViewAnimationSlideUp];
    }
}
-(IBAction)addFiles:(id)sender {
    NSOpenPanel *dialog = [NSOpenPanel openPanel];
    dialog.allowsMultipleSelection = YES;
    dialog.allowedFileTypes = @[@"fountain"];
    
    if ([dialog runModal] == NSModalResponseOK) {
        for (NSURL *url in dialog.URLs) {
            if (![_urls containsObject:url]) [_urls addObject:url];
        }
        
        [_table reloadData];
    }
}

-(IBAction)start:(id)sender {
    if (!_urls.count) return;
    
    NSError *error;
    
    for (NSURL *url in _urls) {
        NSString *text = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:&error];
        
        if (error) {
            NSString *filename = url.path.lastPathComponent;
            [self alertPanelWithTitle:@"Error opening file" content:[NSString stringWithFormat:@"%@ could not be opened. Other documents will be printed normally.", filename]];
            error = nil;
        } else {
            NSLog(@"%@", text);
        }
    }
}

-(void)alertPanelWithTitle:(NSString*)title content:(NSString*)content {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"OK"];
    [alert setMessageText:title];
    [alert setInformativeText:content];
    [alert setAlertStyle:NSAlertStyleWarning];
    //[alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
    [alert runModal];
}


@end
