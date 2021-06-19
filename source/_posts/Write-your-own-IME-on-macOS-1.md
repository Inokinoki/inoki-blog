---
title: Write your own IME on macOS - 1. Create project
date: 2021-06-19 19:15:00
tags:
- macOS
- IME
categories:
- IME
---

On macOS, it is not so difficult to write an Input Method Engine (IME). Unlike Linux or the other Unix-like OS, macOS provides an official framework, `InputMethodKit`, to help you write an Input Method Engine.

An IME project is in fact a normal Cocoa app located in a special directory, with a special bundle identifier, some special declarations in `plist` manifest file, and some special classes/objects in the project. This post may help you initiate your own IME project. Let's go!

# Create the project

First, open XCode, create a new App project:

{% asset_img create-1.png Create a Cocoa App project %}

Then, type your IME name. Here I choose the typical name "HelloWorld".

{% asset_img create-2.png Create a Cocoa App project %}

Notice that there must be an `inputmethod` identifier in the bundle identifier. I choose to append a suffix to my organization identifier. However, you should also be able to do it in another way.

# Add some magic

In this section, I'll add some magic to to turn the app into an IME.

## Plist magic

In the manifest file `Info.plist`, there are magic to declare some information of your IME:

| Key                           | Type           |
| ----------------------------- | ------------- |
| InputMethodConnectionName | String |
| InputMethodServerControllerClass | String |
| tsInputMethodCharacterRepertoireKey	 | Array |

The `InputMethodConnectionName` will be the name of your IME, recognized by macOS.

The `InputMethodServerControllerClass` is the name of the Input Method controller class in your IME, which is in charge of communicating with macOS, exchanging the input events and submitting the candidate selected by the user.

The `tsInputMethodCharacterRepertoireKey` can help you declare the category of your IME. It will depend where your IME will show up in the `Input Source` panel of the macOS system preference. As an array, there can be multiple items. Thus, an IME for several languages is possible. For example, Squirrel has a `zh-Hans` string in the array, so it shows up in the `Chinese, Simplified` language as follow:

{% asset_img ime-system-preference.png IME system preference %}

If all is set, we can have an `Info.plist` like this:

{% asset_img plist.png IME Plist file %}

I choose `InokiHelloWorldIME` as the connection name. There will be an Input Method controller class named `InokiHelloWorldController` in my project, in charge of events. And I added `zh-Hans`, `zh-Hant` and `Latn` for the category.

## Class magic

We need to create our Input Method controller class, inheriting `IMKInputController` class from Input Method Kit.

{% asset_img controller.png IME Plist file %}

Add these codes to the implementation(.m) file, so that we can observe what happens when we are "using"(not actually) the IME:

```obj-c
- (void)activateServer:(id)sender
{
    NSLog(@"Server activated for %@", [sender bundleIdentifier]);
}

- (void)deactivateServer:(id)sender
{
    NSLog(@"Server deactivated for %@", [sender bundleIdentifier]);
}
```

This method is using one of the controller API to receive input event from macOS:

```obj-c
- (BOOL)inputText:(NSString*)string client:(id)sender
{
    NSLog(@"Controller received: %@", string);
    return NO;
}
```

There are in fact 3 different APIs to handle the input event, such as:

```obj-c
- (BOOL)inputText:(NSString*)string key:(NSInteger)keyCode modifiers:(NSUInteger)flags client:(id)sender;
- (BOOL)inputText:(NSString*)string client:(id)sender;
- (BOOL)handleEvent:(NSEvent*)event client:(id)sender;
```

For more details, you can take a look at the declaration of `IMKInputController` in `InputMethodKit/IMKInputController.h`.

With all these done, macOS should be able to find your Input Controller, thanks to the runtime information in Objective-C.

## Main Code magic

Finally, we need a minimum main function like this.

```obj-c
#import <Cocoa/Cocoa.h>
#import <InputMethodKit/InputMethodKit.h>

NSString* connectionName = @"InokiHelloWorldIME";
IMKServer*      server;

int main(int argc, char * argv[]) {
  @autoreleasepool{
    server = [[IMKServer alloc] initWithName:(NSString*)connectionName
                            bundleIdentifier:[[NSBundle mainBundle] bundleIdentifier]];

    [[NSApplication sharedApplication] run];
  }
  return 0;
}
```

In which we create an instance of `IMKServer` and make it alive during all the life cycle of our app. The server is also registered to macOS, so that the OS knows which process it should communicate.

# Run it

Finally, we can build it and copy it into `/Library/Input Methods`.

For debug or running, [this post](http://palanceli.com/2017/03/05/2017/0305macOSIMKSample1/) (in Chinese) is a good example.

Here, I concentrate more on the potential and undocumented bug (ok, it might be a feature) as follows.

## Oups, you may be isolated in a sandbox

You may suffer an error like:

```
[IMKServer _createConnection]: *Failed* to register NSConnection name=xxxxx
```

Same to me. I took several hours to dive into macOS and debug such error.

I found that the reason: `IMKServer` needs an `NSConnection` to communicate with macOS. However, by default, the app is sandboxized (by the <project-name.entitlements>) since a version of XCode.

So, the solutions are various:

- Remove the entitlements file;
- Allow `NSConnection` from sandbox;
- Disable the App sandbox in the entitlements file.

{% asset_img sandbox.png Disable Sandbox %}

Then, your IME should be good to go.

# Conclusion

In this post, there is a brief description for creating an IME project. I show an issue that may generally exist related to the sandbox stuff. Hope this can help you. In the next post, I'll try to show up the event handle in an IME on macOS.
