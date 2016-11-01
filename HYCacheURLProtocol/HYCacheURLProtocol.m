//
//  HYCacheURLProtocol.m
//  HYCacheURLProtocol
//
//  Created by 降瑞雪 on 2016/10/31.
//  Copyright © 2016年 汇元网. All rights reserved.
//

#import "HYCacheURLProtocol.h"


@interface HYCacheConfig : NSObject

@property (nonatomic,copy) NSMutableDictionary *cache;
@property (nonatomic,strong)NSOperationQueue *forgeroundNetQueue;
@property (nonatomic,strong) NSOperationQueue * backgroundNetQueue;
@property (nonatomic,strong) NSURLSessionConfiguration * config;

@end

@implementation HYCacheConfig

+(instancetype)shareInstance
{
    static HYCacheConfig * cacheConfig = nil;
    static dispatch_once_t tokenOnce;
    dispatch_once(&tokenOnce, ^{
        cacheConfig = [[HYCacheConfig alloc] init];
    });
    
    return cacheConfig;
}

- (NSMutableDictionary *)cache
{
    if (!_cache) {
        _cache = [NSMutableDictionary dictionary];
    }
    return _cache;
}

- (NSOperationQueue *)forgeroundNetQueue
{
    if (!_forgeroundNetQueue) {
        _forgeroundNetQueue  = [[NSOperationQueue alloc] init];
        _forgeroundNetQueue.maxConcurrentOperationCount = 10; //这只最大并发数10
    }
    return _forgeroundNetQueue;
}

- (NSOperationQueue *)backgroundNetQueue
{
    if (!_backgroundNetQueue) {
        _backgroundNetQueue = [[NSOperationQueue alloc] init];
        _backgroundNetQueue.maxConcurrentOperationCount = 10;
    }
    return _backgroundNetQueue;
}


@end

static NSString * const URLProtocolAlreadyHandleKey = @"alreadyHandle";
static NSString * const checkUpdateInBgKey = @"checkUpdateInBg";
@interface HYCacheURLProtocol ()<NSURLSessionDataDelegate>
{
    NSURLSession * _session;
    NSMutableData * _data;
}

@end

@implementation HYCacheURLProtocol

//开始拦截request请求。
+ (void)startInterceptingRequest
{
    [NSURLProtocol registerClass:[HYCacheURLProtocol class]];
}

//取消拦截reques请求。
+ (void)cancelInterceptingRequest
{
    [NSURLProtocol unregisterClass:[HYCacheURLProtocol class]];
}

//设置缓存过期时间
- (NSTimeInterval)cacheExpireInterval
{
    if (_cacheExpireInterval == 0) {
        _cacheExpireInterval = 3600;
    }
    return _cacheExpireInterval;
}

//清空缓存。
+ (void)cleanupCache
{
    [HYCacheConfig shareInstance].cache = nil;
}

//重新配置config 对象。
- (void)setConfig:(NSURLSessionConfiguration *)config
{
    [HYCacheConfig shareInstance].config = config;
}

//重载这个方法，返回的Bool变量表示否是对当前的request做相关的处理。
+(BOOL)canInitWithRequest:(NSURLRequest *)request
{
    NSString * schemeStr = request.URL.scheme;
    if ([schemeStr caseInsensitiveCompare:@"http"] == NSOrderedSame || [schemeStr caseInsensitiveCompare:@"https"] == NSOrderedSame) {
        if ([NSURLProtocol propertyForKey:URLProtocolAlreadyHandleKey inRequest:request] ||[NSURLProtocol propertyForKey:checkUpdateInBgKey inRequest:request]) {
            return NO;
        }
    }
    return YES;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
    return request;
}

- (void)startLoading
{
    //从NSURLCache 中取出缓存响应体。
    NSCachedURLResponse * cacheResponse = [[NSURLCache sharedURLCache] cachedResponseForRequest:self.request];
    if (cacheResponse) {
        
        NSError * error = nil;
        [self.client URLProtocol:self didReceiveResponse:cacheResponse.response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
        [self.client URLProtocol:self didLoadData:cacheResponse.data];
        [self.client URLProtocolDidFinishLoading:self];
        [self.client URLProtocol:self didFailWithError:error];
        [self backgroundCheckUpdate];
    }
    else {
        //发送request请求。
        [self netRequestWithRequest:self.request];
    }
}

- (void)stopLoading
{
    [_session invalidateAndCancel];
    _session = nil;
}

- (void)backgroundCheckUpdate
{
    __weak typeof(self)weakSelf = self;
    //执行检查缓存更新操作，在子线程中执行，最大并发数为10 。
    [[HYCacheConfig shareInstance].backgroundNetQueue addOperationWithBlock:^{
        //如果当前时间，减去上一次的发送请求的时间，小于一小时，使用缓存response，否则就重新发起请求。
        NSDate * lastUpdateDate = [HYCacheConfig shareInstance].cache[weakSelf.request.URL.absoluteString];
        if (lastUpdateDate){
            //获取当前时间。
            NSDate * currentDate = [NSDate date];
            NSTimeInterval interval = [currentDate timeIntervalSinceDate:lastUpdateDate];
            if (interval > weakSelf.cacheExpireInterval) {
                //缓存已经过期，直接重新发起请求。
                [weakSelf netRequestWithRequest:self.request];
            }
            else {
                NSLog(@"缓存未过期,还可以正常使用");
            }
        }
        else {
            [weakSelf netRequestWithRequest:self.request];
        }
    }];
}

//发送网络请求。
- (void)netRequestWithRequest:(NSURLRequest *)request
{
    NSMutableURLRequest * mutableRequest = [self.request mutableCopy];
    [NSURLProtocol setProperty:@YES forKey:URLProtocolAlreadyHandleKey inRequest:mutableRequest];
    _session = [NSURLSession sessionWithConfiguration:[HYCacheConfig shareInstance].config delegate:self delegateQueue:[HYCacheConfig shareInstance].forgeroundNetQueue];
    NSURLSessionTask * task = [_session dataTaskWithRequest:request];
    [task resume];
    
    //保存发送requeset时间点，这个的作用主要是做缓存过期更新操作。
    [[HYCacheConfig shareInstance].cache setValue:[NSDate date] forKey:request.URL.absoluteString];
}

#pragma mark -- NSURLSessionDataDelegate

//接收到数据。
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    [_data appendData:data];
    [self.client URLProtocol:self didLoadData:data];
}

//收到响应。
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    _data = [NSMutableData data];
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    completionHandler(NSURLSessionResponseAllow);
}

//已经完成。
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    if (error) {
        [self.client URLProtocol:self didFailWithError:error];
    }
    else{
        [self.client URLProtocolDidFinishLoading:self];
        
        if (!_data) {
            return;
        }
        //当本次request 处理结束之后，需要对response 和data进行缓存。
        NSCachedURLResponse * cacheResponse = [[NSCachedURLResponse alloc] initWithResponse:task.response data:_data];
        [[NSURLCache sharedURLCache] storeCachedResponse:cacheResponse forRequest:self.request];
        _data = nil;
    }
}

@end
