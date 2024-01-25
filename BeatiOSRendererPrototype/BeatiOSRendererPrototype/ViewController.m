//
//  ViewController.m
//  BeatiOSRendererPrototype
//
//  Created by Lauri-Matti Parppei on 22.1.2024.
//

#import "ViewController.h"
#import <BeatParsing/BeatParsing.h>
#import <BeatCore/BeatCore.h>
#import <BeatPagination2/BeatPagination2.h>

@interface ViewController () <BeatPaginationDelegate>
@property (nonatomic) IBOutlet UITextView* textView;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.textView.linkTextAttributes = @{ NSForegroundColorAttributeName: BXColor.blackColor };
    self.textView.editable = false;
    
    NSURL* url = [NSBundle.mainBundle URLForResource:@"Testi" withExtension:@"fountain"];
    NSString* string = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:nil];
    
    BeatExportSettings* settings = BeatExportSettings.new;
    settings.printSceneNumbers = true;
    
    ContinuousFountainParser* parser = [ContinuousFountainParser.alloc initWithString:string];
    
    BeatScreenplay* screenplay = [BeatScreenplay from:parser settings:settings];
    
    BeatPaginationManager* manager = [BeatPaginationManager.alloc initWithSettings:settings delegate:nil renderer:nil livePagination:false];
    [manager paginateWithLines:screenplay.lines];
    
    BeatRenderer* renderer = [BeatRenderer.alloc initWithSettings:settings];
    NSArray<NSAttributedString*>* pages = [renderer renderPages:manager.finishedPagination.pages];
    
    NSMutableAttributedString* attrStr = NSMutableAttributedString.new;
    
    for (NSAttributedString* page in pages) {
        [attrStr appendAttributedString:page];
    }
    
    [self.textView setAttributedText:attrStr];
}


@end
