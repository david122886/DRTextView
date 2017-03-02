# DRTextView
使用Core Text实现一个富文本显示控件，主要支持高亮选中放大镜效果,控件使用很简单。
# 调用代码
```
    CGRect area1 = (CGRect){0,0,CGRectGetWidth(self.view.bounds),300};
    CGRect area2 = (CGRect){0,500,CGRectGetWidth(self.view.bounds),200};
    self.textView = [[DRTextView alloc]
                     initWithFrame:self.view.bounds
                     withAreaRects:@[NSStringFromCGRect(area1),NSStringFromCGRect(area2)]];
//  self.textView = [[DRTextView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:self.textView];
    self.textView.backgroundColor = [UIColor whiteColor];
    self.textView.delegate = self;
```
    
```
    CGRect area1 = (CGRect){0,0,CGRectGetWidth(self.view.bounds),300};
    CGRect area2 = (CGRect){0,500,CGRectGetWidth(self.view.bounds),200};
````

设置富文本显示区域，可以是不连续区域

#效果图
![](/gif1)
    
