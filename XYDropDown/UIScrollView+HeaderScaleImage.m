
//
//  UIScrollView+HeaderScaleImage.m
//  下拉放大
//
//  Created by xiyang on 2017/2/7.
//  Copyright © 2017年 xiyang. All rights reserved.
//

#import "UIScrollView+HeaderScaleImage.h"
#import <objc/runtime.h>

#define YZKeyPath(objc,keyPath) @(((void)objc.keyPath,#keyPath))

/**
 分类的目的：实现两个方法实现的交换，调用原有方法，用现有方法（自己实现方法）的实现。
 */
@interface NSObject (MethodSwizzling)


/**
 交换对象方法

 @param origSelector 原有方法
 @param swizzleSelector 现有方法
 */
+(void)yz_swizzleInstanceSelector:(SEL)origSelector
                  swizzleSelector:(SEL)swizzleSelector;


/**
 交换类方法

 @param origSelector 原有方法
 @param swizzleSelector 现有方法
 */
+(void)yz_swizzleClassSelector:(SEL)origSelector
               swizzleSelector:(SEL)swizzleSelector;


@end


@implementation NSObject(MethodSwizzling)

+(void)yz_swizzleInstanceSelector:(SEL)origSelector
                  swizzleSelector:(SEL)swizzleSelector{
    
    //获取原有方法
    Method origMethod = class_getInstanceMethod(self, origSelector);
    
    //获取交换方法
    Method swizzleMethod = class_getClassMethod(self, swizzleSelector);
    //添加原有方法实现为当前方法
    BOOL isAdd = class_addMethod(self, origSelector, method_getImplementation(swizzleMethod), method_getTypeEncoding(swizzleMethod));
    
    if (!isAdd) {//添加方法失败，原有方法存在，直接替换
        method_exchangeImplementations(origMethod, swizzleMethod);
    }else{
        class_replaceMethod(self, swizzleSelector, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
    }
    
}
+(void)yz_swizzleClassSelector:(SEL)origSelector
               swizzleSelector:(SEL)swizzleSelector{
    //获取原有方法
    Method origMethod = class_getClassMethod(self, origSelector);
    Method swizzleMethod = class_getClassMethod(self, swizzleSelector);
    
    BOOL isAdd = class_addMethod(self, origSelector, method_getImplementation(swizzleMethod), method_getTypeEncoding(swizzleMethod));
    
    if (!isAdd) {
        method_exchangeImplementations(origMethod, swizzleMethod);
    }
    
    
}
@end


static char * const headerImageViewKey = "headerImageViewKey";
static char * const headerImageViewHeight = "headerImageViewHeight";
static char * const isInitialKey = "isInitialkey";
// 默认图片高度
static CGFloat const oriImageH = 200;
@implementation UIScrollView (HeaderScaleImage)

+(void)load{
    [self yz_swizzleInstanceSelector:@selector(setTableHeaderView:) swizzleSelector:@selector(setYz_TableHeaderView:)];
}

//拦截 通过代码设置tableview头部视图
-(void)setYz_TableHeaderView:(UIView *)tableHeaderView{
    
    if (![self isMemberOfClass:[UITableView class]]) {
        return;
    }
    //设置tableView 头部视图
    [self setYz_TableHeaderView:tableHeaderView];
    
    //设置头部视图的位置
    UITableView *tableView = (UITableView *)self;
    
    self.yz_headerScaleImageHeight = tableView.tableHeaderView.frame.size.height;
    
}


-(UIImageView *)yz_headerImageView{
    
    UIImageView *imageView = objc_getAssociatedObject(self, headerImageViewKey);
    if (imageView == nil) {
        imageView = [[UIImageView alloc] init];
        imageView.clipsToBounds = YES;
        imageView.contentMode = UIViewContentModeScaleToFill;
        [self insertSubview:imageView atIndex:0];
        
        //保存imageview
        
        objc_setAssociatedObject(self, headerImageViewKey, imageView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
    }
    return  imageView;
    
}

-(void)setYz_headerScaleImageHeight:(CGFloat)yz_headerScaleImageHeight{
    objc_setAssociatedObject(self, headerImageViewHeight, @(yz_headerScaleImageHeight), OBJC_ASSOCIATION_COPY_NONATOMIC);
    
    
    //设置头部视图的位置
    
    [self setupHeaderImageViewFrame];
}

-(CGFloat)yz_headerScaleImageHeight{
    
    CGFloat headerImageHeight = [objc_getAssociatedObject(self, headerImageViewHeight)floatValue];
    return headerImageHeight == 0?oriImageH:headerImageHeight;
    
}

// 属性：yz_headerImage
-(UIImage *)yz_headerScaleImage{
    return  self.yz_headerImageView.image;
}

-(void)setYz_headerScaleImage:(UIImage *)yz_headerScaleImage{
    self.yz_headerImageView.image = yz_headerScaleImage;
    //初始化头部视图
    [self setupheaderImageView];
}



//设置头部视图的位置
-(void)setupHeaderImageViewFrame{
    
    self.yz_headerImageView.frame = CGRectMake(0, 0, self.bounds.size.width, self.yz_headerScaleImageHeight);
}
  //初始化头部视图
-(void)setupheaderImageView{
    //设置头部视图的位置
    
    [self setupHeaderImageViewFrame];
    
    //KVO监听偏移量，修改头部imageview的frame
    if (self.yz_isInitial == NO) {
        [self addObserver:self forKeyPath:YZKeyPath(self , contentOffset) options:NSKeyValueObservingOptionNew context:nil];
        self.yz_isInitial = YES;
    }
    
}


// 属性：yz_isInitial
- (BOOL)yz_isInitial
{
    return [objc_getAssociatedObject(self, isInitialKey) boolValue];
}
- (void)setYz_isInitial:(BOOL)yz_isInitial
{
    objc_setAssociatedObject(self, isInitialKey, @(yz_isInitial),OBJC_ASSOCIATION_ASSIGN);
}


-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context{
    CGFloat offsetY = self.contentOffset.y;
    if (offsetY < 0) {
        self.yz_headerImageView.frame = CGRectMake(offsetY, offsetY, self.bounds.size.width - offsetY * 2, self.yz_headerScaleImageHeight - offsetY);
    }else{
        self.yz_headerImageView.frame = CGRectMake(0, 0, self.bounds.size.width, self.yz_headerScaleImageHeight);
    }
}

-(void)dealloc{
    if (self.yz_isInitial) {//初始化过，就表示有监听contentOffset属性，才要移除
        [self removeObserver:self forKeyPath:YZKeyPath(self, contentOffset)];
        
    }
}





@end
