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

// 核心：构建伪造的 Bundle 目录
- (NSString *)getFakeBundlePath:(NSString *)realPath {
    NSString *docs = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *fakeBundlePath = [docs stringByAppendingPathComponent:@"FakeBundle.app"];
    NSString *modsPath = [docs stringByAppendingPathComponent:@"mods"];
    NSFileManager *fm = [NSFileManager defaultManager];

    // 1. 确保 Documents/mods 存在（玩家放 Mod 的地方）
    if (![fm fileExistsAtPath:modsPath]) {
        [fm createDirectoryAtPath:modsPath withIntermediateDirectories:YES attributes:nil error:nil];
    }

    // 2. 确保假的 FakeBundle.app 存在
    if (![fm fileExistsAtPath:fakeBundlePath]) {
        [fm createDirectoryAtPath:fakeBundlePath withIntermediateDirectories:YES attributes:nil error:nil];
    }

    // 3. 将真实 .app 里的所有文件软链接到 FakeBundle.app 中
    NSArray *items = [fm contentsOfDirectoryAtPath:realPath error:nil];
    for (NSString *item in items) {
        if ([item isEqualToString:@"mods"]) continue; // 忽略真实包里可能存在的 mods 文件夹
        
        NSString *dest = [fakeBundlePath stringByAppendingPathComponent:item];
        if (![fm fileExistsAtPath:dest]) {
            NSString *src = [realPath stringByAppendingPathComponent:item];
            [fm createSymbolicLinkAtPath:dest withDestinationPath:src error:nil];
        }
    }

    // 4. 将 Documents/mods 软链接到 FakeBundle.app/mods
    NSString *fakeModsDest = [fakeBundlePath stringByAppendingPathComponent:@"mods"];
    if (![fm fileExistsAtPath:fakeModsDest]) {
        [fm createSymbolicLinkAtPath:fakeModsDest withDestinationPath:modsPath error:nil];
    }

    // 返回伪造的路径欺骗游戏引擎
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
// 启动弹窗检测
// ---------------------------------------------------------
__attribute__((constructor))
static void init() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSString *docs = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        NSString *modsPath = [docs stringByAppendingPathComponent:@"mods"];
        BOOL docsExist = [[NSFileManager defaultManager] fileExistsAtPath:modsPath];
        
        NSString *msg = docsExist ? @"Mod 引擎加载成功\n请在『文件』App中管理 Documents/mods" : @"初始化失败";
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"STS2 Mod Loader" 
                                   message:msg 
                                   preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        
        // 更安全的获取 RootViewController 的方式
        UIWindow *keyWindow = nil;
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            if (window.isKeyWindow) {
                keyWindow = window;
                break;
            }
        }
        [keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
    });
}
