#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface NSBundle (StS2Hook)
@end

@implementation NSBundle (StS2Hook)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method originalBundle = class_getInstanceMethod([NSBundle class], @selector(bundlePath));
        Method swizzledBundle = class_getInstanceMethod([self class], @selector(sts_bundlePath));
        method_exchangeImplementations(originalBundle, swizzledBundle);
        
        Method originalRes = class_getInstanceMethod([NSBundle class], @selector(resourcePath));
        Method swizzledRes = class_getInstanceMethod([self class], @selector(sts_resourcePath));
        method_exchangeImplementations(originalRes, swizzledRes);
    });
}

// 核心：构建伪造的资源目录
- (NSString *)getFakeBundlePath:(NSString *)realPath {
    NSString *docs = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    // 🔥 这里去掉了 .app 后缀，变成普通的文件夹名
    NSString *fakeBundlePath = [docs stringByAppendingPathComponent:@"FakeBundle_Data"];
    NSString *modsPath = [docs stringByAppendingPathComponent:@"mods"];
    NSFileManager *fm = [NSFileManager defaultManager];

    if (![fm fileExistsAtPath:modsPath]) {
        [fm createDirectoryAtPath:modsPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    if (![fm fileExistsAtPath:fakeBundlePath]) {
        [fm createDirectoryAtPath:fakeBundlePath withIntermediateDirectories:YES attributes:nil error:nil];
    }

    // 软链接所有原包文件
    NSArray *items = [fm contentsOfDirectoryAtPath:realPath error:nil];
    for (NSString *item in items) {
        if ([item isEqualToString:@"mods"]) continue;
        NSString *dest = [fakeBundlePath stringByAppendingPathComponent:item];
        if (![fm fileExistsAtPath:dest]) {
            NSString *src = [realPath stringByAppendingPathComponent:item];
            [fm createSymbolicLinkAtPath:dest withDestinationPath:src error:nil];
        }
    }

    // 软链接 mods 文件夹
    NSString *fakeModsDest = [fakeBundlePath stringByAppendingPathComponent:@"mods"];
    if (![fm fileExistsAtPath:fakeModsDest]) {
        [fm createSymbolicLinkAtPath:fakeModsDest withDestinationPath:modsPath error:nil];
    }

    return fakeBundlePath;
}

- (NSString *)sts_bundlePath {
    NSString *origPath = [self sts_bundlePath];
    if (![self isEqual:[NSBundle mainBundle]]) return origPath;
    return [self getFakeBundlePath:origPath];
}

- (NSString *)sts_resourcePath {
    NSString *origPath = [self sts_resourcePath];
    if (![self isEqual:[NSBundle mainBundle]]) return origPath;
    return [self getFakeBundlePath:origPath];
}

@end

// ---------------------------------------------------------
// 启动检测与强行建夹
// ---------------------------------------------------------
__attribute__((constructor))
static void sts2_loader_init() {
    NSString *docs = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *fakeBundlePath = [docs stringByAppendingPathComponent:@"FakeBundle_Data"];
    NSString *modsPath = [docs stringByAppendingPathComponent:@"mods"];
    NSFileManager *fm = [NSFileManager defaultManager];

    // 强行创建
    [fm createDirectoryAtPath:modsPath withIntermediateDirectories:YES attributes:nil error:nil];
    [fm createDirectoryAtPath:fakeBundlePath withIntermediateDirectories:YES attributes:nil error:nil];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"MOD 加载成功" 
                                   message:@"文件夹已生成，请在文件App中放入MOD" 
                                   preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"起飞" style:UIAlertActionStyleDefault handler:nil]];
        
        UIWindow *keyWindow = nil;
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            if (window.isKeyWindow) { keyWindow = window; break; }
        }
        [keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
    });
}
