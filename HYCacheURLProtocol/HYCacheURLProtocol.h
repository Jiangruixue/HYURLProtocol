//
//  HYCacheURLProtocol.h
//  HYCacheURLProtocol
//
//  Created by 降瑞雪 on 2016/10/31.
//  Copyright © 2016年 汇元网. All rights reserved.

/*
    此框架暂时不支持WKWebView的缓存操作。
 */

#import <Foundation/Foundation.h>

@interface HYCacheURLProtocol : NSURLProtocol

@property (nonatomic,assign) NSTimeInterval cacheExpireInterval; // 缓存过期时间，默认是1小时。
@property (nonatomic,strong) NSURLSessionConfiguration * config; //session配置对象。可以重新修改session配置。

+ (void)cleanupCache; //删除URLCache，当收到内存太高警告时，可以调用此方法，进行删除缓存。
+ (void)startInterceptingRequest; //开始拦截request请求。
+ (void)cancelInterceptingRequest;//取消拦截reques请求。

@end
