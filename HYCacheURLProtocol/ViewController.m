//
//  ViewController.m
//  HYCacheURLProtocol
//
//  Created by 降瑞雪 on 2016/10/31.
//  Copyright © 2016年 汇元网. All rights reserved.
//

#import "ViewController.h"
#import "HYCacheURLProtocol.h"

@interface ViewController ()<UIWebViewDelegate>

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    /*
     不支持 WKWebView URL缓存机制。。
     */
    //使用方法，在开启webview的时候开启监听，，销毁weibview的时候取消监听，否则监听还在继续。将会监听所有的网络请求
    [HYCacheURLProtocol startInterceptingRequest];
    
    UIWebView  *webview = [[UIWebView alloc] initWithFrame:self.view.bounds];
    webview.delegate = self;
    [self.view addSubview:webview];
    NSURL *URL = [NSURL URLWithString:@"https://www.baidu.com"];
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:URL];
    [webview loadRequest:request];
    NSLog(@"cache directory---%@", NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0]);
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{

}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{

}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    NSLog(@"error:: %@",error.description);
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    return YES;
}

- (void)dealloc{
    
    //在不需要用到webview的时候即使的取消监听
    [HYCacheURLProtocol cancelInterceptingRequest];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    [HYCacheURLProtocol cleanupCache];
    // Dispose of any resources that can be recreated.
}


@end
