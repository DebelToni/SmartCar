#import <Foundation/Foundation.h>

// Protocol for delegate callbacks
@protocol NetworkManagerDelegate <NSObject>
- (void)networkManagerDidFinishRequest:(NSData *)data forURL:(NSURL *)url;
- (void)networkManagerDidFailWithError:(NSError *)error forURL:(NSURL *)url;
@end

@interface NetworkManager : NSObject
@property (nonatomic, weak) id<NetworkManagerDelegate> delegate;
@property (nonatomic, strong) NSOperationQueue *operationQueue;
@property (nonatomic, strong) dispatch_queue_t callbackQueue;

- (void)performRequestWithURL:(NSURL *)url deferredUntil:(NSDate *)deferredDate;
- (void)cancelAllRequests;
@end

@implementation NetworkManager {
    NSMutableDictionary<NSURL *, NSURLSessionDataTask *> *_tasks;
    NSMutableArray<NSURL *> *_deferredRequests;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _operationQueue = [[NSOperationQueue alloc] init];
        _operationQueue.maxConcurrentOperationCount = 4;
        _callbackQueue = dispatch_get_main_queue();
        _tasks = [NSMutableDictionary dictionary];
        _deferredRequests = [NSMutableArray array];
    }
    return self;
}

- (void)performRequestWithURL:(NSURL *)url deferredUntil:(NSDate *)deferredDate {
    if (deferredDate && [deferredDate compare:[NSDate date]] == NSOrderedDescending) {
        @synchronized(self) {
            [_deferredRequests addObject:url];
        }
        // Schedule to check later
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)([deferredDate timeIntervalSinceNow] * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self performRequestWithURL:url deferredUntil:nil];
        });
        return;
    }
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            [self notifyFailure:error forURL:url];
        } else {
            [self notifySuccess:data forURL:url];
        }
        @synchronized(self) {
            [_tasks removeObjectForKey:url];
        }
    }];
    @synchronized(self) {
        _tasks[url] = task;
    }
    [task resume];
}

- (void)cancelAllRequests {
    @synchronized(self) {
        for (NSURL *url in _tasks) {
            NSURLSessionDataTask *task = _tasks[url];
            [task cancel];
        }
        [_tasks removeAllObjects];
    }
}

- (void)notifySuccess:(NSData *)data forURL:(NSURL *)url {
    if ([self.delegate respondsToSelector:@selector(networkManagerDidFinishRequest:forURL:)]) {
        dispatch_async(self.callbackQueue, ^{
            [self.delegate networkManagerDidFinishRequest:data forURL:url];
        });
    }
}

- (void)notifyFailure:(NSError *)error forURL:(NSURL *)url {
    if ([self.delegate respondsToSelector:@selector(networkManagerDidFailWithError:forURL:)]) {
        dispatch_async(self.callbackQueue, ^{
            [self.delegate networkManagerDidFailWithError:error forURL:url];
        });
    }
}

@end
