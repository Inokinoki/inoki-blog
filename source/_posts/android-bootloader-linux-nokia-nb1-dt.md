---
title: Android Bootloader and Linux Internal based on Nokia 8(NB1) —— Device Tree
date: 2022-05-09 20:48:00
tags:
- Android
- ABL
- Linux
- Bootloader
categories:
- [Linux, Android, Bootloader]
---

Context: I am working on porting Plasma Mobile and EDK II to my Nokia 8 (codename: NB1) device. There are many things to do and to learn.

In this post, I want to write down what I have learnt from the ABL Bootloader and the Linux kernel, about how the Device Tree(DT, which describes the periphicals in an embedded device) is processed by the ABL and the kernel.

# Introduction

The Nokia 8 device(and its successor Nokia 8 Sirocco) uses the MSM8998 SoC platform(or say Qualcomm 835) as a base. In fact, its company HMD just owns the Nokia trademark for mobile phone manufacture. The main design and development is by FIH Mobile, which is a subsidiary of Foxconn. So, we will say some modules named by the FIH in this post.

The model that I own is marked as "Qualcomm Technologies, Inc. MSM8998 v2.1 MTP, FIH NB1 PVT1 SS" in the DT. However, there are many DTs that are appended to the kernel, where it also has the ones for A1N(Nokia 8 Sirocco) and the evaluation version of these devices. These result in more than 80 different DTs, even including the different versions of MSM8998.

So, I wonder how the DT is actually choosed, by the Linux kernel, or by the Bootloader. And in which stage, during the early stage, the XBL or the ABL?

At very first, I thought that the DTs are appended to the kernel, so that the Bootloader(s) will not get involved very deeply. The best DT might be found and choosed by the kernel. However, I found that it is the ABL which is in charge of choosing, fixing and patching the DT after studying. Although the device is kind of outdated, this page talking about ["Using Mutiple DTs"](https://source.android.com/devices/architecture/dto/multiple) from Android documentation might be still helpful for someone.

# DT loading in ABL Bootloader

In my previous posts such as [Android bootloader analysis -- ABL(1)](https://blog.inoki.cc/2021/10/18/android-bootloader-analysis-abl-1/), I analyse the Bootloader in a coarse-grained manner. As mentioned in [Android bootloader analysis -- Aboot](https://blog.inoki.cc/2021/10/17/android-bootloader-analysis-aboot-en/), ABL is actually an EFI application that loaded by the XBL. The application is a module named after LinuxLoader, which is in charge of loading Linux kernel and the related entities in an ABoot(Android Boot) image.

## DT in LinuxLoader EFI application

As mentioned in [Android bootloader analysis -- ABL(1)](https://blog.inoki.cc/2021/10/18/android-bootloader-analysis-abl-1/), the EFI application entry is declared in `QcomModulePkg/Application/ LinuxLoader/LinuxLoader.inf`, as `LinuxLoaderEntry`. The application can either boot into Android fastboot mode, or boot into Linux kernel(normal boot or recovery).

Normally, the ABL loads the image in the `boot` partition, in which the ANDROIDBOOT format image is used. The image usually contains a kernel and a ramdisk for basic initialization. Depending on the devices, the DTs can be appended to the kernel or stored in a standalone partition:

{% asset_img treble_dto_partition_1.png Appended DT %}

{% asset_img treble_dto_partition_2.png Standalone DT %}

My Nokia 8 uses the first solution. And there are many DTs. So, before booting, the Bootloader needs to purge them.

If the image is validated, `BootLinux (&Info)` is called to actually try to process the image so as to boot it. In that function, `DTBImgCheckAndAppendDT` is called to choose the best DT and append it to the kernel.

To do this, `DeviceTreeAppended` in `QcomModulePkg/Library/BootLib/LocateDeviceTree.c` is called. It checks all the possible DTs from the begin address of the appended DT, to the kernel end. For each DT, the `DeviceTreeCompatible` is called to find the best DT.

The standard matching process contains the retrievals of `qcom,msm-id`, `qcom,board-id` and `qcom,pmic-id` properties in the DT. There is a special structure to describe such information from the hardware:

```c
typedef struct DtInfo {
  UINT32 DtPlatformId;
  UINT32 DtSocRev;
  UINT32 DtFoundryId;
  UINT32 DtVariantId;
  UINT32 DtVariantMajor;
  UINT32 DtVariantMinor;
  UINT32 DtPlatformSubtype;
  UINT32 DtPmicModel[MAX_PMIC_IDX];
  UINT32 DtPmicRev[MAX_PMIC_IDX];
  UINT64 DtMatchVal;
  VOID *Dtb;
} DtInfo;
```

The matching process is as follows:

```c
if (CurDtbInfo->DtMatchVal & BIT (ExactMatch)) {
	if (BestDtbInfo->DtMatchVal < CurDtbInfo->DtMatchVal) {
		gBS->CopyMem (BestDtbInfo, CurDtbInfo, sizeof (struct DtInfo));
		FindBestMatch = TRUE;
	} else if (BestDtbInfo->DtMatchVal == CurDtbInfo->DtMatchVal) {
		FindBestMatch = TRUE;
		if (BestDtbInfo->DtSocRev < CurDtbInfo->DtSocRev) {
			gBS->CopyMem (BestDtbInfo, CurDtbInfo, sizeof (struct DtInfo));
		} else if (BestDtbInfo->DtVariantMajor < CurDtbInfo->DtVariantMajor) {
			gBS->CopyMem (BestDtbInfo, CurDtbInfo, sizeof (struct DtInfo));
		} else if (BestDtbInfo->DtVariantMinor < CurDtbInfo->DtVariantMinor) {
			gBS->CopyMem (BestDtbInfo, CurDtbInfo, sizeof (struct DtInfo));
		} else if (BestDtbInfo->DtPmicRev[0] < CurDtbInfo->DtPmicRev[0]) {
			gBS->CopyMem (BestDtbInfo, CurDtbInfo, sizeof (struct DtInfo));
		} else if (BestDtbInfo->DtPmicRev[1] < CurDtbInfo->DtPmicRev[1]) {
			gBS->CopyMem (BestDtbInfo, CurDtbInfo, sizeof (struct DtInfo));
		} else if (BestDtbInfo->DtPmicRev[2] < CurDtbInfo->DtPmicRev[2]) {
			gBS->CopyMem (BestDtbInfo, CurDtbInfo, sizeof (struct DtInfo));
		} else if (BestDtbInfo->DtPmicRev[3] < CurDtbInfo->DtPmicRev[3]) {
			gBS->CopyMem (BestDtbInfo, CurDtbInfo, sizeof (struct DtInfo));
		} else {
			FindBestMatch = FALSE;
		}
	}
}
```

However, for different models of Nokia 8, they do share the same `msm` information because they are using the same platform and the same board, which are:

```
compatible = "qcom,msm8998-mtp", "qcom,msm8998", "qcom,mtp";
qcom,board-id = <8 0>, <1 0>;
```

I found, by mysterious way, that my phone uses a special `fih,hw-id` field to find the correct DT. I will discuss this later.

Finally, a pointer named `tags` is returned and be passed as the actual DT to the kernel.

## FIH modules

As aforementioned, there is a special `fih,hw-id` field in addition to `qcom,board-id` and `compatible` fields to match the DT in the ABL Bootloader.

Such id is stored in a special memory area, which is also declared as reseved memory in the DT:

```
fih_mem: fih_region@a0000000 { /* for FIH feature */
    compatible = "removed-dma-pool";
    no-map;
    reg = <0 0xa0000000 0 0xb00000>;
};
```

We can see that the memory region starts at `0xa0000000` and has a size of `0xb00000`. The detailed information is not accessible here because the XBL seems not to be open-sourced.

However, when I unpacked the XBL from the factory image, I saw there are `FIHDxe` EFI driver and `FIHHWIDApp` to load the hardware id into the EFI environment. So that, the `LinuxLoader` EFI application can eventually read the information and match the DT.

I cannot provide more details because the reverse-engineering is performed. But the address to store the hardware id is `0x000160f1` in the EFI environment under my 5150 image. It is written by the `FIHHWIDApp` using the methods provided by the `FIHDxe`.

Anyway, the DT choosed by my device is with:

```
model = "Qualcomm Technologies, Inc. MSM8998 v2.1 MTP, FIH NB1 PVT1 SS";
compatible = "qcom,msm8998-mtp", "qcom,msm8998", "qcom,mtp";
qcom,board-id = <8 0>, <1 0>;
fih,hw-id = <1 7 4>;
```

in which I guess that it is a **P**roduct version **1**, with **S**ingle **S**lot. This DT is finally the only DT passed to the Linux kernel.

# DT processing in Linux kernel

In ARM64, when kernel is loaded and executed, the address pointing to DT is passed in `X5` register. The first executable code is from `arch/arm64/kernel/head.S`, where we can see the device hardware initialization and the Flatten DT(FDT) pointer is saved from `X5` register to `__fdt_pointer`:

```asm
str_l	x21, __fdt_pointer, x5		// Save FDT pointer
```

It is a physical address in `arch/arm64/kernel/setup.c`:

```c
phys_addr_t __fdt_pointer __initdata;
```

where `__initdata` indicates that it should be stored in a special section for data used during initialization.

The `head.S` does not do many things and then just passes the control(without return) to `start_kernel` function. This function is usually generic for all platforms, which performs Linux initialization step-by-step. The DT-related function calls are as follows:

```c
setup_arch(&command_line);

rest_init();
```

where `setup_arch` is definitly platform-related and architecture-related. And after all initializations are finished, the rest part (non-essential) of the kernel needs to be initialized.

## DT in architecture-related setup

Each platform/architecture has its own setup function. The one for ARM64 is `arch/arm64/kernel/setup.c`.

It first print the CPU information(the information is visualized in `dmesg`) and establish the mappings of virtual addresses:

```c
pr_info("Boot CPU: AArch64 Processor [%08x]\n", read_cpuid_id());
early_fixmap_init();
early_ioremap_init();
```

Then the boot-related functions are:

```c
setup_machine_fdt(__fdt_pointer);
// ...
efi_init();
// ...
/* Parse the ACPI tables for possible boot-time configuration */
acpi_boot_table_init();
// ...
if (acpi_disabled) {
	unflatten_device_tree();
	psci_dt_init();
} else {
	psci_acpi_init();
}
```

Note that both the DT and the EFI-ACPI boot modes are supported. In our case, we only consider the DT mode. So, the topic remains on `setup_machine_fdt`, and the `unflatten_device_tree`, `psci_dt_init` when `acpi_disabled` is true.

### ARM64 Machine FDT setuping

The `setup_machine_fdt` accepts a DT pointer. Note that now the DT has been chosen by the ABL, so we are safe to load and verify the only DT.

```c
static void __init setup_machine_fdt(phys_addr_t dt_phys)
{
	void *dt_virt = fixmap_remap_fdt(dt_phys);

	if (!dt_virt || !early_init_dt_scan(dt_virt)) {
		pr_crit("\n"
			"Error: invalid device tree blob at physical address %pa (virtual address 0x%p)\n"
			"The dtb must be 8-byte aligned and must not exceed 2 MB in size\n"
			"\nPlease check your bootloader.",
			&dt_phys, dt_virt);

		while (true)
			cpu_relax();
	}

	machine_name = of_flat_dt_get_machine_name();
	if (machine_name) {
		dump_stack_set_arch_desc("%s (DT)", machine_name);
		pr_info("Machine: %s\n", machine_name);
	}
}
```

It first get the virtual address of FDT from the physical address using the memory mapping. Then, perform a basic scan to validate the DT(`early_init_dt_scan` in `drivers/of/fdt.c`). At the end, the machine name is gotten and printed, which can also be seen in `dmesg`.

<!---
### ARM Machine FDT setuping

The `of_flat_dt_match_machine` function finds one of the compatible DTs(though ABL only gives one) using the given function(`arch_get_next_mach` here).

```c
const struct machine_desc * __init setup_machine_fdt(void *dt)
{
	const struct machine_desc *mdesc;
	unsigned long dt_root;
	const void *clk;
	int len;

	if (!early_init_dt_scan(dt))
		return NULL;

	mdesc = of_flat_dt_match_machine(NULL, arch_get_next_mach);
	if (!mdesc)
		machine_halt();

	dt_root = of_get_flat_dt_root();
	clk = of_get_flat_dt_prop(dt_root, "clock-frequency", &len);
	if (clk)
		arc_set_core_freq(of_read_ulong(clk, len/4));

	arc_set_early_base_baud(dt_root);

	return mdesc;
}
```

```c
pr_info("Machine model: %s\n", of_flat_dt_get_machine_name());
```
--->

### FDT processing

Then, the FDT is parsed in `unflatten_device_tree()` to construct a tree of `device_nodes`, which can be used to probe the peripherals.

The first use is to discover the Power State Coordination Interface(PSCI) in `psci_dt_init()`. The interface should be compatible with one of the following values:

```
{ .compatible = "arm,psci",	.data = psci_0_1_init},
{ .compatible = "arm,psci-0.2",	.data = psci_0_2_init},
{ .compatible = "arm,psci-1.0",	.data = psci_0_2_init}
```

Kernel can use the similar way to discover other devices.

## DT processing in sysfs

In an ARM Linux with sysfs, we can usually see the `devicetree` node and the `fdt` node under `/sysfs/firmware` directory. These nodes are actually the visualization of the corresponding kernel objects. The Linux kernel just adds them into the kernel object sets.

Such function is implemented in `rest_init`. The kernel runs a kernel thread to start the non-critical initilization part of the kernel:

```c
kernel_thread(kernel_init, NULL, CLONE_FS);
```

The `kernel_init` executes `kernel_init_freeable` and then run the `init` command. The command can be passed from the kernel commanline in `ramdisk_execute_command` or `execute_command`. Otherwise, the kernel will try `/sbin/init`, `/etc/init`, `/bin/init` and `/bin/sh`. If this still fails, the kernel is in panic.

In `kernel_init_freeable`, the kernel still calls many function. The `do_basic_setup` and then `driver_init` are associated to the DT processing in sysfs.

The `driver_init` calls several functions to initialize the different parts as follows:

```c
/* These are the core pieces */
devtmpfs_init();
devices_init();
buses_init();
classes_init();
firmware_init();
hypervisor_init();

/* These are also core pieces, but must come after the
 * core core pieces.
 */
platform_bus_init();
cpu_dev_init();
memory_dev_init();
container_dev_init();
of_core_init();
```

In `firmware_init`, the `firmware_kobj` is created to host the firmware-related kernel objects:

```c
int __init firmware_init(void)
{
	firmware_kobj = kobject_create_and_add("firmware", NULL);
	if (!firmware_kobj)
		return -ENOMEM;
	return 0;
}
```

At the end, `of_core_init` creates `/sys/firmware/devicetree` and the nodes under the tree:

```c
void __init of_core_init(void)
{
	struct device_node *np;

	/* Create the kset, and register existing nodes */
	mutex_lock(&of_mutex);
	of_kset = kset_create_and_add("devicetree", NULL, firmware_kobj);
	if (!of_kset) {
		mutex_unlock(&of_mutex);
		pr_err("devicetree: failed to register existing nodes\n");
		return;
	}
	for_each_of_allnodes(np)
		__of_attach_node_sysfs(np);
	mutex_unlock(&of_mutex);

	/* Symlink in /proc as required by userspace ABI */
	if (of_root)
		proc_symlink("device-tree", NULL, "/sys/firmware/devicetree/base");
}
```

In addtion, `late_initcall(of_fdt_raw_init)` in `driver/of/fdt.c` can create the `/sys/firmware/fdt` to host the FDT binary contents:

```c
static int __init of_fdt_raw_init(void)
{
	static struct bin_attribute of_fdt_raw_attr =
		__BIN_ATTR(fdt, S_IRUSR, of_fdt_raw_read, NULL, 0);

	if (!initial_boot_params)
		return 0;

	if (of_fdt_crc32 != crc32_be(~0, initial_boot_params,
				     fdt_totalsize(initial_boot_params))) {
		pr_warn("fdt: not creating '/sys/firmware/fdt': CRC check failed\n");
		return 0;
	}
	of_fdt_raw_attr.size = fdt_totalsize(initial_boot_params);
	return sysfs_create_bin_file(firmware_kobj, &of_fdt_raw_attr);
}
```

If we search the `firmware_kobj`, there are also many other firmware types that can be initialized, such as:

- EFI `kobject_create_and_add("efi", firmware_kobj);` under `drivers/firmware/efi/efi.c`
- ACPI `kobject_create_and_add("efi", firmware_kobj);` under `drivers/acpi/bus.c`
- DMI `kobject_create_and_add("dmi", firmware_kobj);` under `drivers/firmware/dmi_scan.c`

which are common for EFI system.

For those who are intrested in EFI and ACPI, there are some function calls during kernel init:

```c
acpi_early_init();
/* ... */
acpi_subsystem_init();
sfi_init_late();

if (efi_enabled(EFI_RUNTIME_SERVICES)) {
    efi_late_init();
    efi_free_boot_services();
}
```

## FIH modules

Some nodes in the DT are really device-wise and their drivers are not mainlined. The customized kernel provides a driver module to bring up the devices and read the related information. As mentioned before, there is also a similar close-sourced module in XBL. Here we can see the related information.

The hardware id can be read by the following structure, from the reserved memory region at `0xA0A80000`

```c
struct st_hwid_table {
	/* mpp */
	unsigned int r1; /* pin: PROJECT-ID */
	char r2; /* pin: HW_REV-ID */
	char r3; /* pin: RF_BAND-ID */
	/* info */
	char prj; /* project */
	char rev; /* hw_rev */
	char rf;  /* rf_band */
	/* device tree */
	char dtm; /* Major number */
	char dtn; /* minor Number */
	/* driver */
	char btn; /* button */
	char uart;
};
```

Such information is read and explosed to a file under procfs(`/proc` directory), which can be directly read by the userspace program:

```c
static int __init fih_info_init(void)
{

	if (proc_create("devmodel", 0, NULL, &project_file_ops) == NULL) {
		pr_err("fail to create proc/devmodel\n");
	}

	if (proc_create("baseband", 0, NULL, &hw_rev_file_ops) == NULL) {
		pr_err("fail to create proc/baseband\n");
	}

	if (proc_create("bandinfo", 0, NULL, &rf_band_file_ops) == NULL) {
		pr_err("fail to create proc/bandinfo\n");
	}

	if (proc_create("hwmodel", 0, NULL, &hwmodel_file_ops) == NULL) {
		pr_err("fail to create proc/hwmodel\n");
	}

	if (proc_create("hwcfg", 0, NULL, &hwcfg_file_ops) == NULL) {
		pr_err("fail to create proc/hwcfg\n");
	}

	if (proc_create("SIMSlot", 0, NULL, &simslot_file_ops) == NULL) {
		pr_err("fail to create proc/SIMSlot\n");
	}

	if (proc_create("MODULE", 0, NULL, &module_file_ops) == NULL) {
		pr_err("fail to create proc/MODULE\n");
	}

	if (proc_create("fqc_xml", 0, NULL, &fqc_xml_file_ops) == NULL) {
		pr_err("fail to create proc/fqc_xml\n");
	}

	return (0);
}
```

There are also information of cpu, dram, battery, gpio, touch, etc. Here we can see the related information.

```c
/**************************************************************
 * START         | SIZE        | TARGET
 * -------------------------------------------------------- 0MB
 *   0xA000_0000 | 0x0020_0000 | modem rf_nv (2MB)
 *   0xA020_0000 | 0x0020_0000 | modem cust_nv (2MB)
 *   0xA040_0000 | 0x0040_0000 | modem default_nv (2MB)
 *   0xA080_0000 | 0x0010_0000 | modem log (1MB)
 *   -------------------------------------------------------- 7MB
 *   0xA090_0000 | 0x0004_0000 | last_alog_main (256KB)
 *   0xA094_0000 | 0x0004_0000 | last_alog_events (256KB)
 *   0xA098_0000 | 0x0004_0000 | last_alog_radio (256KB)
 *   0xA09C_0000 | 0x0004_0000 | last_alog_system (256KB)
 *   0xA0A0_0000 | 0x0004_0000 | last_kmsg (256KB)
 *   0xA0A4_0000 | 0x0002_0000 | last_blog (128KB)
 *   0xA0A6_0000 | 0x0002_0000 | blog (128KB)
 *   -------------------------------------------------------- 8.5MB
 *   0xA0A8_0000 | 0x0000_0040 | hwid:hwcfg (64B)
 *   0xA0A8_0040 | 0x0000_0040 | secboot:devinfo (64B)
 *   0xA0A8_0080 | 0x0000_0100 | secboot:unlock (256B)
 *   0xA0A8_0180 | 0x0000_0080 | sutinfo (128B)
 *   0xA0A8_0200 | 0x0000_0010 | no use 1 (16B)
 *   0xA0A8_0210 | 0x0000_0010 | bset (16B)
 *   0xA0A8_0220 | 0x0000_0010 | bat-id adc (16B)
 *   0xA0A8_0230 | 0x0000_0010 | no use 2 (16B)
 *   0xA0A8_0240 | 0x0000_0020 | apr (32B)
 *   0xA0A8_0260 | 0x0000_0180 | no use 3 (384B)
 *   0xA0A8_03E0 | 0x0000_0020 | mem (32B)
 *   0xA0A8_0400 | 0x0000_0C00 | no use 4 (3KB)
 *   0xA0A8_1000 | 0x0000_1000 | e2p (4KB)
 *   0xA0A8_2000 | 0x0000_1000 | cda (4KB)
 *   0xA0A8_3000 | 0x0000_1000 | note (4KB)
 *   0xA0A8_4000 | 0x0000_1000 | hwcfg (4KB)
 *   0xA0A8_5000 | 0x0000_3000 | no use 5 (12KB)
 *   0xA0A8_8000 | 0x0004_0000 | fver (256KB)
 *   0xA0AC_8000 | 0x0000_4000 | sensordata (16KB)
 *   0xA0AC_C000 | 0x0000_4000 | LCM data (16KB)
 *   0xA0AD_0000 | 0x0000_1000 | DDR CDT (4KB)
 *   0xA0AD_1000 | 0x0000_1000 | sensor TOF (4KB)
 *   0xA0AD_2000 | 0x0000_8000 | sensor SSC (32KB)
 *   0xA0AD_A000 | 0x0000_6400 | sensordata 2 (25KB)
 *   0xA0AE_0400 | 0x0001_FC00 | no use 6 (127KB)
 *   -------------------------------------------------------- 9MB
 *   0xA0B0_0000 | 0x0020_0000 | pstore (2MB)
 *   -------------------------------------------------------- 11MB
 *   0xA0D0_0000 | 0x00B0_0000 | All FIH mem (11MB)
 */
```

# Conclusion

In this post, I analyzed the how the ABL Bootloader and the Linux kernel deal with the DT. It is interesting to know some details about the exact processing on the Nokia 8(NB1) platform anyway.
