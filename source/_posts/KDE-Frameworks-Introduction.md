---
title: KDE Frameworks - Introduction
date: 2020-07-02 23:22:00
tags:
- KDE Frameworks
categories:
- KDE Frameworks
---

**Note: this is an extraction of [KDE Frameworks API](https://api.kde.org/frameworks/index.html) with some comments**

- *Italics* means the project might be interesting to some developers.
- **Bold** means the project can be very useful for some applications.

The KDE Frameworks build on the Qt framework, providing everything from simple utility classes (such as those in KCoreAddons) to integrated solutions for common requirements of desktop applications (such as KNewStuff, for fetching downloadable add-on content in an application, or the powerful KIO multi-protocol file access framework).

The KDE Frameworks can be used in CMake-based and QMake-based projects, and most of them are portable to at least Windows, Mac and Linux. The documentation of each framework has code snippets that show how to include the framework in a QMake or CMake project.

The frameworks are divided into four tiers, based on the kind of dependencies that they have. For instance, Tier 1 frameworks depend on Qt and possibly some third-party libraries, but not on other frameworks. This makes them easy to integrate into existing applications.

# Tier 1

Tier 1 frameworks depend only on Qt (and possibly a small number of other third-party libraries), so can easily be used by any Qt-based project.

|   Framework   |   Type        | Description   | Note |
|---------------|---------------|---------------|------|
| Attica        | functional    | Open Collaboration Services API, version 1.6, REST  |
| BluezQt       | integration   | Qt wrapper for BlueZ 5 (Bluetooth) DBus API | Linux Only |
| BreezeIcons   | functional    | Breeze icon theme |   Beautiful icons |
| **ECM**       | functional    | Extra CMake modules |
| KApiDox       | functional    | Scripts and data for building API documentation (dox) in a standard format and style |
| KArchive      | functional    | File compression |
| KCalendarCore | functional    | The KDE calendar access library |
| KCGroups      | functional    | control cgroup resources through systemd dbus interface | Linux only |
| KCodecs       | functional    | provide a collection of methods to manipulate strings using various encodings |
| **KConfig**   | functional    | Configuration system | gconfig-like |
| **KCoreAddons**   | functional    | Addons to QtCore |
| **KDBusAddons**   | functional    | Addons to QtDBus |
| KDNSSD 	    | integration   | a library for handling the DNS-based Service Discovery Protocol (DNS-SD) |
| **KGuiAddons**    | functional    | Addons to QtGui |
| KHolidays     | functional    | Holiday calculation library |
| **KI18n**     | functional    | Advanced internationalization framework |
| KIdleTime     | functional    | Monitoring user activity |
| **Kirigami2** | functional    | QtQuick plugins to build user interfaces based on the KDE human interface guidelines |
| KItemModels   | functional   | Models for Qt Model/View system |
| KItemViews    | functional   | Widget addons for Qt Model/View |
| KPlotting     | functional   | Lightweight plotting framework |
| KQuickCharts  | functional   | A QtQuick module providing high-performance charts | I don't know why, but it only supports Linux and FreeBSD |
| *KSyntaxHighlighting*        | functional   | Syntax Highlighting | Kate uses it, helpful for Text Editor
| KUserFeedback        | solution   | User feedback framework |
| *KWayland*        | integration   | Qt-style API to interact with the wayland-client and wayland-server API |
| **KWidgetsAddons**        | functional   | Addons to QtWidgets |
| *KWindowSystem*        | integration   | Access to the windowing system |
| ModemManagerQt        | integration   | Qt wrapper for ModemManager API | Linux Only |
| NetworkManagerQt        | integration   | Qt wrapper for NetworkManager API | Linux Only |
| Oxygen-icons        | functional   | Oxygen icon theme |
| Prison        | solution  | Barcode abstraction layer providing uniform access to generation of barcodes |
| QQC2-Desktop-Style    | functional    | QtQuickControls 2 style that integrates with the desktop |
| Solid         | integration   | Hardware integration and detection    | Hardware Discovery, Power Management, Network Management |
| Sonnet        | solution      | Support for spellchecking | plugin-based spell checking library |
| ThreadWeaver  | functional    | High-level multithreading framework   | job-based interface to queue tasks |

# Tier 2

Tier 2 frameworks additionally depend on tier 1 frameworks, but still have easily manageable dependencies.

|   Framework   |   Type        | Description   | Note |
|---------------|---------------|---------------|------|
| KActivities   | solution      | Runtime and library to organize the user work in separate activities |
| **KAuth**     | integration   | Abstraction to system policy and authentication features | run high-privileged tasks (Linux, macOS, etc) |
| KCompletion   | functional    | Text completion helpers and widgets | completion for user input |
| KContacts     | functional    | Support for vCard contacts | read/write data in vCard standard (RFC 2425 / RFC 2426) |
| KCrash        | integration   | Support for application crash analysis and bug report from apps | crash report |
| KDocTools     | functional    | Documentation generation from docbook |
| **KFileMetaData**     | integration   | A file metadata and text extraction library | extracting the text and metadata from different files |
| KImageFormats | functional    | Image format plugins for Qt | additional image format plugins for QtGui (runtime plugin) |
| **KJobWidgets**       | functional    | Widgets for tracking KJob instances | widgets for showing progress of asynchronous jobs |
| **KNotifications**    | solution      | Abstraction for system notifications | cross-platform notification! |
| KPackage      | functional    | Library to load and install packages of non binary files as they were a plugin |
| KPeople       | functional    | Provides access to all contacts and the people who hold them | gather all types of contacts |
| **KPty**      | integration   | Pty abstraction | interfacing with pseudo terminal devices |
| KQuickImageEditor     | functional    | QtQuick plugins for image editing UI | QtQuick components for image editing, Linux only |
| KUnitConversion       | functional    | Support for unit conversion | Unit Conversion |
| **Syndication**       | functional    | An RSS/Atom parser library | parse RSS (0.9/1.0, 0.91..2.0) and Atom (0.3 and 1.0) feeds |

# Tier 3

Tier 3 frameworks are generally more powerful, comprehensive packages, and consequently have more complex dependencies.

|   Framework       |   Type        | Description   | Note |
|-------------------|---------------|---------------|------|
| Baloo             | solution      | Baloo is a file indexing and searching framework for KDE Plasma, Linux/FreeBSD only |
| KActivitiesStats  | solution      | A library for accessing the usage data collected by the activities system |
| KBookmarks        | functional    | Support for bookmarks and the XBEL format | access and manipulate bookmarks|
| **KCMUtils**      | integration   | Utilities for working with KCModules |
| **KConfigWidgets**    | integration   | Widgets for configuration dialogs | can be integrated into KDE Plasma system setting |
| **KDAV**          | functional    | The KDav library | interact with WebDAV calendars and todos with KJobs |
| KDeclarative      | functional    | Provides integration of QML and KDE Frameworks | bridge between QML and KDE Frameworks |
| KDED              | solution      | Extensible deamon for providing system level services | Linux/FreeBSD only |
| KDESu             | integration   | Integration with su for elevated privileges | su GUI for console mode programs, Linux/FreeBSD only |
| KEmoticons        | functional    | Support for emoticons and emoticons themes | from text to images in HTML |
| KGlobalAccel      | integration   | Add support for global workspace shortcuts | Linux/FreeBSD only |
| KIconThemes       | integration   | Support for icon themes |
| KInit             | solution      | Process launcher to speed up launching KDE applications |
| **KIO**           | solution      | Resource and network access abstraction | SFTP, Samba, etc |
| *KNewStuff*       | solution      | Support for downloading application assets from the network | collaborative data sharing for applications |
| KNotifyConfig     | integration   | Configuration system for KNotify |
| *KParts*          | solution      | Document centric plugin system |
| KRunner           | solution      | Parallelized query system |
| **KService**      | solution      | Advanced plugin and service introspection | handling desktop services |
| *KTextEditor*     | solution      | Advanced embeddable text editor | with rich text support |
| *KTextWidgets*    | functional    | Advanced text editing widgets |
| KWallet           | solution      | Secure and unified container for user passwords |
| *KXmlGui*         | integration   | User configurable main windows | managing menu and toolbar actions in an abstract way |
| *Plasma*          | solution      | Plugin based UI runtime used to write primary user interfaces | KDE Plasma! |
| Purpose           | integration   | Offers available actions for a specific purpose | allow other apps use this one |

# Tier 4

Tier 4 frameworks can be mostly ignored by application programmers; this tier consists of plugins acting behind the scenes to provide additional functionality or platform integration to existing frameworks (including Qt).

|   Framework           |   Type        | Description   | Note |
|-----------------------|---------------|---------------|------|
| FrameworkIntegration  | integration   | Workspace and cross-framework integration plugins |

# Porting Aids

Porting Aids frameworks provide code and utilities to ease the transition from kdelibs 4 to KDE Frameworks 5. Code should aim to port away from this framework, new projects should avoid using these libraries.

|   Framework       |   Type        | Description   | Note |
|-------------------|---------------|---------------|------|
| KDELibs4Support   | solution      | Porting aid from KDELibs4 |
| KDesignerPlugin   | functional    | Tool to generate custom widget plugins for Qt Designer/Creator |
| KDEWebKit         | integration   | KDE Integration for QtWebKit |
| KHtml             | solution      | KHTML APIs |
| KJS               | functional    | Support for JS scripting in applications |
| KJsEmbed          | functional    | Embedded JS |
| KMediaPlayer      | integration   | Plugin interface for media player features |
| Kross             | solution      |Multi-language application scripting |
| KXmlRpcClient     | functional    | Interaction with XMLRPC services |
