### 多流-OC

#### 准备工作
1. 在三体云官网SDK下载页 [http://3ttech.cn/index.php?menu=53](http://3ttech.cn/index.php?menu=53) 下载对应平台的 连麦直播SDK。
2. 登录三体云官网 [http://dashboard.3ttech.cn/index/login](http://dashboard.3ttech.cn/index/login) 注册体验账号，进入控制台新建自己的应用并获取APPID。

#### SDK使用
**演示远端用户存在多个摄像头情况下的直播场景**

1. 该demo使用链接framework的方式，参考other link flags

2. 在framework search path添加framework路径

3. 添加系统库：

> 1. libc++.tbd
> 2. libxml2.tbd
> 3. libz.tbd
> 4. libsqlite3.tbd
> 5. ReplayKit.framework
> 6. CoreTelephony.framework
> 7. SystemConfiguration.framework

4. 设置 bitcode=NO

5. 选择后台音频模式

