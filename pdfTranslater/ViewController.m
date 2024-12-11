//
//  ViewController.m
//  pdfTranslater
//
//  Created by hwy on 2024/12/5.
//

#import "ViewController.h"
#import <AFNetworking/AFNetworking.h>
#import <Masonry.h>

@interface ViewController()

@property(nonatomic, strong) NSSplitView *splitView;
@property(nonatomic, strong) NSScrollView *pdfContainer;
@property(nonatomic, strong) NSScrollView *translationContainer;
@property (nonatomic, copy) NSString *translationEngine;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // 默认为字节的翻译引擎
    [self selectTranslationEngine:TranslationEngineTypeBTD];
    
    // 左右分屏布局
    self.splitView = [[NSSplitView alloc] initWithFrame:self.view.bounds];
    [self.splitView setDividerStyle:NSSplitViewDividerStyleThin];
    [self.splitView setVertical:YES];
    self.splitView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.splitView.autoresizesSubviews = YES; // 确保子视图大小自动调整

    [self.view addSubview:self.splitView];
    
    // PDF显示区域
    self.pdfContainer = [[NSScrollView alloc] init];
    _pdfView = [[PDFView alloc] initWithFrame:self.pdfContainer.bounds];
    [_pdfView setAutoScales:YES];
    _pdfView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [self.pdfContainer setDocumentView:_pdfView];
    [self.splitView addSubview:self.pdfContainer];
    
    
    // 翻译结果区域
    self.translationContainer = [[NSScrollView alloc] init];
    _translationView = [[NSTextView alloc] initWithFrame:self.translationContainer.bounds];
    [_translationView setEditable:NO];
    [_translationView setFont:[NSFont systemFontOfSize:14]];
    _translationView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    // 为 NSTextView 设置边框
   _translationView.layer = [CALayer layer];  // 创建一个 layer
   _translationView.layer.borderColor = [[NSColor blackColor] CGColor];  // 设置边框颜色
   _translationView.layer.borderWidth = 2.0;  // 设置边框宽度
   _translationView.layer.cornerRadius = 5.0;  // 可选：设置圆角
       
    [self.translationContainer setDocumentView:_translationView];
    [self.splitView addSubview:self.translationContainer];
    
    // 设置初始子视图宽度为平分
    [self adjustSubviewsToSplitEqually];
    
    // 添加“翻译”按钮
    NSButton *translateButton = [[NSButton alloc] init];
    [translateButton setTitle:@"翻译"];
    [translateButton setTarget:self];
    [translateButton setAction:@selector(translateButtonClicked)];
    [self.view addSubview:translateButton];
    [translateButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.size.width.height.equalTo(@50);
        make.left.equalTo(self.pdfContainer.mas_right);
        make.top.equalTo(self.splitView.mas_centerY);
    }];
    
    // 加载默认 PDF 文档
    [self loadDefaultPDF];
}

- (void)viewWillAppear {
    [super viewWillAppear];
    
    // 设置为全屏模式
    [self.view.window toggleFullScreen:nil];
}

- (void)loadDefaultPDF {
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"sample" ofType:@"pdf"];
    [self loadPDFWithPath:filePath];
}

- (void)loadPDFWithPath:(NSString *)filePath {
    PDFDocument *document = [[PDFDocument alloc] initWithURL:[NSURL fileURLWithPath:filePath]];
    [_pdfView setDocument:document];
}



- (void)translateButtonClicked {
    PDFSelection *selection = self.pdfView.currentSelection;
    NSString *selectedTexts = [selection string];
    // 如果没有选中文本
    if (selectedTexts == nil) {
        self.translationView.string = @"没有选中任何文本。";
        return;
    }
    
    [self translateText:selectedTexts];
}

- (void)translateText:(NSString *)text {
    if (text.length == 0) return;
    
    text = [self processText:text];
    
    // 创建 AFHTTPSessionManager 实例
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    
    // 设置请求和响应的序列化方式（如果需要处理 JSON 数据）
    manager.requestSerializer = [AFJSONRequestSerializer serializer];
    manager.responseSerializer = [AFJSONResponseSerializer serializer];
    
    // 设置请求头
    [manager.requestSerializer setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    // API 请求 URL
    NSString *urlString = @"http://127.0.0.1:7119/translate";
    
    // 请求体参数
    NSDictionary *parameters = @{@"text": text, @"target_lang": @"zh",@"engine": self.translationEngine};
    
    // 使用 POST 请求
    [manager POST:urlString parameters:parameters headers:nil progress:nil success:^(NSURLSessionDataTask *task, id responseObject) {
        // 请求成功，处理返回的翻译结果
        NSDictionary *result = (NSDictionary *)responseObject;
        NSString *translatedText = result[@"translatedText"];
        
        // 在主线程更新 UI
        dispatch_async(dispatch_get_main_queue(), ^{
            self.translationView.string = translatedText ?: @"翻译失败";
        });
        
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        // 请求失败，处理错误
        dispatch_async(dispatch_get_main_queue(), ^{
            self.translationView.string = @"翻译失败";
        });
    }];
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}


- (NSString *)processText:(NSString *)text {
    NSMutableString *processedText = [text mutableCopy];
    
    // 遍历字符串，查找 \n，并判断前一个字符
    for (NSInteger i = 1; i < processedText.length; i++) {
        if ([processedText characterAtIndex:i] == '\n') {
            // 如果 \n 前面是 '-'，替换为空字符串
            if ([processedText characterAtIndex:i - 1] == '-') {
                [processedText replaceCharactersInRange:NSMakeRange(i - 1, 2) withString:@""];
                i--; // 调整索引以正确处理下一个字符
            } else {
                // 如果 \n 前面不是 '-'，替换为空格
                [processedText replaceCharactersInRange:NSMakeRange(i, 1) withString:@" "];
            }
        }
    }
    
    return [processedText copy];
}

#pragma mark - NSSplitViewDelegate

// 确保分隔条拖动范围
- (CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMinimumPosition ofSubviewAt:(NSInteger)dividerIndex {
    return 100.0; // 左侧视图最小宽度
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMaximumPosition ofSubviewAt:(NSInteger)dividerIndex {
    return splitView.frame.size.width - 100.0; // 右侧视图最小宽度
}

// 当分隔条调整时调整子视图
- (void)splitViewDidResizeSubviews:(NSNotification *)notification {
    [self adjustSubviewsToSplitEqually];
}

#pragma mark - Helpers

// 设置子视图平分宽度
- (void)adjustSubviewsToSplitEqually {
    CGFloat totalWidth = self.splitView.frame.size.width;
    CGFloat dividerThickness = self.splitView.dividerThickness;
    CGFloat subviewWidth = (totalWidth - dividerThickness) / 2;

    NSRect leftFrame = self.pdfContainer.frame;
    NSRect rightFrame = self.translationContainer.frame;

    leftFrame.size.width = subviewWidth;
    rightFrame.origin.x = subviewWidth + dividerThickness;
    rightFrame.size.width = subviewWidth;

    self.pdfContainer.frame = leftFrame;
    self.translationContainer.frame = rightFrame;
}

#pragma mark - Enter press down

- (void)keyDown:(NSEvent *)event {
    // 检查是否按下 Enter 键
    if (event.keyCode == 36) { // Enter 键
        [self translateButtonClicked]; // 调用绑定的方法
    } else {
        [super keyDown:event]; // 继续处理其他按键事件
    }
}

- (BOOL)acceptsFirstResponder {
    return YES; // 确保窗口可以接收键盘事件
}

#pragma mark - select Translation Engine

- (void)selectTranslationEngine:(TranslationEngineType)engine {
    switch (engine) {
        case TranslationEngineTypeBTD:
            self.translationEngine = @"bytedance";
            break;
        case TranslationEngineTypeTencent:
            self.translationEngine = @"Tencent";
            break;
        default:
            break;
    }
}




@end
