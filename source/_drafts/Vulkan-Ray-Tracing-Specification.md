---
title: 【译】Vulkan 光线追踪
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


Overview

Today, Khronos® has released the final versions of the set of Vulkan®, GLSL and SPIR-V extension specifications that seamlessly integrate ray tracing into the existing Vulkan framework. This is a significant milestone as it is the industry’s first open, cross-vendor, cross-platform standard for ray tracing acceleration - and can be deployed either using existing GPU compute or dedicated ray tracing cores. Vulkan Ray Tracing will be familiar to anyone who has used DirectX Raytracing (DXR) in DirectX 12, but also introduces advanced functionality such as the ability to load balance ray tracing setup operations onto the host CPU. Although ray tracing will be first deployed on desktop systems, these Vulkan extensions have been designed to enable and encourage ray tracing to also be deployed on mobile.

These extensions were initially released as provisional versions in March 2020. Since that time (see Figure 1), we have received and incorporated feedback from hardware vendors and software developers, both inside Khronos and from the wider industry, but the overall shape of the API and the functionality provided are fundamentally unchanged. Thank you to all who reviewed and used the provisional extensions and especially those who provided feedback!

![Vulkan Ray Tracing Dev Timeline](https://www.khronos.org/assets/uploads/blogs/2020-Vulkan-Ray-Tracing-development-timeline-1.jpg)

Today’s release of the extension specifications is just the start of the rollout of Vulkan Ray Tracing. Over the coming days and weeks, additional ecosystem components such as shader toolchains and validation layers will be updated with support for ray tracing functionality to ensure developers can easily use these extensions in their applications. Progress on these ecosystem updates can be tracked in GitHub. This will culminate with the release of the Vulkan SDK (1.2.162.0 or later) with Khronos Vulkan Ray Tracing support in mid-December.

This post will highlight the most important differences between the provisional and final versions of the Vulkan Ray Tracing extensions and explain some of the reasoning behind the changes.

Show Me the Specs!

The overall functionality provided by the set of Vulkan Ray Tracing extensions is unchanged since their provisional versions. The final set of extensions released today is:

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

Extension Structure

The most obvious change is that the provisional VK_KHR_ray_tracing extension has been split into 3 extensions:

    VK_KHR_acceleration_structure - for acceleration structure building and management
    VK_KHR_ray_tracing_pipeline - for ray tracing shader stages and pipelines, and
    VK_KHR_ray_query - providing ray query intrinsics for all shader stages.

We received feedback that some markets desired the ability to support ray queries without ray pipelines, and the original extension was subdivided in order to avoid duplication and artificial dependencies. Implementers may choose to support either VK_KHR_ray_tracing_pipeline, VK_KHR_ray_query, or both, depending on market needs. Both of these extensions depend on the VK_KHR_acceleration_structure extension to provide a common base for acceleration structure management. The major desktop vendors remain committed to supporting ray pipelines and ray queries. For specifics of support for optional features and support in other markets, please talk to individual vendors.

The Vulkan Ray Tracing extensions are no longer marked as provisional and so the extension interfaces for the five extensions are now defined in the main vulkan_core.h header instead of the provisional vulkan_beta.h, and users no longer need to #define VK_ENABLE_BETA_EXTENSIONS to enable the Vulkan Ray Tracing functionality.

The dependencies for the extensions have also changed. Vulkan 1.1 and SPIR-V 1.4 are now required. VK_KHR_acceleration_structure requires Vulkan 1.1, VK_EXT_descriptor_indexing, VK_KHR_buffer_device_address, and VK_KHR_deferred_host_operations. We realize that a lengthy list of extension dependencies is annoying and ideally would have liked to simply require Vulkan 1.2, but not all platforms are shipping Vulkan 1.2 support at this time and we do not want to add any artificial barriers for adopting ray tracing functionality. Applications are able to just target Vulkan 1.2 directly for simplicity, if supported by all their target markets. We also considered not making VK_KHR_deferred_host_operations an explicit dependency, but changes to the pipeline creation with deferred operations required it to be kept. We made VK_KHR_pipeline_library a soft requirement for VK_KHR_ray_tracing_pipeline instead of a strict requirement, so applications only need to enable it if they are actually using it. In addition to VK_KHR_acceleration_structure, VK_KHR_ray_tracing_pipeline and VK_KHR_ray_query both require SPIR-V 1.4 at a minimum, due to changes in entry point requirements that were added in that version. SPIR-V 1.5 can also be used on Vulkan 1.2 implementations.

Featurewise, the following is mandated for all implementations.

VK_KHR_acceleration_structure requires:

    VK_KHR_deferred_host_operations
    accelerationStructure,
    descriptorBindingAccelerationStructureUpdateAfterBind,
    all the features required by the descriptorIndexing feature (if Vulkan 1.2 is supported) or the VK_EXT_descriptor_indexing extension, and
    bufferDeviceAddress from Vulkan 1.2 or the VK_KHR_buffer_device_address

Implementations that support VK_KHR_ray_tracing_pipeline require:

    VK_KHR_acceleration_structure,
    rayTracingPipeline,
    rayTracingPipelineTraceRaysIndirect,
    rayTraversalPrimitiveCulling, if VK_KHR_ray_query is also supported, and
    VK_KHR_pipeline_library.

Implementations that support VK_KHR_ray_query require:

    VK_KHR_acceleration_structure, and
    rayQuery.

Additionally there are a number of optional capabilities defined with the extensions.

For VK_KHR_acceleration_structure these are:

    accelerationStructureCaptureReplay,
    accelerationStructureIndirectBuild, and
    accelerationStructureHostCommands.

For VK_KHR_ray_tracing_pipeline these are:

    rayTracingPipelineShaderGroupHandleCaptureReplay,
    rayTracingPipelineShaderGroupHandleCaptureReplayMixed, and
    rayTraversalPrimitiveCulling, if VK_KHR_ray_query is not supported.

Acceleration Structures

The change in the final Vulkan Ray Tracing functionality that will have the most impact on applications is the creation and layout of acceleration structures.

We received feedback from authors of API translation layers (such as vkd3d-proton) that it would be impractical to layer DXR on top of the provisional API Vulkan Ray Tracing acceleration structure. This resulted in changes to a sized acceleration structure creation and using allocation of acceleration structure storage on a VkBuffer instead of dedicated acceleration structure object storage. One impact of these changes is that the VkAccelerationStructureKHR and VkAccelerationStructureNV handles are no longer aliases and cannot be used interchangeably. Similarly any structures or functions which take them as parameters are also no longer aliased.

We also added a new acceleration structure type for layering - VK_ACCELERATION_STRUCTURE_TYPE_GENERIC_KHR. This can be used at acceleration structure creation time in cases where the actual acceleration structure type (top or bottom) is not yet known. The actual acceleration structure type must be specified as VK_ACCELERATION_STRUCTURE_TYPE_TOP_LEVEL_KHR or VK_ACCELERATION_STRUCTURE_TYPE_BOTTOM_LEVEL_KHR when the build is performed and cannot be changed. Applications written directly for Vulkan should not use VK_ACCELERATION_STRUCTURE_TYPE_GENERIC_KHR as this could affect capabilities or performance in the future.

We also received feedback from authors of layered Vulkan implementations (such as MoltenVK) indicating that some ray tracing requirements (such as device addresses) would make it impossible to implement Vulkan in a layered fashion on some other APIs. Unfortunately it is impossible to address this while also supporting other goals like feature parity with DXR. We hope that future versions of other APIs will add the necessary features to enable this layering as well.

We heard that developers really preferred unified creation and build parameters, as in VK_NV_ray_tracing and DXR. We changed the acceleration structure creation to be based on size, and the size can be calculated from the same structure that is used for builds (vkGetAccelerationStructureBuildSizesKHR), or from a compaction query (vkCmdWriteAccelerationStructuresPropertiesKHR). We also learned that some implementations needed additional information at creation time, and this resulted in the addition of pMaxPrimitiveCounts to vkGetAccelerationStructureBuildSizesKHR.

Some aspects of the previous geometry descriptions were confusing and did not work well with auto-generated code (like validation layers), and so we resolved the ambiguities caused by the ppGeometries duality, and added an additional pGeometries field but require that only one of these fields be used at a time.

Other additions included: creation time capture and replay flags for acceleration structures (for debug tools), nullDescriptor support for accelerations structures as an interaction with VK_EXT_robustness2 and VK_DESCRIPTOR_SET_LAYOUT_CREATE_UPDATE_AFTER_BIND_POOL_BIT support for acceleration structures.

Last but not least, we made changes to use device addresses consistently throughout all the extensions. There were also many naming suggestions made, some which where taken, and various naming and stylistic changes were made for reasons of consistency and extensibility. For more details on these and other changes made, see Issues 3 & 4 and the changelog in VK_KHR_acceleration_structure.
Deferred Host Operations

We revamped the way that deferred host operations are used with the vkBuildAccelerationStructuresKHR and vkCreateRayTracingPipelinesKHR commands. Instead of chaining the deferred operation request into the pNext of each individual build or create operation, the deferral request is now passed in as a top-level parameter of the command and the whole command is either deferred or not. When the command is deferred, the application must not access the return parameters until the deferred operation is complete. The prior semantics of the commands when some sub-operations could be deferred and not others made for unclear behavioral expectations on the command return values and it was difficult to understand when it was safe to access them. We believe that the new semantics are clearer and should enable greater opportunities for parallelism, but as noted above this comes at the expense of requiring the VK_KHR_deferred_host_operations extension to be enabled at all times.

![Deferred Host Operations](https://www.khronos.org/assets/uploads/blogs/2020-Deferred-Host-Operations-enable-Acceleration-Structures-to-be-built-using-multiple-CPU-cores-for-faster-frame-rates-and-elimination-of-frame-stuttering-2.jpg)

Ray Tracing Pipelines

The changes to the ray tracing pipeline mechanisms were not as drastic, and some of them only impact SPIR-V and the shader compiler toolchains.

In addition to the changes to vkCreateRayTracingPipelinesKHR mentioned above for deferred operations, there were also changes to make VkPipelineLibraryCreateInfoKHR and VkRayTracingPipelineInterfaceCreateInfoKHR optional so that VK_KHR_pipeline_library does not need to be enabled if they are not being used.

The biggest API change for ray tracing pipelines was the addition of explicit stack size management. Ray tracing pipelines have a potentially large set of shaders which may be invoked in various call chain combinations during ray tracing. The implementation may use a stack to store parameters in memory during a given shader execution and this stack needs to be sized to be large enough to handle the stack sizes required for all shaders in any call chain which can be executed by the implementation. The default stack size is potentially quite large, so we added a way for the application to specify a more optimal stack size after pipeline compilation. This is used in the cases where the application can compute a tighter stack size bound based on application-specific knowledge of the shaders and the properties of the call chains. A new dynamic state (VK_DYNAMIC_STATE_RAY_TRACING_PIPELINE_STACK_SIZE_KHR) was added for ray tracing pipelines along with commands to query the stack size of a shader group (vkGetRayTracingShaderGroupStackSizeKHR) and to set the dynamic stack size for a pipeline (vkCmdSetRayTracingPipelineStackSizeKHR).

Another added feature was based on feedback from DXR layering efforts, namely the ability to trace rays by acceleration structure address. With this functionality, the device address of an acceleration structure that has been retrieved from vkGetAccelerationStructureDeviceAddressKHR can be stored in a buffer or other shader resource. In the shader, it can be converted into the opaque OpTypeAccelerationStructureKHR descriptor type using the SPIR-V OpConvertUToAccelerationStructureKHR instruction (which manifests as the accelerationStructureEXT type constructor in GLSL). The resulting variable can then be used to specify the acceleration structure to trace into for the OpTraceRayKHR instruction (traceRayEXT()). This conversion is one-way, and no other operations are supported on the opaque acceleration structure descriptors.

![Ray tracing pipelines](https://www.khronos.org/assets/uploads/blogs/2020-Ray-tracing-pipelines-provide-implicit-management-of-ray-intersections-3.jpg)

The SPIR-V working group also provided feedback on the SPIR-V extensions, and this resulted in changes to the Payload parameter to OpTraceRayKHR and the Callable Data parameter to OpExecuteCallableKHR. Previously, these parameters matched the declared location layout qualifier of the payload or callable data structure, as declared in GLSL. However, these locations were not meaningful in SPIR-V and thus were replaced with pointers to the appropriate storage class directly instead of using integer locations. This has no impact on the GLSL extension as glslang handles the conversion automatically, however, this did require new opcodes for OpTraceRayKHR and OpExecuteCallableKHR, which can no longer be aliased to the corresponding operations from SPV_NV_ray_tracing.

Another SPIR-V change driven by internal feedback was making OpIgnoreIntersectionKHR and OpTerminateRayKHR into termination instructions because they terminate the invocation that executes them. These must also be the last instruction in a block. Again, this resulted in new opcodes being assigned to these instructions. This change did impact GLSL -- instead of being built-in functions these are now jump statements, and so instead of appearing as ignoreIntersectionEXT(); it is now simply ignoreIntersectionEXT; when used in a shader.

Wrapping up the SPIR-V changes for ray tracing pipelines, there is a new capability and enum (RayTracingKHR) which enables implementations and tool-chains to distinguish between SPIR-V authored for the now obsoleted provisional extension and the final semantics. There were also a number of clarifications made to required explicit layouts for ShaderRecordBufferKHR and to generally treat it the same as the StorageBuffer storage class. We also specified the behavior for the return value and out of range T values for OpReportIntersectionKHR, and we clarified that only a subset of bits are used for various ray tracing parameters.

As with the VK_KHR_acceleration_structure extension, we made changes to use buffer device addresses exclusively and thus the shader binding tables are now provided as buffer device addresses to the trace rays commands via the VkStridedDeviceAddressRegionKHR structure. Similarly, the indirect parameters to vkCmdTraceRaysIndirectKHR are passed via buffer device address.

We also updated the interactions with Vulkan 1.2 and the VK_KHR_vulkan_memory_model extension, and require certain builtin variables (primarily subgroup related) to be marked as Volatile in shaders which support shader calls.

Other changes included adding creation time capture and replay flags for shader group handles, adding various properties and limits that were previously missed, and some renaming for improved clarity. For more details on these and other changes made, see Issues 3 & 4 in VK_KHR_ray_tracing_pipeline, Issue 2 of SPV_KHR_ray_tracing, and the extension changelogs.
Ray Queries

Given that there is very little Vulkan API surface for ray queries, most of the changes related to ray queries were in the SPIR-V extensions and interactions.

SPV_KHR_ray_query also includes support for issuing ray queries by acceleration structure address, and adds OpConvertUToAccelerationStructureKHR which can similarly be used to convert acceleration structure device addresses to opaque OpTypeAccelerationStructureKHR descriptors. These can then be used to specify the acceleration structure to trace for OpRayQueryInitializeKHR.

As with ray pipelines, there is a new capability and enum (RayQueryKHR) which enables implementations and tool-chains to distinguish between SPIR-V authored for the now obsoleted provisional extension and the final semantics. We also clarified that only a subset of bits are used for cull mask, and disallowed querying the candidate T value from AABB primitives.

Finally, we also specified numerical limits for ray parameters, required HitT to be in the ray interval for OpRayQueryGenerateIntersectionKHR, and restricted traces to top-level acceleration structures.

For more details on these and other changes made, see Issue 1 in VK_KHR_ray_query, Issue 1 in SPV_KHR_ray_query, and the extension changelogs.

![Ray Queries](https://www.khronos.org/assets/uploads/blogs/2020-Ray_Queries_provide_explicit_ray_management_from_within_any_shader-4.jpg)

This is the Way

This section gives an overview of the new flow for acceleration structure creation and includes a quick primer on resource creation flags and ray tracing synchronization.
Acceleration Structure Creation

To create an acceleration structure, the application must first determine the sizes required for the acceleration structure. For builds, the size of the acceleration structure and the scratch buffer sizes for builds and updates are obtained in the VkAccelerationStructureBuildSizesInfoKHR structure via the vkGetAccelerationStructureBuildSizesKHR command. The shape and type of the acceleration structure to be created is described in VkAccelerationStructureBuildGeometryInfoKHR structure. This is the same structure that will later be used for the actual build, but the acceleration structure parameters and geometry data pointers do not need to be fully populated at this point (although they can be), just the acceleration structure type, and the geometry types, counts, and maximum sizes. These sizes are valid for any sufficiently similar acceleration structure. For acceleration structures that are going to be the target of a compacting copy, the required size can be obtained via the vkCmdWriteAccelerationStructuresPropertiesKHR command. Once the required sizes have been determined, the application creates a VkBuffer for the acceleration structure (accelerationStructureSize), and VkBuffer(s) as needed for the build (buildScratchSize) and update (updateScratchSize) scratch buffers.

Next, the VkAccelerationStructureKHR object can be created using the vkCreateAccelerationStructureKHR command which creates an acceleration structure of the specified type and size and places it at offset within the buffer provided in VkAccelerationStructureCreateInfoKHR. Unlike most other resources in Vulkan, the specified portion of the buffer fully provides the memory for the acceleration structure; no additional memory requirements need to be queried or memory bound to the acceleration structure object. If desired, multiple acceleration structures can be placed in the same VkBuffer, provided the acceleration structures do not overlap.

Finally, the vkCmdBuildAccelerationStructuresKHR command can be used to build the acceleration structure. The build takes the same VkAccelerationStructureBuildGeometryInfoKHR structure that was used to determine the acceleration structure size, but this time the destination acceleration structure must be specified along with all geometry data pointers (for vertices, indices, transforms, aabbs, and instances) and scratch data pointers. Once the build has completed, the acceleration structure is completely self-contained, and build input and scratch buffers can be repurposed by the application unless it plans to use them for future update builds.
Resource Usage and Synchronization

This section provides a high-level overview of when the various buffer usage flags should be used, and a brief description of what types of synchronization should be used for the various ray tracing operations.

Buffers that will be used for the acceleration structure backing are created with the VK_BUFFER_USAGE_ACCELERATION_STRUCTURE_STORAGE_BIT_KHR usage, buffers that will be used for build scratch space need to specify that VK_BUFFER_USAGE_STORAGE_BUFFER_BIT usage, and acceleration structure build inputs such as vertex, index, transform, aabb, and instance data need to specify the VK_BUFFER_USAGE_ACCELERATION_STRUCTURE_BUILD_INPUT_READ_ONLY_BIT_KHR usage. Buffers that are used for the shader binding table are created with the VK_BUFFER_USAGE_SHADER_BINDING_TABLE_BIT_KHR usage and buffers used for indirect build and trace parameters are created with the VK_BUFFER_USAGE_INDIRECT_BUFFER_BIT usage.

To synchronize dependencies with the acceleration structure build commands (vkCmdBuildAccelerationStructuresKHR vkCmdBuildAccelerationStructuresIndirectKHR), the VK_PIPELINE_STAGE_ACCELERATION_STRUCTURE_BUILD_BIT_KHRpipeline stage is used. Accesses to the source or destination acceleration structures, and the scratch buffers use an access type of VK_ACCESS_ACCELERATION_STRUCTURE_READ_BIT_KHR or VK_ACCESS_ACCELERATION_STRUCTURE_WRITE_BIT_KHRas appropriate. Accesses to input buffers for the build (vertex, index, transform, aabb, or instance data) use an access type of VK_ACCESS_SHADER_READ_BIT and access to the indirect parameters use an access type of VK_ACCESS_INDIRECT_COMMAND_READ_BIT.

When synchronizing dependencies with the acceleration structure copy commands (vkCmdWriteAccelerationStructuresPropertiesKHR, vkCmdCopyAccelerationStructureKHR, vkCmdCopyAccelerationStructureToMemoryKHR, and vkCmdCopyMemoryToAccelerationStructureKHR) the VK_PIPELINE_STAGE_ACCELERATION_STRUCTURE_BUILD_BIT_KHR pipeline stage is also used. Accesses to acceleration structures for reading or writing use the VK_ACCESS_ACCELERATION_STRUCTURE_READ_BIT_KHR or VK_ACCESS_ACCELERATION_STRUCTURE_WRITE_BIT_KHR, respectively. Accesses to buffers via device addresses for reading or writing use an access type of VK_ACCESS_TRANSFER_READ_BIT or VK_ACCESS_TRANSFER_WRITE_BIT, respectively.

To synchronize dependencies with trace rays commands (vkCmdTraceRaysKHR and vkCmdTraceRaysIndirectKHR) the VK_PIPELINE_STAGE_RAY_TRACING_SHADER_BIT_KHR pipeline stage is used for accesses to the shader binding table buffers with an access type of VK_ACCESS_SHADER_READ_BIT. For accesses to the indirect parameter, the VK_PIPELINE_STAGE_DRAW_INDIRECT_BIT pipeline stage is used with an access type of VK_ACCESS_INDIRECT_COMMAND_READ_BIT.

To synchronize dependencies with acceleration structures that are used for ray query instructions in any graphics, compute, or ray tracing pipeline stage, the appropriate pipeline stage is used along with an access type of VK_ACCESS_ACCELERATION_STRUCTURE_READ_BIT_KHR.

![Comparing Vulkan Ray Tracing and DXR](https://www.khronos.org/assets/uploads/blogs/2020-Comparing-Vulkan-Ray-Tracing-and-DXR.-It-is-straightforward-to-port-code-between-the-two-APIs-including-re-use-of-ray-tracing-shaders-written-in-HLSL-5_.jpg)

Conclusion and Resources

Now that the final Vulkan Ray Tracing extensions have been published, ecosystem artifacts currently supporting the provisional specifications will be updated as quickly as possible, with the rollout of tooling and other components tracked on GitHub. We encourage all developers to transition to using the final Khronos Vulkan Ray Tracing extensions.

Drivers including the final Vulkan Ray Tracing extensions for NVIDIA GPUs can be found at developer.nvidia.com/vulkan-driver, together with information on which GPUs are supported. Initial drivers supporting these extensions for AMD GPUs can be found at https://www.amd.com/en/support/kb/release-notes/rn-rad-win-20-11-2-vrt-beta. The ray tracing extensions will be supported by Intel Xe-HPG GPUs, available in 2021, with driver support provided via the regular driver update process.

For insights on how to use Vulkan Ray Tracing for hybrid rendering, where rasterization and ray tracing are used in tandem to achieve compelling levels of visual fidelity and interactivity, check out the Vulkan Ray Tracing Best Practices for Hybrid Rendering blog that discusses the implementation of ray traced reflections in Wolfenstein: Youngblood described using the final extensions.

Also available today is an updated NVIDIA Vulkan Ray Tracing Tutorial and the 2020.6 release of the NVIDIA Nsight Graphics developer tool with support for the Vulkan Ray Tracing extensions. Be on the lookout for many more upcoming announcements about production drivers, tools, and samples!

The Vulkan Working Group is excited to enable the developer and content creation communities to use Vulkan Ray Tracing and we welcome any feedback or questions. These can be shared through the Khronos Developer Slack and Vulkan GitHub Issues Tracker.

Welcome to the era of portable, cross-vendor, cross-platform ray tracing acceleration!
