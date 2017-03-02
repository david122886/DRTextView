//
//  LSYMagnifierView.m
//  LSYReader
//
//  Created by Labanotation on 16/6/12.
//  Copyright © 2016年 okwei. All rights reserved.
//

#import "LSYMagnifierView.h"

@implementation LSYMagnifierView

- (id)initWithFrame:(CGRect)frame {
    
    if (self = [super initWithFrame:CGRectMake(0, 0, 100, 100)]) {
        self.layer.borderColor = [[UIColor lightGrayColor] CGColor];
//        [self setBackgroundColor:[LSYReadConfig shareInstance].theme];
        self.layer.borderWidth = 1;
        self.layer.cornerRadius = 50;
        self.layer.masksToBounds = YES;
    }
    return self;
}
- (void)setTouchPoint:(CGPoint)touchPoint {
    
    _touchPoint = touchPoint;
    self.center = CGPointMake(touchPoint.x, touchPoint.y - 70);
    [self setNeedsDisplay];
}
- (void)drawRect:(CGRect)rect {
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(context, self.frame.size.width*0.5,self.frame.size.height*0.5);
    CGContextScaleCTM(context, 1.3, 1.3);
    CGContextTranslateCTM(context, -1 * (_touchPoint.x), -1 * (_touchPoint.y));
    [self.readView.layer renderInContext:context];
}

@end
