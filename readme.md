# 杀戮尖塔2 iOS移植版mod加载器插件



这是一个ai项目。



**暂时不支持带有dll文件的mod的运行。**



从release里获取本dylib插件，在你的LiveContainer的"**模块**"页新建文件夹，将该dylib文件导入。

再在lc的塔2的软件设置里指定加载你新建的模块文件夹即可。



接下来，打开游戏的数据文件夹（长按软件后弹窗选择），在Documents下新建mods文件夹，将你的mod按文件夹分别导入即可。



游戏启动后会弹窗显示*“检测到 Documents/mods 存在”* 

此时代表插件注入成功，且mod被识别。

## 开源协议
本项目采用 [MIT License](LICENSE) 开源协议。
