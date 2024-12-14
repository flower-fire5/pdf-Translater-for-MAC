//
//  ViewController.m
//  pdfTranslater
//
//  Created by hwy on 2024/12/5.
//

#import "ViewController.h"
#import <AFNetworking/AFNetworking.h>
#import <Masonry.h>

@interface ViewController() <NSTextFieldDelegate>

@property(nonatomic, strong) NSSplitView *splitView;
@property(nonatomic, strong) NSScrollView *pdfContainer;
@property(nonatomic, strong) NSScrollView *translationContainer;
@property (nonatomic, copy) NSString *translationEngine;
@property (nonatomic, strong) NSSearchField *searchField;
@property (nonatomic, strong) NSTextField *searchTextField;
@property (nonatomic, strong) NSButton *closeButton;
@property (nonatomic, strong) NSButton *prevButton;
@property (nonatomic, strong) NSButton *nextButton;
@property (nonatomic, strong) NSTextField *resultLabel;
@property (nonatomic, strong) NSArray<PDFSelection *> *matches;
@property (nonatomic, strong) NSMutableArray<PDFAnnotation *> *highlights;
@property (nonatomic, assign) NSInteger currentMatchIndex;
@property (nonatomic, assign) NSInteger prevMatchIndex;
@property (nonatomic, strong) NSView *searchContainer;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // 默认为字节的翻译引擎
    [self selectTranslationEngine:TranslationEngineTypeBTD];
    
    // 左右分屏布局
    self.splitView = [[NSSplitView alloc] initWithFrame:self.view.bounds];
    [self.splitView setDividerStyle:NSSplitViewDividerStyleThick];
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
    [_translationView setFont:[NSFont systemFontOfSize:16]];
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
    
    // 添加搜索框
    [self setupSearchField];
    
    // 设置快捷键
    [self setupKeyBindings];
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

#pragma mark - 实现快捷键功能
//- (BOOL)performKeyEquivalent:(NSEvent *)event {
//    if (([event modifierFlags] & NSEventModifierFlagCommand) && [event keyCode] == 8) { // cmd + C
//        [self copySelectedText];
//        return YES;
//    }
//    if (([event modifierFlags] & NSEventModifierFlagCommand) && [event keyCode] == 3) { // cmd + F
//        [self toggleSearchBox];
//        return YES;
//    }
//    if (([event modifierFlags] & NSEventModifierFlagCommand) && [event keyCode] == 47) { // cmd + G (Next)
//        [self nextMatch];
//        return YES;
//    }
//    if (([event modifierFlags] & NSEventModifierFlagCommand) && [event keyCode] == 43) { // cmd + Shift + G (Previous)
//        [self previousMatch];
//        return YES;
//    }
//    return [super performKeyEquivalent:event];
//}

- (void)setupKeyBindings {
    // 添加全局快捷键监听
    [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^NSEvent * _Nullable(NSEvent * _Nonnull event) {
        // 检查是否按下 Cmd 键
        BOOL isCommandPressed = (event.modifierFlags & NSEventModifierFlagCommand) != 0;
        BOOL isShiftPressed = (event.modifierFlags & NSEventModifierFlagShift) != 0;
        
        if (isCommandPressed) {
            switch (event.keyCode) {
                case 8: // "C" 键
                    [self copySelectedText];
                    return nil; // 拦截事件
                    
                case 3: // "F" 键
                    [self toggleSearchBox];
                    return nil; // 拦截事件
                    
                case 5: // "G" 键
                    if (isShiftPressed) {
                        [self previousMatch]; // Cmd+Shift+G
                    } else {
                        [self nextMatch]; // Cmd+G
                    }
                    return nil; // 拦截事件
            }
        }
        return event; // 不拦截其他事件
    }];
}

#pragma mark - 复制选中文本

- (void)copySelectedText {
    PDFSelection *selection = self.pdfView.currentSelection;
    if (selection) {
        NSString *selectedText = [selection string];
        if (selectedText.length > 0) {
            // 复制到剪贴板
            NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
            [pasteboard clearContents];
            [pasteboard setString:selectedText forType:NSPasteboardTypeString];
            NSLog(@"Copied: %@", selectedText);
        } else {
            NSLog(@"No text selected to copy.");
        }
    }
}

#pragma mark - 搜索框设置

- (void)setupSearchField {
    // 搜索框容器视图
    NSView *searchContainer = [[NSView alloc] init];
    searchContainer.hidden = YES; // 默认隐藏
    [self.view addSubview:searchContainer];
    
    // 使用 Masonry 布局搜索容器
    [searchContainer mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.pdfView.mas_top); // 与 PDFView 顶部对齐
        make.left.equalTo(self.view.mas_left).offset(20); // 左侧偏移 20
        make.right.equalTo(self.view.mas_right).offset(-20); // 右侧偏移 -20
        make.height.equalTo(@40); // 固定高度
    }];
    
    // 创建搜索框
    self.searchTextField = [[NSTextField alloc] init];
    self.searchTextField.placeholderString = @"Search PDF...";
    self.searchTextField.delegate = self;
    [searchContainer addSubview:self.searchTextField];
    
    [self.searchTextField mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(searchContainer.mas_left); // 左对齐
        make.centerY.equalTo(searchContainer.mas_centerY); // 垂直居中
        make.width.equalTo(@200); // 固定宽度
    }];

    // 创建关闭按钮
    self.closeButton = [[NSButton alloc] init];
    [self.closeButton setTitle:@"Close"];
    [self.closeButton setTarget:self];
    [self.closeButton setAction:@selector(closeSearch)];
    [searchContainer addSubview:self.closeButton];
    
    [self.closeButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.searchTextField.mas_right).offset(10); // 紧跟在搜索框右侧
        make.centerY.equalTo(searchContainer.mas_centerY); // 垂直居中
        make.width.equalTo(@50); // 固定宽度
    }];

    // 创建向前按钮
    self.prevButton = [[NSButton alloc] init];
    [self.prevButton setTitle:@"Prev"];
    [self.prevButton setTarget:self];
    [self.prevButton setAction:@selector(previousMatch)];
    [searchContainer addSubview:self.prevButton];
    
    [self.prevButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.closeButton.mas_right).offset(10); // 紧跟在关闭按钮右侧
        make.centerY.equalTo(searchContainer.mas_centerY); // 垂直居中
        make.width.equalTo(@50); // 固定宽度
    }];

    // 创建向后按钮
    self.nextButton = [[NSButton alloc] init];
    [self.nextButton setTitle:@"Next"];
    [self.nextButton setTarget:self];
    [self.nextButton setAction:@selector(nextMatch)];
    [searchContainer addSubview:self.nextButton];
    
    [self.nextButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.prevButton.mas_right).offset(10); // 紧跟在向前按钮右侧
        make.centerY.equalTo(searchContainer.mas_centerY); // 垂直居中
        make.width.equalTo(@50); // 固定宽度
    }];

    // 创建结果显示标签
    self.resultLabel = [[NSTextField alloc] init];
    self.resultLabel.stringValue = @"0/0";
    self.resultLabel.editable = NO;
    self.resultLabel.bordered = NO;
    self.resultLabel.backgroundColor = [NSColor clearColor];
    self.resultLabel.alignment = NSTextAlignmentCenter; // 居中对齐
    [searchContainer addSubview:self.resultLabel];
    
    [self.resultLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.nextButton.mas_right).offset(10); // 紧跟在向后按钮右侧
        make.centerY.equalTo(searchContainer.mas_centerY); // 垂直居中
        make.width.equalTo(@50); // 固定宽度
    }];
    
    // 保存搜索容器到实例变量（便于显示/隐藏）
    self.searchContainer = searchContainer;
    
    // 初始化搜索结果数组
    self.matches = [NSArray array];
    self.currentMatchIndex = -1;
    self.highlights = [NSMutableArray array];
}

#pragma mark - 搜索框显示/隐藏逻辑

- (void)toggleSearchBox {
    BOOL isSearchBoxVisible = !self.searchContainer.hidden;
    self.searchContainer.hidden = isSearchBoxVisible; // 切换搜索容器可见性
    
    if (!isSearchBoxVisible) {
        // 打开搜索框时，清空之前的高亮
        if (self.matches.count > 0) {
            [self highlightCurrentMatch];
        }else {
            [self clearHighlights];
        }
        // 搜索框获取焦点
        [self.searchTextField becomeFirstResponder];
    } else {
        [self closeSearch];
    }
}

- (void)closeSearch {
    self.searchContainer.hidden = YES; // 隐藏搜索框容器
    [self hideHighlights]; // 清除高亮
}

#pragma mark - 搜索与高亮管理

- (void)clearHighlights {
    // 移除所有高亮标记
    for (PDFAnnotation *highlight in self.highlights) {
        [highlight.page removeAnnotation:highlight];
    }
    [self.highlights removeAllObjects];

    // 清空匹配结果
    self.matches = @[];
    self.currentMatchIndex = -1;
    self.resultLabel.stringValue = @"0/0";
}

- (void)hideHighlights {
    // 移除所有高亮标记
    for (PDFAnnotation *highlight in self.highlights) {
        [highlight.page removeAnnotation:highlight];
    }
    [self.highlights removeAllObjects];
}


- (void)controlTextDidChange:(NSNotification *)notification {
    NSString *searchText = self.searchTextField.stringValue;
    if (searchText.length > 0) {
        [self searchPDFForText:searchText];
    } else {
        [self clearHighlights];
    }
}

- (void)searchPDFForText:(NSString *)searchText {
    [self clearHighlights];
    
    PDFDocument *document = self.pdfView.document;
    self.matches = [document findString:searchText withOptions:NSCaseInsensitiveSearch];
    
    if (self.matches.count > 0) {
        self.currentMatchIndex = 0;
        [self highlightAllMatches]; // 高亮所有匹配内容
        self.resultLabel.stringValue = [NSString stringWithFormat:@"%ld/%ld", (long)(self.currentMatchIndex + 1), (long)self.matches.count];
    } else {
        self.resultLabel.stringValue = @"0/0";
    }
}


- (void)highlightAllMatches {
    for (NSInteger i = 0; i < self.matches.count; i++) {
        PDFSelection *selection = self.matches[i];
        PDFPage *page = selection.pages[0];
        NSRect bounds = [selection boundsForPage:page];
        
        // 设置高亮颜色：当前匹配项为橙色，其他为黄色
        NSColor *highlightColor = (i == self.currentMatchIndex) ? [NSColor orangeColor] : [NSColor yellowColor];
        
        PDFAnnotation *highlight = [[PDFAnnotation alloc] initWithBounds:bounds forType:PDFAnnotationSubtypeHighlight withProperties:nil];
        highlight.color = highlightColor;

        [page addAnnotation:highlight]; // 添加高亮标记
        [self.highlights addObject:highlight];
    }
}

- (void)highlightCurrentMatch {
    // 检查是否需要更新上一个匹配项
    if (self.prevMatchIndex >= 0 && self.prevMatchIndex < self.matches.count) {
        PDFSelection *selection = self.matches[self.prevMatchIndex];
        PDFPage *page = selection.pages[0];
        NSRect bounds = [selection boundsForPage:page];

        // 清除之前的橙色高亮
        if (self.highlights[self.prevMatchIndex]) {
            [page removeAnnotation:self.highlights[self.prevMatchIndex]];
        }

        // 添加黄色高亮
        PDFAnnotation *highlight = [[PDFAnnotation alloc] initWithBounds:bounds forType:PDFAnnotationSubtypeHighlight withProperties:nil];
        highlight.color = [NSColor yellowColor];
        [page addAnnotation:highlight];

        // 更新 highlights 数组
        self.highlights[self.prevMatchIndex] = highlight;
    }

    // 检查是否需要更新当前匹配项
    if (self.currentMatchIndex >= 0 && self.currentMatchIndex < self.matches.count) {
        PDFSelection *selection = self.matches[self.currentMatchIndex];
        PDFPage *page = selection.pages[0];
        NSRect bounds = [selection boundsForPage:page];

        // 清除之前的黄色高亮（如果有）
        if (self.highlights[self.currentMatchIndex]) {
            [page removeAnnotation:self.highlights[self.currentMatchIndex]];
        }

        // 添加橙色高亮
        PDFAnnotation *highlight = [[PDFAnnotation alloc] initWithBounds:bounds forType:PDFAnnotationSubtypeHighlight withProperties:nil];
        highlight.color = [NSColor orangeColor];
        [page addAnnotation:highlight];

        // 更新 highlights 数组
        self.highlights[self.currentMatchIndex] = highlight;

        // 滚动到当前匹配项
        [self.pdfView goToSelection:selection];
    }
}


#pragma mark - 上一项/下一项导航

- (void)nextMatch {
    if (self.matches.count > 0) {
        self.prevMatchIndex = self.currentMatchIndex;
        self.currentMatchIndex = (self.currentMatchIndex + 1) % self.matches.count;
        [self highlightCurrentMatch];
        self.resultLabel.stringValue = [NSString stringWithFormat:@"%ld/%ld", (long)(self.currentMatchIndex + 1), (long)self.matches.count];
    }
}

- (void)previousMatch {
    if (self.matches.count > 0) {
        self.prevMatchIndex = self.currentMatchIndex;
        self.currentMatchIndex = (self.currentMatchIndex - 1 + self.matches.count) % self.matches.count;
        [self highlightCurrentMatch];
        self.resultLabel.stringValue = [NSString stringWithFormat:@"%ld/%ld", (long)(self.currentMatchIndex + 1), (long)self.matches.count];
    }
}




@end
