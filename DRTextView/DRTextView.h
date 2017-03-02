//
//  DRTextView.h
//  DRTextView
//
//  Created by liudavid on 17/2/10.
//  Copyright © 2017年 liudavid. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

NS_INLINE NSString *NSStringFromCFRange(CFRange range){
    if (range.location == kCFNotFound) {
        return @"";
    }
    return [NSString stringWithFormat:@"%ld#%ld",range.location,range.length];
}

NS_INLINE CFRange CFRangeFromString(NSString *str){
    if (!str || [str isEqualToString:@""]) {
        return CFRangeMake(kCFNotFound, 0);
    }
    CFRange range = CFRangeMake(kCFNotFound, 0);
    NSArray *arr = [str componentsSeparatedByString:@"#"];
    if (arr.count == 2) {
        range.location = [arr[0] longValue];
        range.length = [arr[1] longValue];
    }
    return range;
}

///最大值
NS_INLINE CFIndex CFRangeGetMax(CFRange range){
    return range.location + range.length;
}
///最小值
NS_INLINE CFIndex CFRangeGetMin(CFRange range){
    return range.location;
}

///包含,r1是否包含r2
NS_INLINE BOOL CFRangeContainRange(CFRange r1,CFRange r2){
    if (r1.location == kCFNotFound || r2.location == kCFNotFound) {
        return NO;
    }
    if (CFRangeGetMin(r2) >= CFRangeGetMin(r1) && CFRangeGetMax(r2) <= CFRangeGetMax(r1)) {
        return YES;
    }
    return NO;
}

///相等
NS_INLINE BOOL CFRangeEqualRange(CFRange r1,CFRange r2){
    if (r1.location == r2.location && r1.length == r2.length) {
        return YES;
    }
    return NO;
}

///合集
NS_INLINE CFRange CFRangeUnionRange(CFRange r1,CFRange r2){
    if (r1.location == kCFNotFound || r2.location == kCFNotFound) {
        return CFRangeMake(kCFNotFound, 0);
    }
    CFRange range;
    range.location = CFRangeGetMin(r1) >= CFRangeGetMin(r2)?r2.location:r1.location;
    range.length = CFRangeGetMax(r1) > CFRangeGetMax(r2)?(CFRangeGetMax(r1)-range.location):(CFRangeGetMax(r2)-range.location);
    return range;
}
///交集
NS_INLINE CFRange CFRangeIntersectionRange(CFRange r1,CFRange r2){
    if (r1.location == kCFNotFound || r2.location == kCFNotFound) {
        return CFRangeMake(kCFNotFound, 0);
    }
    CFRange range;
    range.location = CFRangeGetMin(r1) >= CFRangeGetMin(r2)?r1.location:r2.location;
    range.length = CFRangeGetMax(r1) > CFRangeGetMax(r2)?(CFRangeGetMax(r2)-range.location):(CFRangeGetMax(r1)-range.location);
    if (range.length <= 0) {
        return CFRangeMake(kCFNotFound, 0);
    }
    return range;
}
/*
///补集 flag:包含关系时 -1 取左边，0 取最大值，1 取右边
NS_INLINE CFRange CFRangeSupplementaryRange(CFRange r1,CFRange r2,int flag){
    if (r1.location == kCFNotFound || r2.location == kCFNotFound) {
        return CFRangeMake(kCFNotFound, 0);
    }
    if (CFRangeEqualRange(r1,r2)) {
        return CFRangeMake(kCFNotFound, 0);
    }
    
    if (CFRangeContainRange(selectedRange, pointRange)) {
        if (CFRangeGetMax(selectedRange) - CFRangeGetMax(pointRange)  > CFRangeGetMin(pointRange) - CFRangeGetMin(selectedRange)) {
            
            return CFRangeMake(pointRange.location, CFRangeGetMax(selectedRange) - CFRangeGetMin(pointRange));
        }else{
            return CFRangeMake(selectedRange.location, CFRangeGetMax(pointRange) - CFRangeGetMin(selectedRange));
        }
    }
    return range;
}
*/


@class DRTextView;
@protocol DRTextViewDelegate <NSObject>
-(void)textView:(DRTextView*)textView didSelectedStringRange:(NSRange)selectedRange andSelectedRects:(NSArray*)areaRects;
-(void)textViewDidCancelSelectedArea:(DRTextView*)textView;
@end

@interface DRTextView : UIView
@property (weak,nonatomic) id<DRTextViewDelegate> delegate;
@property (strong,nonatomic,readonly) UILongPressGestureRecognizer *longGesture;
@property (strong,nonatomic,readonly) UIPanGestureRecognizer *panGesture;
///整个文本区域字符串
@property (strong,nonatomic,readonly) NSArray *areaRectsArr;

///游标小圆点颜色
@property (strong,nonatomic) UIColor *dotColor;
///游标颜色
@property (strong,nonatomic) UIColor *cursorColor;
///选中区域背景色
@property (strong,nonatomic) UIColor *selectedBgColor;
///显示文本
@property (strong,nonatomic) NSAttributedString *attriString;
-(instancetype)initWithFrame:(CGRect)frame withAreaRects:(NSArray*)areaRects;

@end
