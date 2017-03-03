//
//  ViewController.m
//  DRTextView
//
//  Created by liudavid on 17/2/10.
//  Copyright © 2017年 liudavid. All rights reserved.
//

#import "ViewController.h"
#import "DRTextView.h"

#define kChapterContent @"猎云注：本文讲述了一位艰难创业者背后，妻子默默支持老公的故事。创业不易，老公与CEO谈股份谈崩，面临净身出户，需要重新找工作的境地。妻子不知道怎么帮老公争股份，不知道该如何跟不讲理的人打交道，于是写下这篇“求职帖”，“如果你们是一个靠谱的团队，想招一个靠谱的技术负责人，我真的觉得我老公是最适合的！”妻子这样说道。文章转自诶诶想你公众号：发现身边，作者：Emily Liu 。"

@interface ViewController ()<DRTextViewDelegate>
@property (strong,nonatomic) DRTextView *textView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.textView = [[DRTextView alloc]
                     initWithFrame:self.view.bounds];
//    self.textView = [[DRTextView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:self.textView];
    self.textView.backgroundColor = [UIColor whiteColor];
    self.textView.delegate = self;
    // Do any additional setup after loading the view, typically from a nib.
    
    
    NSMutableDictionary *attriDic = @{}.mutableCopy;
    attriDic[NSForegroundColorAttributeName] = [UIColor blackColor];
    attriDic[NSFontAttributeName] = [UIFont systemFontOfSize:25];
    attriDic[NSUnderlineColorAttributeName] = [UIColor redColor];
    NSMutableParagraphStyle *paraStyle = [[NSMutableParagraphStyle alloc] init];
    paraStyle.headIndent = 10.0f;//左边距
    paraStyle.tailIndent = CGRectGetWidth(self.view.bounds)-10.0f;//右边距
    paraStyle.firstLineHeadIndent = 100.0f;
    paraStyle.lineSpacing = 20.0f;
    paraStyle.alignment = NSTextAlignmentJustified;
    attriDic[NSParagraphStyleAttributeName] = paraStyle;
    
    NSMutableAttributedString *attriString = [[NSMutableAttributedString alloc] initWithString:kChapterContent];
    [attriString addAttributes:attriDic range:(NSRange){0,kChapterContent.length}];
    [attriString addAttribute:NSForegroundColorAttributeName value:[UIColor blueColor] range:(NSRange){20,10}];
    self.textView.attriString = attriString;
    
    self.textView.dotColor = [UIColor yellowColor];
    self.textView.cursorColor = [UIColor redColor];
    self.textView.selectedBgColor = [UIColor colorWithRed:10/255.0 green:200/255.0 blue:50/255.0 alpha:0.6];
    
    self.textView.chapterName = @"测试测试";
    self.textView.progress = @"69.5%";
    self.textView.bookName = @"测试";
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)textView:(DRTextView*)textView didSelectedStringRange:(NSRange)selectedRange andSelectedRects:(NSArray*)areaRects{
    NSLog(@"%@",[kChapterContent substringWithRange:selectedRange]);
}

-(void)textViewDidCancelSelectedArea:(DRTextView*)textView{
    NSLog(@"textViewDidCancelSelectedArea");
}

@end
