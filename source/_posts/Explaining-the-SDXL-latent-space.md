---
title: 【译】解释 SDXL 的隐空间
date: 2024-02-18 03:57:50
tags:
- AI
- Stable Diffusion
- SDXL
- 中文
- 翻译
categories:
- [AI, Stable Diffusion]
---

原文地址：https://huggingface.co/blog/TimothyAlexisVass/explaining-the-sdxl-latent-space

# 简短的背景

特别感谢 Ollin Boer Bohan Haoming、 Cristina Segalin 和 Birchlabs 提供的信息、讨论和知识帮助！

我正在为 [SDXL 推理过程创建校正滤波器](https://huggingface.co/blog/TimothyAlexisVass/explaining-the-sdxl-latent-space#udi-sdxl-correction-filters)，以用于我为扩散模型创建的用户界面。

在拥有多年的图像校正经验后，我希望能够从根本上改进 SDXL 的实际输出。要创建的用户界面中有许多我想要的技术，我开始着手自己解决这些问题。我注意到，SDXL 的输出几乎总是有规律地出现噪点或过于平滑。由于标清模型的工作原理，色彩空间总是需要白平衡，色彩范围有偏差和限制。

如果可以在实际输出之前改善信息和色彩范围，那么在图像生成并转换为 8 位 RGB 之后的后期处理中进行修正就没有什么意义了。

要创建滤镜和修正工具，最重要的是要了解你正在处理的数据。这促使我开始对 SDXL 的隐层进行实验性探索，以期了解它们。基于 SDXL 架构的扩散模型所使用的张量如下所示：

```
[batch_size, 4 channels, height (y), width (x)]
```

我的第一个问题很简单：“这 4 个通道到底是什么？”

我得到的大多数回答都是“这不是人类能理解的东西”。但我认为这绝对是可以理解的，甚至是非常容易理解和有用的知识。

# SDXL 隐层的 4 个通道

对于由 SDXL 生成的 1024×1024 像素的图像，隐层的张量为 128×128 像素，其中隐空间中的每个像素代表像素空间中的 64 (8×8) 个像素。如果我们将隐层生成并解码为标准的 8 位 jpg 图像，那么：

## 8 位像素空间拥有 3 个通道

红色 (R)、绿色 (G) 和蓝色 (B)，每个通道有 256 个可能的值，范围在 0-255 之间。因此，要存储 64 个像素的全部信息，我们需要在每个隐层像素的每个通道中存储 64×256 = 16384 个值。

图像的 SDXL 隐层表示有 4 个通道：

1. 0：亮度
2. 1：青色/红色 => 相当于 rgb(0, 255, 255)/rgb(255, 0, 0)
3. 2：淡紫色/中紫色 => 相当于 rgb(127, 255, 0)/rgb(127, 0, 255)
4. 3：图案/结构。

如果在解码时每个值的范围都在 -4 和 4 之间，那么在半精度的 16 位浮点格式中，每个隐层像素的 4 个通道都可以包含 16384 个不同的值。

## 通过线性近似将 SDXL 潜在像素直接转换为 RGB

有了这种理解，我们就可以创建一个近似函数，将隐层像素直接转换为 RGB：

```python
def latents_to_rgb(latents):
    weights = (
        (60, -60, 25, -70),
        (60,  -5, 15, -50),
        (60,  10, -5, -35)
    )

    weights_tensor = torch.t(torch.tensor(weights, dtype=latents.dtype).to(latents.device))
    biases_tensor = torch.tensor((150, 140, 130), dtype=latents.dtype).to(latents.device)
    rgb_tensor = torch.einsum("...lxy,lr -> ...rxy", latents, weights_tensor) + biases_tensor.unsqueeze(-1).unsqueeze(-1)
    image_array = rgb_tensor.clamp(0, 255)[0].byte().cpu().numpy()
    image_array = image_array.transpose(1, 2, 0)  # Change the order of dimensions

    return Image.fromarray(image_array)
```

## SDXL 色彩范围偏向黄色的可能原因

自然界中蓝色或白色的东西相对较少。在天空中，这些颜色在宜人的条件下最为突出。因此，通过图像了解现实的模型会以亮度（通道 0）、青色/红色（通道 1）和淡紫色/中紫色（通道 2）来思考，其中红色和绿色为主，蓝色为辅。

**这就是为什么 SDXL 生成往往偏向于黄色（红+绿）。**

在推理过程中，张量中的值将从最小值 -30 和最大值 30 开始，解码时的最小/最大边界约为 -4 至 4。

理解这些边界的一个关键是看解码过程中发生了什么：

```python
decoded = vae.decode(latents / vae.scaling_factor).sample # (SDXL vae.scaling_factor = 0.13025)
decoded = decoded.div(2).add(0.5).clamp(0, 1) # The dynamics outside of 0 to 1 at this point will be lost
```

如果这一点上的值超出了 0 到 1 的范围，就会丢失一些信息。因此，如果我们能在去噪过程中进行修正，以满足 VAE 的期望，我们可能会得到更好的结果。

# 什么需要修正？

如何锐化模糊的图像、进行白平衡、改善细节、增加对比度或扩大色彩范围？最好的方法是从清晰的图像开始，图像白平衡正确，对比度高，细节清晰，范围大。

模糊清晰的图像、改变色彩平衡、降低对比度、获得不合理的细节和限制色彩范围远比改善图像要容易得多。

SDXL 有一个非常明显的倾向，就是色彩偏差和将数值置于实际边界之外（上图）。将数值居中并使其在边界内（下图），就可以轻松解决这个问题：

![](https://cdn-uploads.huggingface.co/production/uploads/64e0903c4c78e1eba50b47fa/PIDEjtCUDjeA-vqTpHSE4.jpeg)


![](https://cdn-uploads.huggingface.co/production/uploads/64e0903c4c78e1eba50b47fa/3Y0omWaPai6c-zU_rNNpC.jpeg)

这段代码可以将颜色修正：

```python
def center_tensor(input_tensor, per_channel_shift=1, full_tensor_shift=1, channels=[0, 1, 2, 3]):
    for channel in channels:
        input_tensor[0, channel] -= input_tensor[0, channel].mean() * per_channel_shift
    return input_tensor - input_tensor.mean() * full_tensor_shift
```

# SDXL 的示例输出的例子

生成时使用的随机数、参数和 prompt 如下：

```
seed: 77777777
guidance_scale: 20 # A high guidance scale can be fixed too
steps with base: 23
steps with refiner: 10

prompt: Cinematic.Beautiful smile action woman in detailed white mecha gundam armor with red details,green details,blue details,colorful,star wars universe,lush garden,flowers,volumetric lighting,perfect eyes,perfect teeth,blue sky,bright,intricate details,extreme detail of environment,infinite focus,well lit,interesting clothes,radial gradient fade,directional particle lighting,wow

negative_prompt: helmet, bokeh, painting, artwork, blocky, blur, ugly, old, boring, photoshopped, tired, wrinkles, scar, gray hair, big forehead, crosseyed, dumb, stupid, cockeyed, disfigured, crooked, blurry, unrealistic, grayscale, bad anatomy, unnatural irises, no pupils, blurry eyes, dark eyes, extra limbs, deformed, disfigured eyes, out of frame, no irises, assymetrical face, broken fingers, extra fingers, disfigured hands
```

请注意，我特意选择了较高的引导比例（guidance_scale 参数）。

如何修复这张图片？它一半是绘画，一半是照片。色彩范围偏向黄色。下边是设置完全相同的修复后的生成图像。

![](https://cdn-uploads.huggingface.co/production/uploads/64e0903c4c78e1eba50b47fa/jBMIbZgnxebjU1eQ2jZo_.jpeg)

![](https://cdn-uploads.huggingface.co/production/uploads/64e0903c4c78e1eba50b47fa/lcWkMaCh4Cl3UwHNJMe_k.jpeg)

但是，如果将 `guidance_scale` 设置为 7.5，我们仍然可以得出这样的结论：修复后的输出效果更好，没有不合理的细节，白平衡也正确。

我们可以在潜空间中做很多事情来普遍改进一次生成，也可以针对一次生成中的特定错误做一些非常简单的事情来进行修复：

## 离群值去除

这将通过修剪离分布平均值最远的值来控制不合理细节的数量。它还有助于以更高的引导比例（guidance_scale 参数）生成。

```python
# Shrinking towards the mean (will also remove outliers)
def soft_clamp_tensor(input_tensor, threshold=3.5, boundary=4):
    if max(abs(input_tensor.max()), abs(input_tensor.min())) < 4:
        return input_tensor
    channel_dim = 1

    max_vals = input_tensor.max(channel_dim, keepdim=True)[0]
    max_replace = ((input_tensor - threshold) / (max_vals - threshold)) * (boundary - threshold) + threshold
    over_mask = (input_tensor > threshold)

    min_vals = input_tensor.min(channel_dim, keepdim=True)[0]
    min_replace = ((input_tensor + threshold) / (min_vals + threshold)) * (-boundary + threshold) - threshold
    under_mask = (input_tensor < -threshold)

    return torch.where(over_mask, max_replace, torch.where(under_mask, min_replace, input_tensor))
```

## 色彩平衡和增加范围

我有两种主要方法来实现这一目标。第一种是在对数值进行归一化处理时向平均值收缩（这也会去除异常值），第二种是在数值偏向某种颜色时进行修正。这也有助于以更高的指导尺度生成。

```python
# Center tensor (balance colors)
def center_tensor(input_tensor, channel_shift=1, full_shift=1, channels=[0, 1, 2, 3]):
    for channel in channels:
        input_tensor[0, channel] -= input_tensor[0, channel].mean() * channel_shift
    return input_tensor - input_tensor.mean() * full_shift
```

## 张量最大化

这基本上是通过将张量乘以一个非常小的量，如 1e-5，进行几个步骤，并确保最终张量在转换为 RGB 之前使用了全部可能的范围（接近 -4/4）。请记住，在像素空间中，用完整的动态降低对比度、饱和度和锐度比增加对比度、饱和度和锐度更容易。

```python
# Maximize/normalize tensor
def maximize_tensor(input_tensor, boundary=4, channels=[0, 1, 2]):
    min_val = input_tensor.min()
    max_val = input_tensor.max()

    normalization_factor = boundary / max(abs(min_val), abs(max_val))
    input_tensor[0, channels] *= normalization_factor

    return input_tensor
```

## 回调实现示例

```python
def callback(pipe, step_index, timestep, cbk):
    if timestep > 950:
        threshold = max(cbk["latents"].max(), abs(cbk["latents"].min())) * 0.998
        cbk["latents"] = soft_clamp_tensor(cbk["latents"], threshold*0.998, threshold)
    if timestep > 700:
        cbk["latents"] = center_tensor(cbk["latents"], 0.8, 0.8)
    if timestep > 1 and timestep < 100:
        cbk["latents"] = center_tensor(cbk["latents"], 0.6, 1.0)
        cbk["latents"] = maximize_tensor(cbk["latents"])
    return cbk

image = base(
    prompt,
    guidance_scale = guidance_scale,
    callback_on_step_end=callback,
    callback_on_step_end_inputs=["latents"]
).images[0]
```

这三种方法的简单实现被用于最后一组图像，即[花园中的妇女](#高指导尺度下的长提示成为可能)。

# 增加色彩范围/消除色彩偏差

在常规输出中，SDXL 将颜色范围限制为红色和绿色。因为提示中没有任何内容表明有蓝色这种东西。这是相当不错的一次生成，但颜色范围却受到了限制。

如果你给别人一个黑色、红色、绿色和黄色的调色板，然后告诉他要画出晴朗的蓝天，那么很自然的反应就是要求你提供蓝色和白色。

要在生成中包含蓝色，我们只需在色彩空间受限时重新调整色彩空间，SDXL 就会在生成中适当地包含完整的色彩光谱。

# 高指导尺度下的长提示成为可能

下面是一个典型的例子，颜色范围的增加使整个提示词成为可能，本示例应用了前面所示的[简单、生硬的修改](#回调实现示例)，以更清楚地说明两者的区别：

```
prompt: Photograph of woman in red dress in a luxury garden surrounded with blue, yellow, purple and flowers in many colors, high class, award-winning photography, Portra 400, full format. blue sky, intricate details even to the smallest particle, extreme detail of the environment, sharp portrait, well lit, interesting outfit, beautiful shadows, bright, photoquality, ultra realistic, masterpiece
```

![](https://cdn-uploads.huggingface.co/production/uploads/64e0903c4c78e1eba50b47fa/KTjI5LkGBaR1GarQpzTLq.jpeg)

![](https://cdn-uploads.huggingface.co/production/uploads/64e0903c4c78e1eba50b47fa/5w4_PvycQsDNw2OaUelOD.jpeg)

