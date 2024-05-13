//
//  PrintView.h
//  Writer / Beat
//
//  Copyright © 2019 Lauri-Matti Parppei. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <BeatParsing/BeatParsing.h>

typedef NS_ENUM(NSUInteger, BeatPrintOperation) {
	BeatToPDF = 0,
	BeatToPrint,
	BeatToPreview,
};

@protocol PrintViewDelegate
@property (weak, nonatomic, readonly) id<BeatEditorDelegate> editorDelegate;
@property (nonatomic) NSMutableArray* printViews;
- (void)didFinishPreviewAt:(NSURL*)url;
- (void)didExportFileAt:(NSURL*)url;
- (UIViewController*)viewController;
@end

@interface BeatPrintView : UIView
@property (weak) id<PrintViewDelegate> delegate;
- (id)initWithScript:(NSArray*)lines operation:(BeatPrintOperation)mode settings:(BeatExportSettings*)settings delegate:(id<PrintViewDelegate>)delegate;
@end
