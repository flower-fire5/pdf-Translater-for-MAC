//
//  ViewController.h
//  pdfTranslater
//
//  Created by hwy on 2024/12/5.
//

#import <Cocoa/Cocoa.h>
#import <PDFKit/PDFKit.h>

typedef NS_ENUM(NSUInteger, TranslationEngineType) {
    TranslationEngineTypeBTD,
    TranslationEngineTypeTencent
};

@interface ViewController : NSViewController
@property (nonatomic, strong) PDFView *pdfView;
@property (nonatomic, strong) NSTextView *translationView;

- (void)loadPDFWithPath:(NSString *)filePath;
- (void)selectTranslationEngine:(TranslationEngineType)engine;


@end

