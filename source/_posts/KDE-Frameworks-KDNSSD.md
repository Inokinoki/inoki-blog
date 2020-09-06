---
title: KDE Frameworks - KDNSSD
date: 2020-09-06 08:22:00
tags:
- KDE Frameworks
categories:
- KDE Frameworks
---

**Important**: this post assumes that you have knowledge on Qt and CMake/QMake, and that you have at least some concept on library linking.

# Introduction

The KDE Frameworks[\[1\]](#Reference) provides a set of frameworks based on Qt framework. It can largely reduce duplicated work on implementing lots of common-use components in many Desktop Applications. The KDE Frameworks not only support Linux/Unix Desktop, most of its frameworks can also work on Windows, macOS, even Android and iOS. 

DNS Service Discovery(DNS-SD)[\[2\]](#Reference) is a way of using standard DNS programming interfaces, servers, and packet formats to browse the network for services. The protocol is widely used in the modern applications to provide inter-discovery functionality between devices, for example, printer discovery, Local Area Network multiplayer game, etc.

This post shows up how to use [KDNSSD](https://api.kde.org/frameworks/kdnssd/html/index.html)[\[3\]](#Reference) framework in KDE Frameworks.

# KDNSSD Set Up

The KDNSSD framework is located at the Layer 1 in the KDE Frameworks, which means that KDNSSD doesn't rely on any other framework in the KDE Frameworks. It does require Qt, but it's not a big barricade. If you don't have Qt development kit, you can easily install one and then continue.

In most Linux distribution, in particular, the Linux distribution which has KDE desktop support, there should be software packets of KDNSSD.

## Installation

On Debian/Ubuntu,

```
sudo apt install libkf5dnssd libkf5dnssd-dev
```

On RedHat family (CentOS, Fedora) :

```
sudo yum install kf5-kdnssd kf5-kdnssd-devel
```

On Arch Linux:

```
sudo pacman -S kdnssd
```

The development files (eg. header files) and the runtime libraries should be installed and configured correctly.

## Linking

According to the documentation[\[4\]](#Reference), you can use either CMake or QMake:

```cmake
find_package(KF5DNSSD)
target_link_libraries(yourapp KF5::DNSSD)
```

```qmake
QT += KDNSSD 
```

Even, you could use pkg-config if you'd like.

Here I choose to use CMake, the one mostly used in KDE Community.

# KDNSSD Hello World

The first lesson in Computer Engineer is usually a `Hello World`, which contains the most basic functionality.

In KDNSSD, or DNS-SD, the most basic one is to expose a service and to discover a service. So, the `Hello World` here is to expose a service on the local machine, and discover it 

## Exposing a serivce

Firstly, I create a `ServicePublisher` class in `service_publish.cpp`, as the service exposer program.

Its constructor creates a `KDNSSD::PublicService` object, which pretends there is a `My files` service based on HTTP and thus TCP protocol, listening on `8080` port.

Then, we set up a connection between signal and slot. And finally publish the DNS-SD information asynchronously.

```cpp
ServicePubisher()   // Typo
{
    m_service = new KDNSSD::PublicService("My files", "_http._tcp", 8080);
    connect(m_service, &KDNSSD::PublicService::published, this, &ServicePubisher::isPublished);
    m_service->publishAsync();
}
```

The `published` signal is connected to `isPublished` method in the class. It will output the publish state once the state is notified:

```cpp
void isPublished(bool state)
{
    if (state) {
        qDebug() << "Service published";
    } else {
        qDebug() << "Service not published";
    }
}
```

## Exposing a service

Then, I created another class `ServiceExplorer` to try discovering services which are declared to be based on HTTP and TCP protocol.

```cpp
ServiceExplorer()
{
    m_browser = new KDNSSD::ServiceBrowser(QStringLiteral("_http._tcp"));

    connect(m_browser, &KDNSSD::ServiceBrowser::serviceAdded,
            this, [](KDNSSD::RemoteService::Ptr service) {
                qDebug() << "Service found on" << service->hostName() << service->serviceName();
            });
    connect(m_browser, &KDNSSD::ServiceBrowser::serviceRemoved,
            this, [](KDNSSD::RemoteService::Ptr service) {
                qDebug() << "Service unregistered on" << service->hostName();
            });
    
    m_browser->startBrowse();
}
```

The `serviceAdded` and `serviceRemoved` signals are connected with anonymous functions, which only do some output.

## CMake file

At the end, add the 2 programs as executable and link them to the KDNSSD:

```cmake
add_executable(kdnssd-discover-helloworld service_discover.cpp)
add_executable(kdnssd-publish-helloworld service_publish.cpp)

find_package(KF5DNSSD)

target_link_libraries(kdnssd-discover-helloworld KF5::DNSSD)
target_link_libraries(kdnssd-publish-helloworld KF5::DNSSD)
```

Build and run them :) You should be able to discover the fake `My Files` service published by the `ServicePublisher`.

You can find the source code on my [kde-frameworks-tutorial](https://github.com/Inokinoki/kde-frameworks-tutorial/tree/master/KDNSSD) GitHub repo. Give me and my project a star if you like it :) You can also watch it to get notified when there is an update.

# Conclusion

Here I only show a basic use of KDNSSD. To know more details about it, reading documentation is the best way. Good luck!

For further reading, you could find the links in [Reference](#Reference) chapter.


# Reference

\[1\] KDE Frameworks, https://kde.org/products/frameworks/

\[2\] DNS-SD, http://www.dns-sd.org/

\[3\] RFC 6763 DNS-Based Service Discovery, https://www.ietf.org/rfc/rfc6763.txt

\[4\] KDNSSD Dcoumentation, https://api.kde.org/frameworks/kdnssd/html/index.html