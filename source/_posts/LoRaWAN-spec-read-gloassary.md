---
title: LoRaWAN specification 1.1 - Glossary
date: 2020-05-16 10:27:00
tags:
- LoRaWAN
- LoRa
- IoT
categories:
- LoRa
---


| Abbreviation |                   Full text                    |     中文     |
|--------------|------------------------------------------------|--------------|
| ADR          | Adaptive Data Rate                             | 自适应数据速率 |
| AES          | Advanced Encryption Standard                   | 高级加密标准  | 
| AFA          | Adaptive Frequency Agility                     | 自适应频率捷变 |
| AR           | Acknowledgement Request                        | 确认请求      |
| CBC          | Cipher Block Chaining                          | 密码块链接    |
| CMAC         | Cipher-based Message Authentication Code       | 基于密码的消息认证代码 |
| CR           | Coding Rate                                    | 编码率 |
| CRC          | Cyclic Redundancy Check                        | 循环冗余校验 |
| DR           | Data Rate                                      | 数据速率 |
| ECB          | Electronic Code Book                           | 电子密码本 |
| ETSI         | European Telecommunications Standards Institute| 欧洲电信标准协会  |
| EIRP         | Equivalent Isotropically Radiated Power        | 等效各向同性辐射功率 |
| FSK          | Frequency Shift Keying modulation technique    | 频移键控调制技术 |
| GPRS         | General Packet Radio Service                   | 通用分组无线业务 |
| HAL          | Hardware Abstraction Layer                     | 硬件抽象层 |
| IP           | Internet Protocol                              | 互联网协议 |
| LBT          | Listen Before Talk / Listen Before Transmit    | 先听后发 |
| LoRaTM       | Long Range modulation technique                | 长程调制技术 |
| LoRaWANTM    | Long Range Network protocol                    | 长程网络协议 |
| MAC          | Medium Access Control                          | 介质访问控制 |
| MIC          | Message Integrity Code                         | 消息完整性码 |
| RF           | Radio Frequency                                | 无线电频率 |
| RFU          | Reserved for Future Usage                      | 保留以备将来使用 |
| Rx           | Receiver                                       | 接受端 |
| RSSI         | Received Signal Strength Indicator             | 接收信号强度指示器 |
| SF           | Spreading Factor                               | 扩频因子 |
| SNR          | Signal Noise Ratio                             | 信噪比 |
| SPI          | Serial Peripheral Interface                    | 串行外设接口 |
| SSL          | Secure Socket Layer                            | 安全套结层 |
| Tx           | Transmitter                                    | 发送端 |
| USB          | Universal Serial Bus                           | 通用串行总线 |

# Extra 补充内容

## Block cipher mode of operation 分组密码工作模式

In cryptography, a block cipher mode of operation is an algorithm that uses a block cipher to provide information security such as confidentiality or authenticity.

| Mode         |	Formulas                                    |  Ciphertext  |
|--------------|------------------------------------------------|--------------|
|Electronic codebook (ECB) |	Yi = F(PlainTexti, Key) |	Yi |
|Cipher block chaining (CBC) |	Yi = PlainTexti XOR Ciphertexti−1 |	F(Y, Key); |Ciphertext0=IV | 
| Propagating CBC (PCBC) |	Yi = PlainTexti XOR (Ciphertexti−1 XOR PlainTexti−1) |	F(Y, Key); Ciphertext0 = IV |
| Cipher feedback (CFB)  |	Yi = Ciphertexti−1 |	Plaintext XOR F(Y, Key); Ciphertext0 = IV |
| Output feedback (OFB)  |	Yi = F(Yi−1, Key); Y0 = IV |	Plaintext XOR Yi |
| Counter (CTR) |	Yi = F(IV + g(i), Key); IV = token() |	Plaintext XOR Yi |

### ECB

The simplest of the encryption modes is the electronic codebook (ECB) mode (named after conventional physical codebooks). The message is divided into blocks, and each block is encrypted separately. 

最简单的加密模式即为电子密码本（Electronic codebook，ECB）模式。需要加密的消息按照块密码的块大小被分为数个块，并对每个块进行独立加密。

### CBC

Ehrsam, Meyer, Smith and Tuchman invented the cipher block chaining (CBC) mode of operation in 1976. In CBC mode, each block of plaintext is XORed with the previous ciphertext block before being encrypted. This way, each ciphertext block depends on all plaintext blocks processed up to that point. To make each message unique, an initialization vector must be used in the first block. 

1976年，IBM发明了密码分组链接（CBC，Cipher-block chaining）模式。在CBC模式中，每个明文块先与前一个密文块进行异或后，再进行加密。在这种方法中，每个密文块都依赖于它前面的所有明文块。同时，为了保证每条消息的唯一性，在第一个块中需要使用初始化向量。 

### Others 其他加密方式

Propagating cipher block chaining (PCBC)
Cipher feedback (CFB)
Output feedback (OFB)
Counter (CTR)

# Listen Before Talk/Transmit 先听后发

Listen Before Talk (LBT) or sometimes called Listen Before Transmit is a technique used in radio-communications whereby a radio transmitters first sense its radio environment before it starts a transmission. LBT can be used by a radio device to find a network the device is allowed to operate on or to find a free radio channel to operate on. Difficulty in the latter situation is the signal threshold down to which the device has to listen. 

“先听后说”（LBT）或有时称为“先听后发”是无线电通信中使用的一种技术，通过该技术，无线电发射机在开始传输之前首先会感知其无线电环境。

无线电设备可以使用 LBT 完成：

1. 查找允许该设备运行的网络
2. 或者找到要运行的空闲无线电信道。

后一种情况的困难在于设备必须监听信号阈值。

# LoRa Modulation

## Spreading Factor 扩频因子

LoRa 扩频调制技术采用多个信息码片来代表有效负载信息的每个位。扩频信息的发送速度称为符号速率(Rs)，而码片速率与标称符号速率之间的比值即为扩频因子，其表示每个信息位发送的符号数量。LoRaTM 调制解调器中扩频因子的取值范围见下表。扩频因子为6时，LoRa 的数据传输速率最快。
 

注意：因为不同的SF之间为正交关系，因此必须提前获知链路发送端和接收端的SF。另外，还必须获知接受机输入端的信噪比。。在负信噪比条件下信号也能正常接收，这改善了LoRa接受机的灵敏度，链路预算及覆盖范围。
 

## 扩频调制带宽(BW)

增加带宽，可以提高有效数据速率以缩短传输时间，但是会牺牲接收灵敏度。
 
LoRa符号速率Rs可以通过以下公式计算：

$$
Rs= \frac{BW}{2^s}
$$

每Hz每秒发送一个码片。
 
LoRa 数据速率 DR 可以通过以下公式计算：

$$
DR = SF* \frac{BW}{2^s} * CR
$$

LoRa 扩频技术一经推出，就凭借它惊人的灵敏度(-148dbm)、强悍的抗干扰能力、出色的系统容量表现，赢得了广泛的关注。说通俗点，LoRa扩频技术改变了传输功耗和传输距离之间的平衡，彻底改变了嵌入式无线通信领域的局面。它给人们呈现了一个能实现远距离、长电池寿命、大系统容量、低硬件成本的全新通信技术，而这正是物联网(IoT)所需要的。


## LoRa扩频原理

常规的数字数据通信原理是使用与数据速率相适应的尽可能小的带宽。这是因为带宽数是有限的，而且有很多的用户要分享。
 
扩频通信的原理是尽可能使用最大带宽数, 同样的能量在一个大的带宽上传播。这里扩频带宽的很小部分与常规无线信号相干扰， 但常规无线信号不影响扩频信号，这是因为两者相比常规信号带宽很窄。
 
为何使用扩频技术:

1. 扩大带宽、减少干扰。当扩频因子为1时，数据1就用“1”来表示，扩频因子为4时，可能用“1011”来表示1，这样传输的时候可以降低误码率也就是信噪比，但是却减少了可以传输的实际数据，所以，扩频因子越大，传输的数据数率就越小。

2. 根据对速率的不同要求分配不同数量的码道，提高利用率。扩频因子还有另一个用途，那就是`正交码(OVSF: Orthogonal Variable Spreading Factor ，正交可变扩频因子)`，通过OVSF可以获得正交的扩频码，扩频因子为4时有4个正交的扩频码，正交的扩频码可以让同时传输的无线信号互不干扰，也就是说，扩频因子为4时，可以同时传输4个人的信息。

One of references: [
Data Rate and Spreading Factor](https://docs.exploratory.engineering/lora/dr_sf/)
