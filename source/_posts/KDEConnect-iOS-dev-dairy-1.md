---
title: KDE Connect iOS Develop Dairy(1) Build
date: 2020-04-18 21:43:50
tags:
- KDE Connect
categories:
- KDE Connect
---

# Handle Dependencies

The project uses [CocoaPods](https://cocoapods.org/) to manage its dependencies:

### WHAT IS COCOAPODS
CocoaPods is a dependency manager for Swift and Objective-C Cocoa projects. It has over 72 thousand libraries and is used in over 3 million apps. CocoaPods can help you scale your projects elegantly.

The CocoaPods file is `Podfile`, which describes the iOS version `(7.0)` to use, and the dependencies name, version and source:

```
platform :ios, '7.0'
pod 'CocoaAsyncSocket', '~> 7.3.5'
pod 'MRProgress'
pod 'InAppSettingsKit', '~> 2.1'
pod 'VTAcknowledgementsViewController'
pod 'XbICalendar', :podspec => 'https://raw.githubusercontent.com/libical/XbICalendar/master/XbICalendar.podspec'
pod 'MYBlurIntroductionView'
```

The first step to build it is installing the dependencies. After installing CocoaPods, I ran `pod install` and got some errors:

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

There are some bugs to fix :)

## Bugfix

```
[!] Could not automatically select an Xcode workspace. Specify one in your Podfile like so:

    workspace 'path/to/Workspace.xcworkspace'
```

In this project, the `.xcworkspace` file is `kdeconnect-ios.xcworkspace`. So, I add `workspace 'kdeconnect-ios'` into the file.

```
[!] The platform of the target `Pods` (iOS 7.0) may not be compatible with `InAppSettingsKit (2.15)` which has a minimum requirement of iOS 8.0.

[!] The platform of the target `Pods` (iOS 7.0) may not be compatible with `VTAcknowledgementsViewController (1.5.2)` which has a minimum requirement of iOS 8.0 - tvOS 9.0.
```

It's obvious that the target OS version should be updated. I directly update it to `platform :ios, '12.0'`.

```
[!] The abstract target Pods is not inherited by a concrete target, so the following dependencies won't make it into any targets in your project:
    ...
```

This message indicates that the `pods`(dependencies) don't have a target, according to the CocoaPod doc, I should add `target "kdeconnect-ios"` and wrap all the pods with a `do ... end` body.

## Final Podfile

As a result, the `Podfile` should be:

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

After fixing, the output seems normal:

```
$ pod install
Analyzing dependencies
Downloading dependencies
Generating Pods project
Integrating client project
Pod installation complete! There are 6 dependencies from the Podfile and 6 total pods installed.
```

# Build with XCode

Without error in installing dependencies, it's possible to open and build it with XCode (though it could be the worst IDE in the world).

## Identifier

The first issue occured while I click `Build`:

{% asset_img error-identifier.png Identifier error %}

```
Failed to register bundle identifier.
The app identifier "application-identifier" cannot be registered to your development team. Change your bundle identifier to a unique string to try again.
```

Apple wants to generate a self-signed certificate for my Apple account and for the application. But it cannot handle the identifier. I change it to `org.kde.kdeconnect.ios` and click `Try again`. It works.

## Multiple commands produce

Then, rebuild and another one came out:

{% asset_img error-multiple-commands-produce.png Language file error %}

```
Multiple commands produce '/Users/inoki/Library/Developer/Xcode/DerivedData/kdeconnect-ios-hhcvmcgjatxxdugxbjbrwgotfgna/Build/Products/Debug-iphoneos/kdeconnect-ios.app/zh-Hans.lproj/Localizable.strings':
1) Target 'kdeconnect-ios' (project 'kdeconnect-ios') has copy command from '/Users/inoki/Projects/kdeconnect-ios-test/kdeconnect-ios/zh-Hans.lproj/Localizable.strings' to '/Users/inoki/Library/Developer/Xcode/DerivedData/kdeconnect-ios-hhcvmcgjatxxdugxbjbrwgotfgna/Build/Products/Debug-iphoneos/kdeconnect-ios.app/zh-Hans.lproj/Localizable.strings'
2) Target 'kdeconnect-ios' (project 'kdeconnect-ios') has copy command from '/Users/inoki/Projects/kdeconnect-ios-test/kdeconnect-ios/zh-Hans.lproj/Localizable.strings' to '/Users/inoki/Library/Developer/Xcode/DerivedData/kdeconnect-ios-hhcvmcgjatxxdugxbjbrwgotfgna/Build/Products/Debug-iphoneos/kdeconnect-ios.app/zh-Hans.lproj/Localizable.strings'
```

To fix it, I refer [this GitHub issue](https://github.com/CocoaPods/CocoaPods/issues/7949#issuecomment-427636746) and change the build system to the legacy one:

{% asset_img error-multiple-commands-produce-fix.png Language file error %}

## Missing header

After that, another error occurs: 

{% asset_img error-header-not-found.png Missing header %}

```
kdeconnect-ios/AppSettingViewController.m:27:9: 'IASKPSTitleValueSpecifierViewCell.h' file not found
```

This may be an update of one dependency, just remove this import line:

```
#import "IASKPSTitleValueSpecifierViewCell.h"
```

## Link error, disable Bitcode

I rebuilt it, but another one came...

{% asset_img error-bitcode.png Bitcode %}

```
ld: '/Users/inoki/Projects/kdeconnect-ios-test/Pods/XbICalendar/libical/lib/libical.a(icalcomponent.c.o)' does not contain bitcode. You must rebuild it with bitcode enabled (Xcode setting ENABLE_BITCODE), obtain an updated library from the vendor, or disable bitcode for this target. for architecture arm64
```

Bitcode may be a feature, but I just want to get it build as soon as possible. So, I disable it in `Build Settings->Build Options`:

{% asset_img error-bitcode-fix.png Bitcode %}

## Link with WebKit

Another link error occurs. It's about the WebView stuff:

```
Undefined symbols for architecture arm64: "_OBJC_CLASS_$_WKWebView"
```

It seems that the WebKit framework is not included in the project. So, add it in `Build Phases->Link Binary with Libraries`:

{% asset_img error-webkit-fix-1.png WebKit %}

{% asset_img error-webkit-fix-2.png WebKit %}

## File(Pods-acknowledgements.plist, Pods-resources.sh) not found

Finally, at the end of building phases, the error came out:

```
Pods/Pods-acknowledgements.plist:0: Reading data: The file “Pods-acknowledgements.plist” couldn’t be opened because there is no such file.
```

This could be an error caused by CocoaPod version. To fix it, just copy the files in `Pods/Target Support Files/Pods-kdeconnect-ios` to `Pods/`:

```sh
cp Pods-kdeconnect-ios-acknowledgements.plist ../../Pods-acknowledgements.plist
cp Pods-kdeconnect-ios-resources.sh ../../Pods-resources.sh
```

Finally, it works :)
