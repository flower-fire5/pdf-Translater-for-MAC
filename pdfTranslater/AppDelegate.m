//
//  AppDelegate.m
//  pdfTranslater
//
//  Created by Ilgwon Ha on 12/15/20.
//

#import "AppDelegate.h"
#import "ViewController.h"
#include "config.h"

@interface AppDelegate ()
{
    NSWindow* window;
}
@property (nonatomic, strong)ViewController *myViewController;
@property (nonatomic, strong)NSMenuItem *BTDEngineMenuItem;
@property (nonatomic, strong)NSMenuItem *tencentEngineMenuItem;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT) styleMask:NSWindowStyleMaskMiniaturizable|NSWindowStyleMaskClosable|NSWindowStyleMaskResizable|NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
    [window setTitle:@"A random app"];
    self.myViewController = [[ViewController alloc]init];
    [window setContentViewController:self.myViewController];
    [window makeKeyAndOrderFront:nil];
    
    CGFloat xPos = NSWidth([[window screen] frame])/2 - NSWidth([window frame])/2;
    CGFloat yPos = NSHeight([[window screen] frame])/2 - NSHeight([window frame])/2;
    [window setFrame:NSMakeRect(xPos, yPos, NSWidth([window frame]), NSHeight([window frame])) display:YES];
    // 创建菜单
    [self setupMenu];
    [NSApp setDelegate:self];
//    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(closeWindow) name:NSWindowWillCloseNotification object:nil];
}

- (void)setupMenu {
    // 创建主菜单
    NSMenu *mainMenu = [[NSMenu alloc] initWithTitle:@"MainMenu"];
    
    // 空菜单，为了将File菜单显示出来
    NSMenuItem *blankMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
    NSMenu *blankMenu = [[NSMenu alloc] initWithTitle:@""];
    
    // 创建 File 菜单
    NSMenuItem *fileMenuItem = [[NSMenuItem alloc] initWithTitle:@"File" action:nil keyEquivalent:@""];
    NSMenu *fileMenu = [[NSMenu alloc] initWithTitle:@"File"];
    
    // 创建 "Open Document" 菜单项
    NSMenuItem *openMenuItem = [[NSMenuItem alloc] initWithTitle:@"Open Document" action:@selector(addFileButtonClicked) keyEquivalent:@"o"];
    [openMenuItem setTarget:self];  // 设置点击该菜单项时调用的方法
    [fileMenu addItem:openMenuItem];
    
    // 创建 Select Translation Engine 菜单
    NSMenuItem *engineMenuItem = [[NSMenuItem alloc] initWithTitle:@"Select Translation Engine" action:nil keyEquivalent:@""];
    NSMenu *engineMenu = [[NSMenu alloc] initWithTitle:@"Select Translation Engine"];
    
    self.BTDEngineMenuItem = [[NSMenuItem alloc] initWithTitle:@"bytedance engine" action:@selector(selectBTDTranslationEngine) keyEquivalent:@"q"];
    
    
    self.tencentEngineMenuItem = [[NSMenuItem alloc] initWithTitle:@"tencent engine" action:@selector(selectTencentTranslationEngine) keyEquivalent:@"w"];
    
    [self.BTDEngineMenuItem setTarget:self];
    [self.tencentEngineMenuItem setTarget:self];
    [engineMenu addItem:self.BTDEngineMenuItem];
    [engineMenu addItem:self.tencentEngineMenuItem];

    
    // 添加 File 菜单到主菜单
    [mainMenu addItem:blankMenuItem];
    [mainMenu setSubmenu:blankMenu forItem:blankMenuItem];
    
    [mainMenu addItem:fileMenuItem];
    [mainMenu setSubmenu:fileMenu forItem:fileMenuItem];
    
    [mainMenu addItem:engineMenuItem];
    [mainMenu setSubmenu:engineMenu forItem:engineMenuItem];
    
    // 设置主菜单
    [NSApp setMainMenu:mainMenu];
    
    self.BTDEngineMenuItem.state = NSControlStateValueOn;
}

- (void)addFileButtonClicked {
    // 打开文件选择对话框
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setCanChooseFiles:YES];
    [openPanel setAllowedFileTypes:@[@"pdf"]];
    [openPanel setAllowsMultipleSelection:NO];
    
    [openPanel beginWithCompletionHandler:^(NSModalResponse result) {
        if (result == NSModalResponseOK) {
            NSURL *fileURL = [[openPanel URLs] firstObject];
            [self.myViewController loadPDFWithPath:[fileURL path]];
        }
    }];
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}
 
- (void)closeWindow {
    [NSApp terminate:self];
    
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

#pragma mark - Select Translation Engine
- (void)selectBTDTranslationEngine {
    [self.myViewController selectTranslationEngine:TranslationEngineTypeBTD];
    self.BTDEngineMenuItem.state = NSControlStateValueOn;
    
    self.tencentEngineMenuItem.state = NSControlStateValueOff;
}

- (void)selectTencentTranslationEngine {
    [self.myViewController selectTranslationEngine:TranslationEngineTypeTencent];
    self.tencentEngineMenuItem.state = NSControlStateValueOn;
    
    self.BTDEngineMenuItem.state = NSControlStateValueOff;
}



@end
