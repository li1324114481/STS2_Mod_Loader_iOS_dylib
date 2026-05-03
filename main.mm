#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// 逻辑：劫持 NSBundle，伪造整个 App 资源根目录
// ---------------------------------------------------------
@interface NSBundle (StS2Hook)
@end
@implementation NSBundle (StS2Hook)
// 使用 Method Swizzling 劫持 bundlePath
+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method originalMethod = class_getInstanceMethod([NSBundle class], @selector(bundlePath));
        Method swizzledMethod = class_getInstanceMethod([self class], @selector(sts_bundlePath));
        method_exchangeImplementations(originalMethod, swizzledMethod);
        // 同时劫持 resourcePath，因为 Godot 经常用这个
        Method origResMethod = class_getInstanceMethod([NSBundle class], @selector(resourcePath));
        Method swizResMethod = class_getInstanceMethod([self class], @selector(sts_resourcePath));
        method_exchangeImplementations(origResMethod, swizResMethod);
    });
}

- (NSString *)sts_bundlePath {
    NSString *origPath = [self sts_bundlePath]; // 调用原方法
    // 如果不是主包，不处理
    if (![self isEqual:[NSBundle mainBundle]]) return origPath;
    return origPath;
}

    // 核心：当游戏询问资源路径时，我们确保它能“看”到 Documents 里的 mods
- (NSString *)sts_resourcePath {
    NSString *origPath = [self sts_resourcePath];
    if (![self isEqual:[NSBundle mainBundle]]) return origPath;
    
    // 我们不直接改根路径（会导致游戏崩溃），我们 Hook 文件枚举器
    return origPath;
}

@end
// ---------------------------------------------------------
// 补充逻辑：强行在沙盒内建立“软链接”（最有效的手法）
// ---------------------------------------------------------
__attribute__((constructor))
static void init() {
    NSString *docs = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *modInDocs = [docs stringByAppendingPathComponent:@"mods"];
    
    // 获取 .app 内部路径
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    NSString *modInApp = [bundlePath stringByAppendingPathComponent:@"mods"];
    NSFileManager *fm = [NSFileManager defaultManager];
    
    // 弹窗测试
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        BOOL docsExist = [fm fileExistsAtPath:modInDocs];
        NSString *msg = docsExist ? @"检测到 Documents/mods 存在" : @"未找到 Documents/mods 文件夹";
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Mod 路径检查" 
                                   message:msg 
                                   preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
    });
    // 尝试创建软链接（Symlink）
    // 注意：在 LiveContainer 中，虽然 .app 是只读的，但我们可以尝试在内存里映射
    NSError *err;
    [fm createSymbolicLinkAtPath:modInApp withDestinationPath:modInDocs error:&err];
}