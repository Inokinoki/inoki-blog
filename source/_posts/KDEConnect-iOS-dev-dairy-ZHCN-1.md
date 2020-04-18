---
title: KDE Connect iOS 开发日记(1)
date: 2020-04-18 22:20:30
tags:
- KDE Connect
- 中文
- 翻译
categories:
- KDE Connect
- [Translation, Chinese]
---

# 处理依赖

KDE Connect iOS 项目使用 [CocoaPods](https://cocoapods.org/) 来管理依赖:

### COCOAPODS 是什么
CocoaPods 是 Swift 和 Objective-C Cocoa 项目的依赖项管理器。 它拥有超过 7.2 万个库，并在超过300万个应用程序中使用。 CocoaPods可以帮助您优雅地扩展项目。

与 CocoaPods 有关的文件是 `Podfile`，它指定了这个项目面向的 iOS 的版本 `(7.0)`，依赖的名称、版本和源：

```
platform :ios, '7.0'
pod 'CocoaAsyncSocket', '~> 7.3.5'
pod 'MRProgress'
pod 'InAppSettingsKit', '~> 2.1'
pod 'VTAcknowledgementsViewController'
pod 'XbICalendar', :podspec => 'https://raw.githubusercontent.com/libical/XbICalendar/master/XbICalendar.podspec'
pod 'MYBlurIntroductionView'
```

构建的第一步就是安装这些依赖。在安装了 CocoaPods 之后，我根据官方文档运行了 `pod install`，但是出现了问题：

```
$ pod install
Analyzing dependencies
Fetching podspec for `XbICalendar` from `https://raw.githubusercontent.com/libical/XbICalendar/master/XbICalendar.podspec`
Downloading dependencies
Installing CocoaAsyncSocket (7.3.5)
Installing InAppSettingsKit (2.15)
Installing MRProgress (0.8.3)
Installing MYBlurIntroductionView (1.0.3)
Installing VTAcknowledgementsViewController (1.5.2)
Installing XbICalendar (0.3.3)
Generating Pods project
Integrating client projects
[!] Could not automatically select an Xcode workspace. Specify one in your Podfile like so:

    workspace 'path/to/Workspace.xcworkspace'


[!] The abstract target Pods is not inherited by a concrete target, so the following dependencies won't make it into any targets in your project:
    - CocoaAsyncSocket (~> 7.3.5)
    - InAppSettingsKit (~> 2.1)
    - MRProgress
    - MYBlurIntroductionView
    - VTAcknowledgementsViewController
    - XbICalendar (from `https://raw.githubusercontent.com/libical/XbICalendar/master/XbICalendar.podspec`)

[!] The platform of the target `Pods` (iOS 7.0) may not be compatible with `InAppSettingsKit (2.15)` which has a minimum requirement of iOS 8.0.

[!] The platform of the target `Pods` (iOS 7.0) may not be compatible with `VTAcknowledgementsViewController (1.5.2)` which has a minimum requirement of iOS 8.0 - tvOS 9.0.
```

看起来有一些 bug 要修了 :)

## 修复 Bug

```
[!] Could not automatically select an Xcode workspace. Specify one in your Podfile like so:

    workspace 'path/to/Workspace.xcworkspace'
```

在这个项目中，`.xcworkspace` 文件对应的是 `kdeconnect-ios.xcworkspace`。所以我在文件中添加了 `workspace 'kdeconnect-ios'` 一句。

```
[!] The platform of the target `Pods` (iOS 7.0) may not be compatible with `InAppSettingsKit (2.15)` which has a minimum requirement of iOS 8.0.

[!] The platform of the target `Pods` (iOS 7.0) may not be compatible with `VTAcknowledgementsViewController (1.5.2)` which has a minimum requirement of iOS 8.0 - tvOS 9.0.
```

很明显，这个输出指出，目标的系统版本需要升级。为了方便，我直接把它升级到了 `platform :ios, '12.0'`。

```
[!] The abstract target Pods is not inherited by a concrete target, so the following dependencies won't make it into any targets in your project:
    ...
```

这个消息则说明 `pods`(对应依赖的概念) 没有指定目标项目。根据 CocoaPod 的文档，我应当添加 `target "kdeconnect-ios"` 并把所有的 pods 放在一个 `do ... end` 结构中。

## 最终版本 Podfile

最终，`Podfile` 文件变成了：

```
workspace 'kdeconnect-ios'
target "kdeconnect-ios" do

platform :ios, '12.0'
pod 'CocoaAsyncSocket', '~> 7.3.5'
pod 'MRProgress'
pod 'InAppSettingsKit', '~> 2.1'
pod 'VTAcknowledgementsViewController'
pod 'XbICalendar', :podspec => 'https://raw.githubusercontent.com/libical/XbICalendar/master/XbICalendar.podspec'
pod 'MYBlurIntroductionView'

end
```

修复过后，输出正常了起来：

```
$ pod install
Analyzing dependencies
Downloading dependencies
Generating Pods project
Integrating client project
Pod installation complete! There are 6 dependencies from the Podfile and 6 total pods installed.
```

# 使用 XCode 构建

既然安装依赖部分已经没有问题了，使用 XCode 编译构建它就变得顺理成章了（虽然 XCode 是世界最差 IDE 没有之一）。

## 应用程序标识符

第一个问题出现在我点击 `Build` 按钮的时候：

{% asset_img error-identifier.png Identifier error %}

```
Failed to register bundle identifier.
The app identifier "application-identifier" cannot be registered to your development team. Change your bundle identifier to a unique string to try again.
```

Apple 试图为我的 Apple 帐号和这个应用程序生成一个自签名证书。但它没法处理现在这个格式的标识符。

因此我把标识符改成了 `org.kde.kdeconnect.ios`，然后点击 `Try again`，这次，自签名证书生成成功。

## Multiple commands produce

紧接着，我重新开始构建。另一个 bug 就出现了：

{% asset_img error-multiple-commands-produce.png Language file error %}

```
Multiple commands produce '/Users/inoki/Library/Developer/Xcode/DerivedData/kdeconnect-ios-hhcvmcgjatxxdugxbjbrwgotfgna/Build/Products/Debug-iphoneos/kdeconnect-ios.app/zh-Hans.lproj/Localizable.strings':
1) Target 'kdeconnect-ios' (project 'kdeconnect-ios') has copy command from '/Users/inoki/Projects/kdeconnect-ios-test/kdeconnect-ios/zh-Hans.lproj/Localizable.strings' to '/Users/inoki/Library/Developer/Xcode/DerivedData/kdeconnect-ios-hhcvmcgjatxxdugxbjbrwgotfgna/Build/Products/Debug-iphoneos/kdeconnect-ios.app/zh-Hans.lproj/Localizable.strings'
2) Target 'kdeconnect-ios' (project 'kdeconnect-ios') has copy command from '/Users/inoki/Projects/kdeconnect-ios-test/kdeconnect-ios/zh-Hans.lproj/Localizable.strings' to '/Users/inoki/Library/Developer/Xcode/DerivedData/kdeconnect-ios-hhcvmcgjatxxdugxbjbrwgotfgna/Build/Products/Debug-iphoneos/kdeconnect-ios.app/zh-Hans.lproj/Localizable.strings'
```

我参考了这个在 GitHub 上的 [issue](https://github.com/CocoaPods/CocoaPods/issues/7949#issuecomment-427636746)，把构建系统更改为 legacy：

{% asset_img error-multiple-commands-produce-fix.png Language file error %}

## 缺失的头文件

接着，另一个错误出现了：

{% asset_img error-header-not-found.png Missing header %}

```
kdeconnect-ios/AppSettingViewController.m:27:9: 'IASKPSTitleValueSpecifierViewCell.h' file not found
```

这个问题可能是某个依赖版本升级导致的，直接移除这行：

```
#import "IASKPSTitleValueSpecifierViewCell.h"
```

## 库链接错误，禁用 Bitcode

之后，我再次重新构建，又一个问题出现了：

{% asset_img error-bitcode.png Bitcode %}

```
ld: '/Users/inoki/Projects/kdeconnect-ios-test/Pods/XbICalendar/libical/lib/libical.a(icalcomponent.c.o)' does not contain bitcode. You must rebuild it with bitcode enabled (Xcode setting ENABLE_BITCODE), obtain an updated library from the vendor, or disable bitcode for this target. for architecture arm64
```

Bitcode 可能是一个新的特性，但目前来说我想尽快将 KDE Connect iOS 构建起来。因此我在 `Build Settings->Build Options` 中禁用了它：

{% asset_img error-bitcode-fix.png Bitcode %}

## 链接 WebKit 库

另一个问题是与 WebKit 有关的：

```
Undefined symbols for architecture arm64: "_OBJC_CLASS_$_WKWebView"
```

看起来是因为 WebKit 框架没有被加入到项目中。所以，可以在 `Build Phases->Link Binary with Libraries` 将其加入：

{% asset_img error-webkit-fix-1.png WebKit %}

{% asset_img error-webkit-fix-2.png WebKit %}

## 文件未找到(Pods-acknowledgements.plist, Pods-resources.sh)

最终，当一切都完成构建，又一个问题出现：

```
Pods/Pods-acknowledgements.plist:0: Reading data: The file “Pods-acknowledgements.plist” couldn’t be opened because there is no such file.
```

这可能是因为 CocoaPod 版本导致的不兼容问题。我把 `Pods/Target Support Files/Pods-kdeconnect-ios` 中对应的文件复制到 `Pods/` 里来修复：

```sh
cp Pods-kdeconnect-ios-acknowledgements.plist ../../Pods-acknowledgements.plist
cp Pods-kdeconnect-ios-resources.sh ../../Pods-resources.sh
```

最终，程序终于构建成功并在设备上运行了 :)
