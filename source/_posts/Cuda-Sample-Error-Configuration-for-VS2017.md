---
title: Cuda Sample Error Configuration for VS2017
date: 2018-09-03 16:38:00
updated: 2018-10-22 08:29:16
tags:
- Windows
- Cuda
- Visual Studio
- Bug
categories:
- [Bug, Cuda]
---

```
CUDA Version: v9.2
Visual Studio 2017
    Microsoft Visual Studio Community 2017
    版本 15.8.2
    VisualStudio.15.Release/15.8.2+28010.2016
    Microsoft .NET Framework
    版本 4.7.03056
    
    已安装的版本: Community
    
    Visual C++ 2017 00369-60000-00001-AA285
    Microsoft Visual C++ 2017
```

When I compiled a sample named "vectorAdd", it occurs an error with message:
```
C1189 #error: -- unsupported Microsoft Visual Studio version! Only the versions 2012, 2013, 2015 and 2017 are supported! vectorAdd c:\program files\nvidia gpu computing toolkit\cuda\v9.2\include\crt\host_config.h 133
```

It's the file ``host_config.h`` who has limited the version. So we can change the version limit in this file:
```
131    #if _MSC_VER < 1600 || _MSC_VER > 1913
```
to
```
131    #if _MSC_VER < 1600 || _MSC_VER > 1920
```

It depends on your Visual Studio version that which version should you indicate, which means that probably ``_MSC_VER > 19xx`` is written in your ``host_config.h``, while your actual ``_MSC_VER`` could also be greater than 1920. It's all up to your situation, the principle is to modify the limit, you've got it!

For another error:
If we open an individual sample in the grand project, it will occur another problem. 

The message shows that all the head files for CUDA have not been added. So we can add them manually: Right click on the ``solution->Properties->VC++ Directories->include path``, add ``"C:\ProgramData\NVIDIA Corporation\CUDA Samples\v9.2\common\inc;"`` (which is your CUDA head files directory).

All will be well. God bless you!
