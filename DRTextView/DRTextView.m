//
//  DRTextView.m
//  DRTextView
//
//  Created by liudavid on 17/2/10.
//  Copyright © 2017年 liudavid. All rights reserved.
//

#import "DRTextView.h"
#import <CoreText/CoreText.h>
#import "LSYMagnifierView.h"
/*
typedef NS_ENUM(NSInteger,DragDirection) {
    DragDirection_none,
    ///从起点往上拖
    DragDirection_fromStartToUp,
    ///从起点往下拖
    DragDirection_fromStartToDown,
};
*/
///touch选中拖动逻辑处理
typedef struct{
    CFRange startLineRange;
    CFRange selectedRange;
    CFRange startCharRange;
} TouchCtr;

@interface DRTextView(){
    CTFrameRef textCTFrame;
    CGPoint movePoint;
    TouchCtr touchCtr;///CFRange必须初始化，不然默认值为0
    BOOL touchMoved,panCanWork;
    CFRange oldSelectedRange;///记录点击选中区域,区别单击点中是已经选中区域/新区域,新区域没有移动时需要选中整行
    CGAffineTransform transform;
}
///坐标系是Core Text左下角为原点坐标系
@property (strong,nonatomic) NSArray *stringRects;
@property (nonatomic,strong) LSYMagnifierView *magnifierView;
@end

@implementation DRTextView

-(instancetype)initWithFrame:(CGRect)frame{
    return [self initWithFrame:frame withAreaRects:@[NSStringFromCGRect((CGRect){0,kPageFooterH,frame.size.width,frame.size.height - kPageFooterH-kPageHeaderH})]];
}

-(instancetype)initWithFrame:(CGRect)frame withAreaRects:(NSArray*)areaRects{
    self = [super initWithFrame:frame];
    if (self) {
        touchCtr.startLineRange = touchCtr.selectedRange = CFRangeMake(kCFNotFound, 0);
        touchCtr.startCharRange = CFRangeMake(kCFNotFound, 0);
        
        _areaRectsArr = areaRects;
        
        transform = CGAffineTransformTranslate(CGAffineTransformIdentity, 0, self.bounds.size.height);
        transform = CGAffineTransformScale(transform, 1.0, -1.0);
        
        _dotColor = [UIColor purpleColor];
        _cursorColor = [UIColor yellowColor];
        _selectedBgColor = [UIColor colorWithRed:100/255.0 green:20/255.0 blue:50/255.0 alpha:0.5];
        
        _pageHeaderFooterColor = [UIColor blackColor];
        _pageHeaderFooterFont = [UIFont systemFontOfSize:10];
        
        _progress = @"0%";
        
        _longGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longCurrentViewGesture:)];
        //        _longGesture.numberOfTapsRequired = 1;///长按手势设置这个值后没有反应
        _longGesture.numberOfTouchesRequired = 1;
        [self addGestureRecognizer:_longGesture];
        
        _panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panCurrentViewGesture:)];
        _panGesture.maximumNumberOfTouches = 1;
        _panGesture.enabled = NO;
        [self addGestureRecognizer:_panGesture];
        
        ///设置电池监听有效
        [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
    }
    return self;
}

#pragma mark - 手势

-(void)beginLongGesture:(UILongPressGestureRecognizer*)gesture
              withPoint:(CGPoint)point
         withTouchPoint:(CGPoint)touchPoint{

    CFRange selectedLineRange;
    CFRange range = [self parseTypedCharRangeWithFrame:textCTFrame
                                          withPosition:point
                                          outLineRange:&selectedLineRange];
    touchMoved = NO;
    oldSelectedRange = CFRangeMake(kCFNotFound, 0);
    
    if (range.location != kCFNotFound) {
        if (touchCtr.selectedRange.location != kCFNotFound) {
            CFRange startCharRange = [self calStartCharRangeWithSelectedRange:touchCtr.selectedRange withPointRange:range];
            if (startCharRange.location != kCFNotFound) {
                CFRange unionRange = touchCtr.selectedRange;
                touchCtr.selectedRange = unionRange;
                touchCtr.startLineRange = unionRange;
                touchCtr.startCharRange = startCharRange;
                touchMoved = YES;///不需要自动高亮一整行
                self.stringRects = [self parseStringRectsWithFrame:textCTFrame withRange:unionRange];
            }else{
                ///没有交集时touchCtr.selectedRange值被替换
                oldSelectedRange = touchCtr.selectedRange;
                touchCtr.startLineRange = selectedLineRange;
                touchCtr.selectedRange = range;
                touchCtr.startCharRange = range;
                self.stringRects = [self parseStringRectsWithFrame:textCTFrame withRange:range];
            }
        }else{
            oldSelectedRange = touchCtr.selectedRange;
            touchCtr.startLineRange = selectedLineRange;
            touchCtr.selectedRange = range;
            touchCtr.startCharRange = range;
            self.stringRects = [self parseStringRectsWithFrame:textCTFrame withRange:range];
        }
        
        
        [self setNeedsDisplay];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showMagnifier];
                [self.magnifierView setTouchPoint:[self convertPoint:touchPoint toView:self.superview]];
            });
        });
    }else{
        touchCtr.startLineRange = CFRangeMake(kCFNotFound, 0);
        touchCtr.selectedRange = CFRangeMake(kCFNotFound, 0);
        touchCtr.startCharRange = CFRangeMake(kCFNotFound, 0);
        self.stringRects = nil;
        [self setNeedsDisplay];
    }
    
    
}

-(void)changedLongGesture:(UILongPressGestureRecognizer*)gesture
                withPoint:(CGPoint)point
           withTouchPoint:(CGPoint)touchPoint{

    CFRange range = [self parseTypedCharRangeWithFrame:textCTFrame
                                          withPosition:point
                                          outLineRange:nil];
    if (range.location != kCFNotFound) {
        if (touchCtr.selectedRange.location == kCFNotFound) {
            touchCtr.selectedRange = range;
            touchCtr.startCharRange = range;
            touchCtr.startLineRange = CFRangeMake(kCFNotFound, 0);
            self.stringRects = [self parseStringRectsWithFrame:textCTFrame withRange:range];
        }else{
            CFRange selectedRange = CFRangeUnionRange(touchCtr.startCharRange, range);
            touchCtr.selectedRange = selectedRange;
            self.stringRects = [self parseStringRectsWithFrame:textCTFrame withRange:selectedRange];
        }
        [self setNeedsDisplay];
    }
    
    [self.magnifierView setTouchPoint:[self convertPoint:touchPoint toView:self.superview]];
    
    touchMoved = YES;
}

-(void)endLongGesture:(UILongPressGestureRecognizer*)gesture
            withPoint:(CGPoint)point
       withTouchPoint:(CGPoint)touchPoint{
    [self hiddenMagnifier];
    if (!touchMoved && oldSelectedRange.location != kCFNotFound) {
        touchCtr.selectedRange = touchCtr.startLineRange;
        self.stringRects = [self parseStringRectsWithFrame:textCTFrame withRange:touchCtr.startLineRange];
        [self setNeedsDisplay];
    }
    if (touchCtr.selectedRange.location != kCFNotFound) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(textView:didSelectedStringRange:andSelectedRects:)]) {
            [self.delegate textView:self didSelectedStringRange:(NSRange){touchCtr.selectedRange.location,touchCtr.selectedRange.length} andSelectedRects:self.stringRects];
        }
    }
}

///长按手势
-(void)longCurrentViewGesture:(UILongPressGestureRecognizer*)gesture{
//    NSLog(@"longCurrentViewGesture");
    
    CGPoint point,transPoint;
    point = [gesture locationInView:self];
    transPoint =  CGPointApplyAffineTransform(point, transform);///注意坐标系必须在一个坐标系内
    
    if (gesture.state == UIGestureRecognizerStateBegan) {
        self.panGesture.enabled = NO;
        [self beginLongGesture:gesture withPoint:transPoint withTouchPoint:point];
    }else
    if (gesture.state == UIGestureRecognizerStateChanged) {
        [self changedLongGesture:gesture withPoint:transPoint withTouchPoint:point];
    }else
    if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled || gesture.state == UIGestureRecognizerStateFailed) {
        [self endLongGesture:gesture withPoint:transPoint withTouchPoint:point];
        self.panGesture.enabled = YES;
    }
}


-(void)beginPanGesture:(UIPanGestureRecognizer*)gesture
                withPoint:(CGPoint)point
        withTouchPoint:(CGPoint)touchPoint{
    if (touchCtr.selectedRange.location == kCFNotFound) {
        panCanWork = NO;
        return ;
    }

    CFRange range = [self parseTypedCharRangeWithFrame:textCTFrame
                                          withPosition:point
                                          outLineRange:nil];
    if (range.location == kCFNotFound) {
        panCanWork = NO;
        return ;
    }
    CFRange startCharRange = [self calStartCharRangeWithSelectedRange:touchCtr.selectedRange withPointRange:range];
    if (startCharRange.location == kCFNotFound) {
        panCanWork = NO;
        return ;
    }
    CFRange selectedRange = CFRangeUnionRange(startCharRange, range);
    touchCtr.selectedRange = selectedRange;
    touchCtr.startLineRange = selectedRange;
    touchCtr.startCharRange = startCharRange;
    self.stringRects = [self parseStringRectsWithFrame:textCTFrame withRange:selectedRange];
    
    [self setNeedsDisplay];
    panCanWork = YES;
    return ;
}
-(void)changedPanGesture:(UIPanGestureRecognizer*)gesture
               withPoint:(CGPoint)point
          withTouchPoint:(CGPoint)touchPoint{
    
    CFRange range = [self parseTypedCharRangeWithFrame:textCTFrame
                                          withPosition:point
                                          outLineRange:nil];
    if (range.location != kCFNotFound) {
        CFRange selectedRange = CFRangeUnionRange(touchCtr.startCharRange, range);
        touchCtr.selectedRange = selectedRange;
        self.stringRects = [self parseStringRectsWithFrame:textCTFrame withRange:selectedRange];
        [self setNeedsDisplay];
    }
    [self showMagnifier];
    [self.magnifierView setTouchPoint:[self convertPoint:touchPoint toView:self.superview]];
    
}

-(void)endPanGesture:(UIPanGestureRecognizer*)gesture
               withPoint:(CGPoint)point
          withTouchPoint:(CGPoint)touchPoint{
    [self hiddenMagnifier];
    if (touchCtr.selectedRange.location != kCFNotFound) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(textView:didSelectedStringRange:andSelectedRects:)]) {
            [self.delegate textView:self didSelectedStringRange:(NSRange){touchCtr.selectedRange.location,touchCtr.selectedRange.length} andSelectedRects:self.stringRects];
        }
    }
}

///拖动手势
-(void)panCurrentViewGesture:(UIPanGestureRecognizer*)gesture{
    //    NSLog(@"panCurrentViewGesture");
    
    CGPoint point,transPoint;
    point = [gesture locationInView:self];
    transPoint =  CGPointApplyAffineTransform(point, transform);///注意坐标系必须在一个坐标系内
    
    if (gesture.state == UIGestureRecognizerStateBegan) {
        self.longGesture.enabled = NO;
        [self beginPanGesture:gesture withPoint:transPoint withTouchPoint:point];
    }else
        if (panCanWork && gesture.state == UIGestureRecognizerStateChanged) {
            [self changedPanGesture:gesture withPoint:transPoint withTouchPoint:point];
        }else
            if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled || gesture.state == UIGestureRecognizerStateFailed) {
                if (panCanWork) {
                    [self endPanGesture:gesture withPoint:transPoint withTouchPoint:point];
                }
                self.longGesture.enabled = YES;
            }
}


#pragma mark - 画内容
- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
   
    if (self.attriString) {
        CGContextSaveGState(context);
        
        CGContextTranslateCTM(context, 0, self.bounds.size.height);
        CGContextScaleCTM(context, 1.0, -1.0);
        
        [self drawSectionArea];
        
        ///path 设置文字显示区域，可以是多个不连续独立区域，作用是用于控制内容排版
        CGMutablePathRef path = CGPathCreateMutable();
        if (self.areaRectsArr.count <= 0) {
            CGPathAddRect(path, NULL, (CGRect){0,0,rect.size.width,rect.size.height});
        }else{
            for (NSString *strRect in self.areaRectsArr) {
                CGPathAddRect(path, NULL, CGRectFromString(strRect));
            }
        }
        
        CTFramesetterRef setterRef = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)self.attriString);
        if (textCTFrame) {
            CFRelease(textCTFrame);
            textCTFrame = NULL;
        }
        textCTFrame = CTFramesetterCreateFrame(setterRef, CFRangeMake(0, self.attriString.length), path, NULL);
        CTFrameDraw(textCTFrame, context);
        
        CFRelease(setterRef);
        CGPathRelease(path);
        if (self.stringRects.count > 0) {
            [self drawSectionDot];
        }
        CGContextRestoreGState(context);
    }
    
    CGContextSaveGState(context);
    [self drawPageHeader];
    [self drawPageFooter];
    CGContextRestoreGState(context);
    

}

///画高亮选中区域
-(void)drawSectionArea{
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGMutablePathRef sectionPath = CGPathCreateMutable();
    for (NSString *rectStr in self.stringRects) {
        CGPathAddRect(sectionPath, NULL, CGRectFromString(rectStr));
    }
    CGContextAddPath(context, sectionPath);///path加入上下文
    [self.selectedBgColor set];
    CGContextFillPath(context);///开始画path
    CGPathRelease(sectionPath);
}

///画选中区域边界
-(void)drawSectionDot{
    ///坐标系统原点在左下角
    CGContextRef context = UIGraphicsGetCurrentContext();
    int dotW = 2;
    CGRect left,right,leftSecRect,rightSecRect;
    leftSecRect = CGRectFromString([self.stringRects firstObject]);
    rightSecRect = CGRectFromString([self.stringRects lastObject]);
    left = (CGRect){CGRectGetMinX(leftSecRect)-dotW/2,CGRectGetMinY(leftSecRect),dotW,CGRectGetHeight(leftSecRect)};
    right = (CGRect){CGRectGetMaxX(rightSecRect)-dotW/2,CGRectGetMinY(rightSecRect),dotW,CGRectGetHeight(rightSecRect)};
    [self.cursorColor set];
    CGContextFillRect(context, left);
    CGContextFillRect(context, right);
    
    [self.dotColor set];
    CGContextFillEllipseInRect(context,(CGRect){left.origin.x - dotW*1.5,CGRectGetMaxY(left),dotW*4,dotW*4});
    CGContextFillEllipseInRect(context,(CGRect){right.origin.x - dotW*1.5,CGRectGetMinY(right)-dotW*4,dotW*4,dotW*4});
}

///章节名
-(void)drawPageHeader{
    if (!self.chapterName || [self.chapterName isEqualToString:@""]) {
        return;
    }
    CGRect headerRect = (CGRect){0,0,CGRectGetWidth(self.bounds),kPageHeaderH};
    [self.chapterName drawInRect:headerRect withAttributes:@{NSForegroundColorAttributeName:self.pageHeaderFooterColor,NSFontAttributeName:self.pageHeaderFooterFont}];
    
    
}
///画页脚，进度，书籍名，时间，电池
-(void)drawPageFooter{
    CGFloat progressW = 50,batteryW = 20,space = 10,dateStringW = 30;
    ///百分比
    CGRect progressRect = (CGRect){space,CGRectGetHeight(self.bounds)-kPageFooterH,progressW,kPageFooterH};
    
    ///执行会翻转坐标系统
    [self.progress drawInRect:progressRect withAttributes:@{NSForegroundColorAttributeName:self.pageHeaderFooterColor,NSFontAttributeName:self.pageHeaderFooterFont}];
    
    ///书籍名
    if (self.bookName && ![self.bookName isEqualToString:@""]) {
        CGFloat w = CGRectGetWidth(self.bounds) - progressW - batteryW - dateStringW - space*4;
        CGFloat centerX = CGRectGetMaxX(progressRect) + space + w/2;
        CGSize size = [self.bookName sizeWithAttributes:@{NSForegroundColorAttributeName:self.pageHeaderFooterColor,NSFontAttributeName:self.pageHeaderFooterFont}];
        if (size.width > w) {
            size.width = w;
        }
        CGRect strRect = (CGRect){centerX-size.width/2,CGRectGetHeight(self.bounds)-kPageFooterH,size.width,kPageFooterH};
        [self.bookName drawInRect:strRect withAttributes:@{NSForegroundColorAttributeName:self.pageHeaderFooterColor,NSFontAttributeName:self.pageHeaderFooterFont}];
    }
    
    ///时间和电池
    [self drawBatteryAndDateWithDateStrW:dateStringW withBatteryW:batteryW];
}


///画电池和时间
-(void)drawBatteryAndDateWithDateStrW:(CGFloat)dateStringW withBatteryW:(CGFloat)batteryW{
    CGRect rect = self.bounds;
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    NSDateFormatter *formmatter = [[NSDateFormatter alloc] init];
    [formmatter setDateFormat:@"HH:mm"];
    
    NSString *date = [formmatter stringFromDate:[NSDate date]];
    float originY = rect.size.height - kPageFooterH;

    
    float dateStringX = rect.size.width - 70;
    float dateStringH = 15;
    
    NSMutableParagraphStyle *percentStyle = [[NSMutableParagraphStyle alloc] init];
    percentStyle.alignment = NSTextAlignmentLeft;
    percentStyle.lineBreakMode = NSLineBreakByTruncatingTail;
    
    NSDictionary *textAttributedic = @{NSForegroundColorAttributeName:self.pageHeaderFooterColor,NSFontAttributeName:self.pageHeaderFooterFont};

    [date drawInRect:(CGRect){dateStringX,originY,dateStringW,dateStringH} withAttributes:textAttributedic];
    
    ///画电池
    int batteryX = rect.size.width - 35;
    int batteryH = 9;
    int batteryY = originY +2;
    //    [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
    float level = [[UIDevice currentDevice] batteryLevel];
    float batteryLevel = fabsf(level);
    CGContextSetFillColorWithColor(context, self.pageHeaderFooterColor.CGColor);
    CGContextSetLineWidth(context, 0.5);
    CGContextStrokeRect(context, (CGRect){batteryX,batteryY,batteryW,batteryH});
    CGContextFillRect(context, (CGRect){batteryX+batteryW+1,batteryY+2,2,batteryH/2});
    CGContextFillRect(context, (CGRect){batteryX+1,batteryY+1,batteryW*batteryLevel >= batteryW-2?batteryW-2:batteryW*batteryLevel,batteryH-2});
}
/*
>>>>>>> gesture_added
- (void)drawRect:(CGRect)rect {
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextTranslateCTM(context, 0, self.bounds.size.height);
    CGContextScaleCTM(context, 1.0, -1.0);
    
    CGMutablePathRef path = CGPathCreateMutable();
//    CGPathAddRect(path, NULL, (CGRect){50,100,rect.size.width-100,rect.size.height-100});
    ///path 设置文字显示区域，可以是多个不连续独立区域，作用是用于控制内容排版
    
    CGPathAddRect(path, NULL, (CGRect){0,0,rect.size.width,rect.size.height/3});
    
    CGPathAddRect(path, NULL, (CGRect){0,rect.size.height/3*2,rect.size.width,rect.size.height/3});
    
    
    CFMutableAttributedStringRef attriArr = CFAttributedStringCreateMutable(kCFAllocatorDefault, 0);
    CFAttributedStringReplaceString(attriArr, CFRangeMake(0, 0), (CFStringRef)kChapterContent);
    
    ///字体颜色
    CFAttributedStringSetAttribute(attriArr, CFRangeMake(0, kChapterContent.length), kCTForegroundColorAttributeName, [UIColor greenColor].CGColor);
    CFAttributedStringSetAttribute(attriArr, CFRangeMake(0, 10), kCTForegroundColorAttributeName, [UIColor purpleColor].CGColor);
    ///字体
    CTFontRef ctfont = CTFontCreateWithName(CFSTR("Georgia"), 30.0, NULL);
    CFAttributedStringSetAttribute(attriArr, CFRangeMake(0, kChapterContent.length), kCTFontAttributeName, ctfont);
    CFRelease(ctfont);
    ///下划线
    CFAttributedStringSetAttribute(attriArr, CFRangeMake(0, kChapterContent.length), kCTUnderlineColorAttributeName, [UIColor redColor].CGColor);
    CFAttributedStringSetAttribute(attriArr, CFRangeMake(0, kChapterContent.length), kCTUnderlineStyleAttributeName,(CFNumberRef)@(kCTUnderlineStyleSingle));
    
    ///段落设置
    CTParagraphStyleSetting lineLeftIndent;///段落左边距
    CGFloat indent = 40.0f;
    lineLeftIndent.spec = kCTParagraphStyleSpecifierHeadIndent;
    lineLeftIndent.value = &indent;
    lineLeftIndent.valueSize = sizeof(CGFloat);
    
    CTParagraphStyleSetting lineRightIndent;///段落右边距
    CGFloat rightIndent = CGRectGetWidth(rect)-indent;
    lineRightIndent.spec = kCTParagraphStyleSpecifierTailIndent;
    lineRightIndent.value = &rightIndent;
    lineRightIndent.valueSize = sizeof(CGFloat);
    
    
    CTParagraphStyleSetting firstLineHeadIndent;//首行缩进
    CGFloat firstIndent = 100.0f;
    firstLineHeadIndent.spec = kCTParagraphStyleSpecifierFirstLineHeadIndent;
    firstLineHeadIndent.value = &firstIndent;
    firstLineHeadIndent.valueSize = sizeof(CGFloat);
    
    ///行距
    CGFloat _linespace = 20.0f;
    CTParagraphStyleSetting lineSpaceSetting;
    lineSpaceSetting.spec = kCTParagraphStyleSpecifierMinimumLineSpacing;
    lineSpaceSetting.value = &_linespace;
    lineSpaceSetting.valueSize = sizeof(CGFloat);
    
    CTParagraphStyleSetting paragrapAlignment;
    CTTextAlignment paragrapNatural = kCTTextAlignmentJustified; //对齐方式
    paragrapAlignment.spec = kCTParagraphStyleSpecifierAlignment;
    paragrapAlignment.value = &paragrapNatural;
    paragrapAlignment.valueSize = sizeof(CTTextAlignment);
    
//    ///行高
//    CGFloat MutiHeight = 2.0f;
//    CTParagraphStyleSetting Muti;
//    Muti.spec = kCTParagraphStyleSpecifierLineHeightMultiple;
//    Muti.value = &MutiHeight;
//    Muti.valueSize = sizeof(CGFloat);
    
    CTParagraphStyleSetting setting[] = {lineLeftIndent,firstLineHeadIndent,lineSpaceSetting,paragrapAlignment,lineRightIndent};
    CTParagraphStyleRef paragraph = CTParagraphStyleCreate(setting, 5);
    CFAttributedStringSetAttribute(attriArr, CFRangeMake(0, kChapterContent.length), kCTParagraphStyleAttributeName, paragraph);
    
   


    CTFramesetterRef frameSetter = CTFramesetterCreateWithAttributedString((CFAttributedStringRef)attriArr);
    
    if (textCTFrame) {
        CFRelease(textCTFrame);
        textCTFrame = NULL;
    }
    
    textCTFrame = CTFramesetterCreateFrame(frameSetter, CFRangeMake(0, 0), path, NULL);
    
    
    if (self.stringRects) {
        CGMutablePathRef selectedPath = CGPathCreateMutable();
        for (NSString *str in self.stringRects) {
            CGPathAddRect(selectedPath, NULL,CGRectFromString(str));
        }
        CGContextAddPath(context, selectedPath);
        CGContextFillPath(context);
        CGPathRelease(selectedPath);
    }
    
    CTFrameDraw(textCTFrame, context);

    
    
    ////////////////////////////////////////////////////
    CFArrayRef lines = CTFrameGetLines(textCTFrame);
    CFIndex lineCount = CFArrayGetCount(lines);
    CGPoint *origins = (CGPoint*)malloc(lineCount*sizeof(CGPoint));
    CTFrameGetLineOrigins(textCTFrame, CFRangeMake(0, 0), origins);
    CGRect pathBounds = CGPathGetBoundingBox(path);///排版区域
    
    [[UIColor purpleColor] set];
    CGContextSetLineWidth(context, 2);
    
    
    if (rectPath) {
        CGPathRelease(rectPath);
        rectPath = NULL;
    }
    
    ///core text 接口涉及到坐标系统原点都在左下角
    
    rectPath = CGPathCreateMutable();
    
    for (CFIndex index  = 0; index < lineCount; index++) {
        CTLineRef line = CFArrayGetValueAtIndex(lines, index);
        CGPoint origin = origins[index];///x表示line开始,坐标原点在左下角
        CGRect lineRect = [self parseLineRectWithLine:line
                                        withLineOrigin:origin
                                   withFramePathBounds:pathBounds
                                          outLineGrap:nil
                                            outAscent:nil
                                           outDescent:nil
                                         outLineWidth:nil];
        
//        CGContextStrokeRect(context, lineRect);
        CGPathAddRect(rectPath, NULL, lineRect);
        
    }
//    CGContextPathContainsPoint(<#CGContextRef  _Nullable c#>, <#CGPoint point#>, <#CGPathDrawingMode mode#>)
//    CGContextGetPathCurrentPoint(<#CGContextRef  _Nullable c#>)
    CGContextAddPath(context, rectPath);///必须把path加入上下文，才能绘制
    CGContextStrokePath(context);
    ////////////////////////////////////////////////////

    
    
    
    [[UIColor orangeColor] set];
    CGContextFillRect(context, (CGRect){movePoint,10,10});
    
    CFRelease(frameSetter);
    CGPathRelease(path);
    CFRelease(paragraph);
    CFRelease(attriArr);
    free(origins);
}
*/

#pragma mark - 单击事件

///UIGesture拦截手势后，此回调不会调用
-(void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    [super touchesEnded:touches withEvent:event];
    if (self.stringRects.count > 0) {
        touchCtr.startLineRange = CFRangeMake(kCFNotFound, 0);
        touchCtr.selectedRange = CFRangeMake(kCFNotFound, 0);
        touchCtr.startCharRange = CFRangeMake(kCFNotFound, 0);
        self.stringRects = nil;
        [self setNeedsDisplay];
        if (self.delegate && [self.delegate respondsToSelector:@selector(textViewDidCancelSelectedArea:)]) {
            [self.delegate textViewDidCancelSelectedArea:self];
        }
    }
}

#pragma mark - 放大镜 Magnifier View
-(void)showMagnifier
{
    if (!_magnifierView) {
        self.magnifierView = [[LSYMagnifierView alloc] init];
        self.magnifierView.readView = self;
        [self.superview addSubview:self.magnifierView];
    }
}
-(void)hiddenMagnifier
{
    if (_magnifierView) {
        [self.magnifierView removeFromSuperview];
        self.magnifierView = nil;
    }
}

#pragma mark - 新思路，接口之间数据通过stringRange传递

/**
 * @brief 获取每行frame
 *
 * @param  line 行对象
 * @param  origin 每一行起始点(frame origin)
 * @param  pathBounds frame排版区域
 *
 * @return 返回当前行frame
 */
-(CGRect)parseLineRectWithLine:(CTLineRef)line
                withLineOrigin:(CGPoint)origin
           withFramePathBounds:(CGRect)pathBounds
                   outLineGrap:(CGFloat *)pleading
                     outAscent:(CGFloat *)pAscent
                    outDescent:(CGFloat *)pDescent
                  outLineWidth:(CGFloat *)pLineWidth{
    CGFloat ascent,descent,leading,lineWidth;
    lineWidth = CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
    /*
     CGRect lineRect = CTLineGetBoundsWithOptions(line, kCTLineBoundsExcludeTypographicLeading);
     rect.origin.y = origin.y-descent + pathBounds.origin.y;
     rect.origin.x = origin.x + pathBounds.origin.x;
     */
    ///line frame 都是相对行origin + 整个排版区域计算
    CGFloat x = origin.x + pathBounds.origin.x;
    CGFloat y = origin.y-descent + pathBounds.origin.y;
    CGFloat height = ascent+descent+leading;
    
    if(pleading)*pleading = leading;
    if(pAscent)*pAscent = ascent;
    if(pDescent)*pDescent = descent;
    if(pLineWidth)*pLineWidth = lineWidth;
    
    return (CGRect){x,y,lineWidth,height};
}


/**
 * @brief 通过position获取stringrange
 *
 * @param  ctframe CTFrameRef
 * @param  point 鼠标点位置，坐标系统原点在左下角
 * @param  pLineRange 输出所在行字符串范围
 *
 * @return point所在位置字符在整页字符串范围
 */
-(CFRange)parseTypedCharRangeWithFrame:(CTFrameRef)ctframe
                          withPosition:(CGPoint)point
                          outLineRange:(CFRange*)pLineRange{
    
    CFArrayRef lines = CTFrameGetLines(ctframe);
    CFIndex lineCount = CFArrayGetCount(lines);
    
    CGPathRef path = CTFrameGetPath(ctframe);
    CGPoint *origins = malloc(lineCount*sizeof(CGPoint));
    CTFrameGetLineOrigins(ctframe, CFRangeMake(0, 0), origins);
    CGRect pathBounds = CGPathGetBoundingBox(path);///排版区域
    
    CTLineRef selectedLine = NULL;
    CGPoint origin;
    CGFloat descent = 0.0f;
    
    for (CFIndex index = 0; index < lineCount; index++) {
        CGPoint tmpOrigin = origins[index];
        CTLineRef line = CFArrayGetValueAtIndex(lines, index);
        CGRect lineRect = [self parseLineRectWithLine:line
                                       withLineOrigin:tmpOrigin
                                  withFramePathBounds:pathBounds
                                          outLineGrap:nil
                                            outAscent:nil
                                           outDescent:&descent
                                         outLineWidth:nil];
        ///注意坐标系必须在一个坐标系内
        if (CGRectContainsPoint(lineRect,point)) {
            selectedLine = line;
            origin = tmpOrigin;
            break;
        }
    }
    
    CFRange charRange = CFRangeMake(kCFNotFound, 0);
    
    if (selectedLine) {
        CFRange lineRange = CTLineGetStringRange(selectedLine);
        ///CTLineGetStringIndexForPosition position参数是相当当前行初始点origin相当坐标，
        ///测试发现鼠标定位字符前半部分能获取正确下标，鼠标定位字符后半部分获取是下一个字符下标
        CGFloat rangeOffset = CTLineGetStringIndexForPosition(selectedLine,(CGPoint){point.x - origin.x,point.y - origin.y});
        
        CGFloat xStart,xEnd;
        if (rangeOffset < lineRange.location + lineRange.length) {
            xStart = CTLineGetOffsetForStringIndex(selectedLine, rangeOffset, NULL);
            xEnd = CTLineGetOffsetForStringIndex(selectedLine,rangeOffset+1, NULL);
        }else{
            xStart = CTLineGetOffsetForStringIndex(selectedLine, rangeOffset-1, NULL);
            xEnd = CTLineGetOffsetForStringIndex(selectedLine,rangeOffset, NULL);
        }
        
        rangeOffset = CTLineGetStringIndexForPosition(selectedLine,(CGPoint){point.x - origin.x - (xEnd - xStart)/2,point.y - origin.y});
        
        if (rangeOffset < lineRange.location + lineRange.length) {
            
            
            charRange = CFRangeMake(rangeOffset, 1);
            if (pLineRange) {
                *pLineRange = lineRange;
            }
            /*
            ///offset也是相对于line origin计算的
            CGFloat xStart,xEnd;
            xStart = CTLineGetOffsetForStringIndex(selectedLine, rangeOffset, NULL);
            xEnd = CTLineGetOffsetForStringIndex(selectedLine,rangeOffset+1, NULL);
            //    CGRect lineBounds = CTLineGetBoundsWithOptions(line, kCTLineBoundsExcludeTypographicLeading);
            CGRect typedRect = (CGRect){xStart+origin.x,origin.y-descent,xEnd-xStart<=0?4:xEnd-xStart,lineRect.size.height};
            if (pCharRect) {
                *pCharRect = typedRect;
            }
            */
        }
        
    }
    free(origins);
    return charRange;
}

/*
///通过stringrange获取char Rect
-(CGRect)parseTypedCharRectWithFrame:(CTFrameRef)ctframe
                           withRange:(CFRange)stringRange{
    NSArray *stringRects = [self parseStringRectsWithFrame:ctframe withRange:stringRange];
    if (stringRects && stringRects.count == 1) {
        return CGRectFromString([stringRects firstObject]);
    }
    return CGRectZero;
}
*/

/**
 * @brief 根据字符范围获取CGRect
 *
 * @param  ctframe CTFrameRef
 * @param  origin 所在行原点
 * @param  line 所在行
 * @param  pathBounds 排版区域
 * @param  strRange 指定字符范围
 *
 * @return 指定字符串所对应CGRect
 */
-(CGRect)parseSelectedRectInLineWithWithFrame:(CTFrameRef)ctframe
                                   withOrigin:(CGPoint)origin
                                  withlineRef:(CTLineRef)line
                          withFramePathBounds:(CGRect)pathBounds
                                 withStrRange:(CFRange)strRange{
    
    if (!ctframe || !line || strRange.location == kCFNotFound) {
        return CGRectZero;
    }
    
    CFRange lineRange = CTLineGetStringRange(line);
    CFRange needRange = CFRangeIntersectionRange(lineRange, strRange);

    if (needRange.location == kCFNotFound) {
        return CGRectZero;
    }
    CGFloat lineWidth,descent;
    CGRect lineRect = [self parseLineRectWithLine:line
                                   withLineOrigin:origin
                              withFramePathBounds:pathBounds
                                      outLineGrap:nil
                                        outAscent:nil
                                       outDescent:&descent
                                     outLineWidth:&lineWidth];

    CGFloat xStart,xEnd;
    
    ///CTLineGetStringIndexForPosition position参数是相当当前行初始点origin相当坐标，
    ///测试发现鼠标定位字符前半部分能获取正确下标，鼠标定位字符后半部分获取是下一个字符下标
    ///offset也是相对于line origin计算的
    xStart = CTLineGetOffsetForStringIndex(line, needRange.location, NULL);
    xEnd = CTLineGetOffsetForStringIndex(line,CFRangeGetMax(needRange), NULL);
    return (CGRect){xStart+origin.x,origin.y-descent,xEnd-xStart,lineRect.size.height};
}
/**
 * @brief 通过stringrange获取所有行Rect
 *
 * @param  ctframe CTFrameRef
 * @param  stringRange 字符串在整页内范围
 *
 * @return 跨多行字符串对应CGRect数组
 */

-(NSArray*)parseStringRectsWithFrame:(CTFrameRef)ctframe
                           withRange:(CFRange)stringRange{
    if (stringRange.location == kCFNotFound || stringRange.length <= 0) {
        return nil;
    }
    
    CFArrayRef lines = CTFrameGetLines(ctframe);
    CFIndex lineCount = CFArrayGetCount(lines);
    CGPoint *origins = malloc(lineCount*sizeof(CGPoint));
    CTFrameGetLineOrigins(ctframe, CFRangeMake(0, 0), origins);
    CGPathRef path = CTFrameGetPath(ctframe);
    
    NSMutableArray *rectArr = @[].mutableCopy;
    for (CFIndex index = 0; index < lineCount; index++) {
        CTLineRef line = CFArrayGetValueAtIndex(lines, index);
        CGRect selectedRec = [self parseSelectedRectInLineWithWithFrame:ctframe withOrigin:origins[index] withlineRef:line withFramePathBounds:CGPathGetBoundingBox(path)  withStrRange:stringRange];
        if (!CGRectEqualToRect(selectedRec, CGRectZero)) {
            selectedRec = CGRectOffset(selectedRec, 0, kPageFooterH);
            [rectArr addObject:NSStringFromCGRect(selectedRec)];
        }
    }

    free(origins);
    return rectArr.count > 0?rectArr:nil;
}

///计算选中区域起始点（选中区域是起始区域和结束区域合集）
-(CFRange)calStartCharRangeWithSelectedRange:(CFRange)selectedRange
                                     withPointRange:(CFRange)pointRange{
    if (CFRangeEqualRange(pointRange,selectedRange)) {
        return CFRangeMake(pointRange.location, 1);///包括相等和包含
    }
    
    if (CFRangeContainRange(selectedRange, pointRange)) {
        if (CFRangeGetMax(selectedRange) - CFRangeGetMax(pointRange)  > CFRangeGetMin(pointRange) - CFRangeGetMin(selectedRange)) {
            return CFRangeMake(CFRangeGetMax(selectedRange)-1, 1);
        }else{
            return CFRangeMake(CFRangeGetMin(selectedRange), 1);
        }
    }
    if (CFRangeContainRange(pointRange,selectedRange)) {
        return CFRangeMake(CFRangeGetMin(pointRange), 1);
    }
    return CFRangeMake(kCFNotFound, 1);
}

-(void)dealloc{
    CFRelease(textCTFrame);
}
@end
