---
title: 【译】 Vulkan 光线追踪
date: 2021-08-02 23:08:10
tags:
- Computer Graphics
- Vulkan
- Ray Tracing
- 中文
- 翻译
categories:
- [Translation, Chinese]
- [Computer Graphics, Vulkan]
---

原文链接：[Vulkan Ray Tracing Final Specification Release](https://www.khronos.org/blog/vulkan-ray-tracing-final-specification-release)

# 总览

今天，Khronos® 发布了一套 Vulkan®、GLSL 和 SPIR-V 扩展规范的最终版本，将光线追踪无缝集成到现有的Vulkan框架中。这是一个重要的里程碑，因为它是业界第一个开放的、跨厂商的、跨平台的光线追踪加速标准--可以使用现有的GPU计算或专门的光线追踪核心来部署。凡是使用过 DirectX 12 中的 DirectX 光线追踪（DXR）的人都会对 Vulkan 光线追踪感到熟悉，但它也引入了一些高级功能，比如将光线追踪设置操作负载平衡到主机 CPU 上的能力。尽管光线追踪将首先部署在桌面系统上，但这些 Vulkan 扩展的设计是为了使光线追踪也能部署在移动设备上，并激励光线追踪的使用。

这些扩展最初是在 2020 年 3 月作为临时版本发布的。从那时起（见图 1），我们收到并采纳了硬件供应商和软件开发商的反馈，包括 Khronos 内部和更广泛的行业，但 API 的整体状态和提供的功能基本上没有变化。感谢所有审阅和使用临时扩展的人，特别是那些提供反馈意见的人!

![Vulkan Ray Tracing Dev Timeline](https://www.khronos.org/assets/uploads/blogs/2020-Vulkan-Ray-Tracing-development-timeline-1.jpg)

今天发布的扩展规范只是 Vulkan 光线追踪技术推广的开始。在未来几天和几周内，其他生态系统组件，如着色器工具链和验证层将被更新，以支持光线追踪功能，确保开发人员能够在他们的应用程序中轻松使用这些扩展。这些生态系统的更新进展可以在 GitHub 上跟踪。这将在12月中旬发布支持 Khronos Vulkan 光线追踪的 Vulkan SDK（1.2.162.0 或更高版本）时达到最高活跃度。

这篇文章将强调 Vulkan Ray Tracing 扩展的临时版本和最终版本之间最重要的区别，并解释这些变化背后的一些原因。

# 秀出我们的规范！

这套 Vulkan 光线追踪扩展所提供的整体功能自其临时版本以来没有变化。今天发布的最终扩展集是：

```
    Vulkan extension specifications
        VK_KHR_acceleration_structure
        VK_KHR_ray_tracing_pipeline
        VK_KHR_ray_query
        VK_KHR_pipeline_library
        VK_KHR_deferred_host_operations
    SPIR-V extensions specifications
        SPV_KHR_ray_tracing
        SPV_KHR_ray_query
    GLSL extensions specifications
        GLSL_EXT_ray_tracing
        GLSL_EXT_ray_query
        GLSL_EXT_ray_flags_primitive_culling
```

## 拓展的结构


最明显的变化是，临时的 `VK_KHR_ray_tracing` 扩展已经被分成了 3 个扩展：
- VK_KHR_acceleration_structure - 用于加速结构的构建和管理
- VK_KHR_ray_tracing_pipeline - 用于光线追踪着色器的阶段和流水线
- VK_KHR_ray_query -  为所有着色器阶段提供光线查询的基本

我们收到的反馈是，一些市场希望能够支持光线追踪查询而不支持光线追踪流水线，为了避免重复和人为的依赖，我们对原来的扩展进行了细分。实现可以选择支持 `VK_KHR_ray_tracing_pipeline`、`VK_KHR_ray_query` 或两者之一，取决于市场需要。这两个扩展都依赖于`VK_KHR_acceleration_structure` 扩展，为加速结构管理提供一个共同的基础。主要的桌面厂商仍然致力于支持光线流水线和光线查询。关于对可选功能的支持和对其他市场的支持的具体细节，请与各个供应商商谈。

Vulkan 光线追踪扩展不再被标记为临时性的，因此五个扩展的扩展接口现在被定义在主 `vulkan_core.h` 头中，而不是临时的 `vulkan_beta.h`，用户不再需要 `#define VK_ENABLE_BETA_EXTENSIONS` 来启用 Vulkan 光线追踪功能。

扩展的依赖性也有变化。现在需要 Vulkan 1.1 和 SPIR-V 1.4。`VK_KHR_acceleration_structure` 需要Vulkan 1.1、`VK_EXT_descriptor_indexing`、`VK_KHR_buffer_device_address`，以及`VK_KHR_deferred_host_operations`。我们意识到，一个冗长的扩展依赖列表是令人讨厌的，理想情况下，我们希望简单地要求 Vulkan 1.2，但目前并非所有平台都支持 Vulkan 1.2，我们不想为采用光线追踪功能添加任何人为障碍。如果所有的目标市场都支持 Vulkan 1.2，那么应用程序就可以直接以 Vulkan 1.2 为目标，以达到简化的目的。我们也考虑过不把 `VK_KHR_deferred_host_operations` 作为一个明确的依赖关系，但是用延迟操作创建流水线的变化要求我们保留它。我们把 `VK_KHR_pipeline_library` 作为 `VK_KHR_ray_tracing_pipeline` 的软要求，而不是严格要求，因此应用程序只需要在实际使用时启用它。除了 `VK_KHR_acceleration_structure`，`VK_KHR_ray_tracing_pipeline` 和 `VK_KHR_ray_query` 都至少需要 SPIR-V 1.4，因为该版本中增加了入口点要求的变化。SPIR-V 1.5 也可以用于 Vulkan 1.2 的实现。

从功能上讲，所有的实现都必须具备以下功能：

- VK_KHR_deferred_host_operations
- accelerationStructure
-  descriptorBindingAccelerationStructureUpdateAfterBind
-  `descriptorIndexing` 功能（如果支持 Vulkan 1.2）或 `VK_EXT_descriptor_indexing` 扩展所需的所有功能
- Vulkan 1.2 中的 `bufferDeviceAddress` 或 `VK_KHR_buffer_device_address`

支持 `VK_KHR_ray_tracing_pipeline` 的实现需要：

- VK_KHR_acceleration_structure
- rayTracingPipeline
- rayTracingPipelineTraceRaysIndirect
- `rayTraversalPrimitiveCulling` 若 `VK_KHR_ray_query` 也被支持
- `VK_KHR_pipeline_library`

支持 `VK_KHR_ray_query` 的实现需要 require:

- VK_KHR_acceleration_structure
- rayQuery.

此外，还有一些可选择的能力与扩展定义。

对于 `VK_KHR_acceleration_structure`，有：

- accelerationStructureCaptureReplay
- accelerationStructureIndirectBuild
- accelerationStructureHostCommands

对于 `VK_KHR_ray_tracing_pipeline`，有：

- rayTracingPipelineShaderGroupHandleCaptureReplay
- rayTracingPipelineShaderGroupHandleCaptureReplayMixed
- rayTraversalPrimitiveCulling，若 `VK_KHR_ray_query` 未支持

## 加速结构

在最终的 Vulkan 光线追踪功能中，对应用程序影响最大的变化是加速结构的创建和布局。

我们从 API 翻译层（如 vkd3d-proton）的作者那里得到反馈，在临时 API Vulkan 光线追踪加速结构的基础上分层 DXR 是不现实的。这导致了对加速结构创建大小的改变，并使用 VkBuffer 上的加速结构存储分配，而不是专门的加速结构对象存储。这些变化的一个影响是，`VkAccelerationStructureKHR` 和 `VkAccelerationStructureNV` 不再是别名，不能互换使用。同样地，任何以它们为参数的结构或函数也不再是别名了。

我们还为分层添加了一个新的加速结构类型 `VK_ACCELERATION_STRUCTURE_TYPE_GENERIC_KHR`。 在实际的加速结构类型（顶部或底部）还不清楚的情况下，可以在加速结构创建时使用。实际的加速结构类型必须指定为 `VK_ACCELERATION_STRUCTURE_TYPE_TOP_LEVEL_KHR` 或 `VK_ACCELERATION_STRUCTURE_TYPE_BOTTOM_LEVEL_KHR`，当执行构建时不能改变。直接为 Vulkan 编写的应用程序不应该使用 `VK_ACCELERATION_STRUCTURE_TYPE_GENERIC_KHR`，因为这可能会影响未来的能力或性能。

我们还收到了分层 Vulkan 实现（如 MoltenVK）的作者的反馈，指出一些光线追踪的要求（如设备地址）会使 Vulkan 无法在其他一些 API 上以分层方式实现。不幸的是，我们不可能在解决这个问题的同时还支持其他目标，比如与 DXR 的功能对等。我们希望其他 API 的未来版本也能添加必要的功能来实现这种分层。

我们听说开发者真的很喜欢统一的创建和构建参数，就像在 `VK_NV_ray_tracing` 和 DXR 中。我们将加速结构的创建改为基于大小，大小可以从用于构建的同一结构中计算（`vkGetAccelerationStructureBuildSizesKHR`），或者从精简查询中计算（`vkCmdWriteAccelerationStructuresPropertiesKHR`）。我们还了解到，一些实现在创建时需要额外的信息，这导致 `vkGetAccelerationStructureBuildSizesKHR` 中增加了 `pMaxPrimitiveCounts`。

以前的几何体描述的某些方面很混乱，与自动生成的代码不能很好地配合（如验证层），因此我们解决了 `ppGeometries` 二元性造成的模糊，并增加了一个额外的 `pGeometries` 字段，但要求每次只使用其中一个字段。

其他新增内容包括：加速器结构的创建时间捕获和重放标志（用于调试工具），加速器结构的 `nullDescriptor` 支持，作为与 `VK_EXT_robustness2` 的交互，以及加速器结构的 `VK_DESCRIPTOR_SET_LAYOUT_CREATE_UPDATE_AFTER_BIND_POOL_BIT` 支持。

最后但并非最不重要的是，我们做了修改，以便在所有扩展中一致地使用设备地址。我们还提出了许多命名建议，其中一些被采纳了，并且出于一致性和可扩展性的考虑，我们做了各种命名和风格上的改变。关于这些和其他变化的更多细节，请参见问题 3 和 4 以及 `VK_KHR_acceleration_structure` 中的变化日志。

## 延迟的主机操作

我们修改了 `vkBuildAccelerationStructuresKHR` 和 `vkCreateRayTracingPipelinesKHR` 命令中延迟主机操作的使用方式。现在，延迟操作请求不再被链入每个单独的构建或创建操作的 `pNext` 中，而是作为命令的顶级参数传入，整个命令要么延迟，要么不延迟。当命令被推迟时，应用程序不得访问返回参数，直到推迟的操作完成。之前的命令语义中，一些子操作可以被延迟，而另一些则不能，这使得对命令返回值的行为预期不明确，很难理解什么时候访问它们是安全的。我们认为，新的语义更清晰，应该能够提供更多的并行机会，但如上所述，这是以要求 `VK_KHR_deferred_host_operations` 扩展在任何时候都被启用为代价。

![Deferred Host Operations](https://www.khronos.org/assets/uploads/blogs/2020-Deferred-Host-Operations-enable-Acceleration-Structures-to-be-built-using-multiple-CPU-cores-for-faster-frame-rates-and-elimination-of-frame-stuttering-2.jpg)

## 光线追踪流水线

对光线追踪流水线机制的改变没有那么剧烈，其中一些只影响 SPIR-V 和着色器编译器工具链。

除了上面提到的针对延迟操作的 `vkCreateRayTracingPipelinesKHR` 的变化之外，还有一些变化，使 `VkPipelineLibraryCreateInfoKHR` 和 `VkRayTracingPipelineInterfaceCreateInfoKHR` 成为可选项，这样如果不使用 `VK_KHR_pipeline_library`，就不需要启用它们。

对于光线追踪流水线来说，最大的 API 变化是增加了明确的堆栈大小管理。光线追踪流水线有一个潜在的大型着色器集，在光线追踪过程中可能会以各种调用链组合的方式被调用。在给定的着色器执行过程中，实现可以使用堆栈在内存中存储参数，这个堆栈的大小需要足够大，以处理实现可以执行的任何调用链中所有着色器所需的堆栈大小。默认的堆栈大小有可能相当大，所以我们增加了一种方法，让应用程序在流水线编译后指定一个更理想的堆栈大小。这是在应用程序可以根据对着色器和调用链属性的特定应用知识计算出更严格的堆栈大小约束的情况下使用的。为光线追踪流水线添加了一个新的动态状态（`VK_DYNAMIC_STATE_RAY_TRACING_PIPELINE_STACK_SIZE_KHR`），以及查询着色器组的堆栈大小（`vkGetRayTracingShaderGroupStackSizeKHR`）和为流水线设置动态堆栈大小（`vkCmdSetRayTracingPipelineStackSizeKHR`）的命令。

另一个新增功能是基于 DXR 分层工作的反馈，即通过加速结构地址追踪光线的能力。有了这个功能，从 `vkGetAccelerationStructureDeviceAddressKHR` 获取的加速结构的设备地址可以存储在一个缓冲区或其他着色器资源中。在着色器中，可以使用SPIR-V `OpConvertUToAccelerationStructureKHR`指令（在 GLSL 中表现为 `accelerationStructureEXT` 类型构造器）将其转换为不透明的 `OpTypeAccelerationStructureKHR` 描述器类型。然后，产生的变量可以用来指定加速结构，以便在 `OpTraceRayKHR` 指令（`traceRayEXT()`）中进行追踪。这种转换是单向的，在不透明的加速结构描述符上不支持其他操作。

![Ray tracing pipelines](https://www.khronos.org/assets/uploads/blogs/2020-Ray-tracing-pipelines-provide-implicit-management-of-ray-intersections-3.jpg)

SPIR-V 工作组也提供了关于 SPIR-V 扩展的反馈，这导致了对 `OpTraceRayKHR` 的有效载荷参数和 `OpExecuteCallableKHR` 的可调用数据参数的修改。以前，这些参数与 GLSL 中声明的有效载荷或可调用数据结构的位置布局限定符匹配。然而，这些位置在 SPIR-V 中是没有意义的，因此被替换为直接指向适当的存储类的指针，而不是使用整数位置。这对 GLSL 扩展没有影响，因为 glslang 自动处理了转换，然而，这确实需要 `OpTraceRayKHR` 和 `OpExecuteCallableKHR` 的新操作码，它们不能再与 `SPV_NV_ray_tracing` 的相应操作相联系。

另一个由内部反馈驱动的 SPIR-V 变化是将 `OpIgnoreIntersectionKHR` 和 `OpTerminateRayKHR` 变成终止指令，因为它们终止了执行它们的调用。这些指令也必须是一个块中的最后一条指令。同样，这也导致了新的操作码被分配给这些指令。这一变化确实影响了 GLSL--这些指令不再是内置函数，而是跳转语句，因此在着色器中使用时，不再显示为 `ignoreIntersectionEXT()`；而是简单地显示为 `ignoreIntersectionEXT`；。

在总结 SPIR-V 对光线追踪流水线的修改时，有一个新的能力和枚举（`RayTracingKHR`），使实现和工具链能够区分为现在已经过时的临时扩展而编写的 SPIR-V 和最终语义。我们还对 `ShaderRecordBufferKHR` 所需的明确布局做了一些澄清，并将其与StorageBuffer存储类的处理方式相同。我们还规定了 `OpReportIntersectionKHR` 的返回值和超出范围的T值的行为，并澄清了只有一个子集的比特用于各种光线追踪参数。

与 `VK_KHR_acceleration_structure` 扩展一样，我们做了修改，以完全使用缓冲设备地址，因此着色器绑定表现在被作为缓冲设备地址通过 `VkStridedDeviceAddressRegionKHR` 结构提供给追踪光线命令。同样地，`vkCmdTraceRaysIndirectKHR` 的间接参数也通过缓冲设备地址传递。

我们还更新了与 Vulkan 1.2 和 `VK_KHR_vulkan_memory_model` 扩展的交互，并要求某些内置变量（主要是与子组相关的）在支持着色器调用的着色器中被标记为 `Volatile`。

其他变化包括为着色器组句柄添加创建时间捕获和重放标志，添加以前遗漏的各种属性和限制，以及一些重命名以提高清晰度。关于这些和其他变化的更多细节，请参见 `VK_KHR_ray_tracing_pipeline` 中的问题 3 和 4，`SPV_KHR_ray_tracing` 中的问题 2，以及扩展变化日志。

## 光线查询

鉴于 Vulkan 的 API 中很少有光线查询，大部分与光线查询有关的变化都在 SPIR-V 的扩展和交互中。

`SPV_KHR_ray_query` 还包括支持通过加速结构地址发出光线查询，并增加了`OpConvertUToAccelerationStructureKHR`，同样可以用来将加速结构设备地址转换成不透明的`OpTypeAccelerationStructureKHR` 描述符。然后，这些描述符可以用来为 `OpRayQueryInitializeKHR` 指定要追踪的加速结构。

与光线流水线一样，存在一个新的能力和枚举（RayQueryKHR），使实现和工具链能够区分为现在已经过时的临时扩展而编写的 SPIR-V 和最终语义。我们还澄清了只有一个子集的位用于剔除掩码，并且不允许从 AABB 基元中查询候选 T 值。

最后，我们还规定了光线参数的数值限制，要求 HitT 在 `OpRayQueryGenerateIntersectionKHR` 的光线区间内，并将追踪限制在顶层加速结构上。

关于这些和其他变化的更多细节，请参见 `VK_KHR_ray_query` 的第1期，`SPV_KHR_ray_query` 的第1期，以及扩展的变化日志。

![Ray Queries](https://www.khronos.org/assets/uploads/blogs/2020-Ray_Queries_provide_explicit_ray_management_from_within_any_shader-4.jpg)

# 路在脚下

This section gives an overview of the new flow for acceleration structure creation and includes a quick primer on resource creation flags and ray tracing synchronization.

## 加速结构的创建

为了创建一个加速结构，应用程序必须首先确定加速结构所需的尺寸。对于构建来说，加速结构的大小以及构建和更新的缓冲区大小是通过 `vkGetAccelerationStructureBuildSizesInfoKHR` 结构中的 `vkGetAccelerationStructureBuildSizesKHR` 命令获得。要创建的加速结构的形状和类型在 `VkAccelerationStructureBuildGeometryInfoKHR` 结构中描述。这和以后用于实际构建的结构是一样的，但是加速结构参数和几何体数据指针不需要在这时完全填充（尽管它们可以填充），只是加速结构类型，以及几何体类型、计数和最大尺寸。这些尺寸对任何足够相似的加速结构都是有效的。对于将成为压缩拷贝目标的加速结构，所需的尺寸可以通过 `vkCmdWriteAccelerationStructuresPropertiesKHR` 命令获得。一旦确定了所需的大小，应用程序就会为加速结构创建一个 VkBuffer（`accelerationStructureSize`），并根据需要为构建（`buildScratchSize`）和更新（`updateScratchSize`）缓冲区创建 VkBuffer。

接下来，可以使用 `vkCreateAccelerationStructureKHR` 命令创建 `VkAccelerationStructureKHR` 对象，该命令创建一个指定类型和大小的加速结构，并将其放置在 `VkAccelerationStructureCreateInfoKHR` 中提供的缓冲区的偏移处。与 Vulkan 中的大多数其他资源不同，缓冲区的指定部分完全为加速结构提供了内存；不需要查询额外的内存需求或将内存绑定到加速结构对象上。如果需要，可以在同一个 `VkBuffer` 中放置多个加速结构，只要加速结构不重叠。

最后，可以使用 `vkCmdBuildAccelerationStructuresKHR` 命令来构建加速结构。构建时使用与确定加速结构大小相同的 `VkAccelerationStructureBuildGeometryInfoKHR` 结构，但这次必须指定目标加速结构以及所有几何数据指针（用于顶点、索引、变换、aabbs和实例）和抓取数据指针。一旦构建完成，加速结构是完全独立的，构建输入和从头开始的缓冲区可以被应用程序重新利用，除非它计划将它们用于未来的更新构建。

## 资源使用与同步

本节提供了关于何时应使用各种缓冲区使用标志的高层次概述，以及对各种光线追踪操作应使用何种类型的同步的简要描述。

将用于加速结构备份的缓冲区是用 `VK_BUFFER_USAGE_ACCELERATION_STRUCTURE_STORAGE_BIT_KHR` 用法创建的，将用于构建从头空间的缓冲区需要指定 `VK_BUFFER_USAGE_STORAGE_BUFFER_BIT` 用法。和加速结构的构建输入，如顶点、索引、变换、aabb和实例数据，需要指定 `VK_BUFFER_USAGE_ACCELERATION_STRUCTURE_BUILD_INPUT_READ_ONLY_BIT_KHR` 用法。用于着色器绑定表的缓冲区以 `VK_BUFFER_USAGE_SHADER_BINDING_TABLE_BIT_KHR` 用法创建，用于间接构建和跟踪参数的缓冲区以 `VK_BUFFER_USAGE_INDIRECT_BUFFER_BIT` 用法创建。

为了与加速结构构建命令（`vkCmdBuildAccelerationStructuresKHR` `vkCmdBuildAccelerationStructuresIndirectKHR`）同步依赖，使用 `VK_PIPELINE_STAGE_ACCELERATION_STRUCTURE_BUILD_BIT_KHRpipeline` 阶段。对源加速结构或目标加速结构的访问，以及对取回缓冲区的访问，使用 `VK_ACCESS_ACCELERATION_STRUCTURE_READ_BIT_KHR` 或 `VK_ACCESS_ACCELERATION_STRUCTURE_WRITE_BIT_KHR` 的访问类型。对构建的输入缓冲区（顶点、索引、变换、aabb或实例数据）的访问使用 `VK_ACCESS_SHADER_READ_BIT` 的访问类型，对间接参数的访问使用 `VK_ACCESS_INDIRECT_COMMAND_READ_BIT` 的访问类型。

当与加速结构复制命令（`vkCmdWriteAccelerationStructuresPropertiesKHR`、`vkCmdCopyAccelerationStructureKHR`、`vkCmdCopyAccelerationStructureToMemoryKHR` 和 `vkCmdCopyMemoryToAccelerationStructureKHR`）同步依赖时，也使用 `VK_PIPELINE_STAGE_ACCELERATION_STRUCTURE_BUILD_BIT_KHR` 流水线阶段。读取或写入加速结构的访问分别使用 `VK_ACCESS_ACCELERATION_STRUCTURE_READ_BIT_KHR` 或者 `VK_ACCESS_ACCELERATION_STRUCTURE_WRITE_BIT_KHR`。通过设备地址访问缓冲区进行读取或写入，分别使用 `VK_ACCESS_TRANSFER_READ_BIT` 或 `VK_ACCESS_TRANSFER_WRITE_BIT` 的访问类型。

为了与光线追踪命令（`vkCmdTraceRaysKHR` 和 `vkCmdTraceRaysIndirectKHR`）同步依赖， `VK_PIPELINE_STAGE_RAY_TRACING_SHADER_BIT_KHR` 流水线阶段被用于访问着色器绑定表缓冲区，访问类型为 `VK_ACCESS_SHADER_READ_BIT`。对于间接参数的访问，使用 `VK_PIPELINE_STAGE_DRAW_INDIRECT_BIT` 流水线阶段，访问类型为 `VK_ACCESS_INDIRECT_COMMAND_READ_BIT`。

为了与任何图形、计算或光线追踪流水线阶段中用于光线查询指令的加速结构同步依赖关系，适当的流水线阶段与 `VK_ACCESS_ACCELERATION_STRUCTURE_READ_BIT_KHR` 访问类型应当一起使用。

![Comparing Vulkan Ray Tracing and DXR](https://www.khronos.org/assets/uploads/blogs/2020-Comparing-Vulkan-Ray-Tracing-and-DXR.-It-is-straightforward-to-port-code-between-the-two-APIs-including-re-use-of-ray-tracing-shaders-written-in-HLSL-5_.jpg)

# 结论与资源

现在，最终的 Vulkan 光线追踪扩展已经发布，目前支持临时规范的生态系统工件将尽快更新，工具和其他组件的推出将在 GitHub 上进行跟踪。我们鼓励所有开发者过渡到使用最终的 Khronos Vulkan 光线追踪扩展。

包括用于 NVIDIA GPU 的最终 Vulkan 光线追踪扩展的驱动程序可以在 developer.nvidia.com/vulkan-driver 上找到，同时还有关于哪些GPU受到支持的信息。支持这些扩展的 AMD GPU 的初始驱动程序可以在https://www.amd.com/en/support/kb/release-notes/rn-rad-win-20-11-2-vrt-beta。英特尔 Xe-HPG GPU 将支持光线追踪扩展，于2021年推出，并通过常规驱动更新程序提供驱动支持。

关于如何将 Vulkan 光线追踪用于混合渲染的见解，其中光栅化和光线追踪被串联使用，以实现引人注目的视觉保真度和互动性，请查看 Vulkan 光线追踪混合渲染的最佳实践博客，其中讨论了光线追踪反射在《重返德军总部：新血缘》中使用最终扩展描述的光线追踪反射的实现。。

今天还发布了最新的 NVIDIA Vulkan 光线追踪教程，以及支持 Vulkan 光线追踪扩展的 NVIDIA Nsight 图形开发工具的 2020.6 版本。敬请关注更多即将发布的关于生产驱动、工具和示例的公告。

Vulkan 工作组很高兴能够让开发者和内容创作社区使用 Vulkan 光线追踪，我们欢迎任何反馈或问题。这些问题可以通过 Khronos 开发者 Slack 和 Vulkan GitHub 问题追踪器进行分享。

欢迎来到便携式、跨厂商、跨平台的光线追踪加速时代！
