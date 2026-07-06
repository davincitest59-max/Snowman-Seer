# Ocean Baby

Ocean Baby 是一款面向安卓手机的本地优先个人效率软件，当前只交付 Android APK。

当前发布版本：V.1.0.0

## 第一版功能

- 自动记录微信、支付宝收付款通知到账本。
- 自动识别并导入微信、支付宝导出的账单文件。
- 管理笔记、待办事项和每日心情。
- 支持勃艮第红、蒂芙尼蓝、申伦布黄、石墨灰、松针绿主题。

## 本地隐私

所有账本、笔记、待办和心情数据默认保存在当前设备，不上传云端。

## 安卓自动记账

Ocean Baby 通过安卓通知使用权读取微信、支付宝的收付款通知，并在通知出现后自动写入本地账本。首次安装后需要在系统设置中为 Ocean Baby 开启“通知使用权”；微信、支付宝也需要允许显示交易通知。

历史账单可通过微信、支付宝导出的账单文件导入。自动通知记账和文件导入都使用去重指纹，避免同一笔交易反复写入。

## 心情弹框

每日首次打开应用时会询问当天心情，保存后当天不再自动弹出；当天心情仍可在心情页面随时修改。自动弹框可在设置中关闭。

## 环境要求

- Flutter 3.44.0 或更高版本。
- Dart 3.12.0 或更高版本。
- 构建安卓 APK 需要 Android SDK 36。

## 开发运行

```powershell
flutter pub get
flutter test
flutter run -d android
```

## 构建

```powershell
flutter build apk --release
```

安卓 release APK 输出路径：

```text
build\app\outputs\flutter-apk\app-release.apk
```
