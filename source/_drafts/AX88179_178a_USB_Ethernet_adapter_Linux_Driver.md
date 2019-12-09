---
title: AX88179_178a USB-Ethernet adapter Linux Driver
date: 2019-12-09 10:52:00
tags:
- Linux
- Linux Driver
- ASIX
categories:
- [Source Code, Linux Driver]
---

In this post, we'll analyze the Linux Driver of USB-Ethernet adapters, which are using `AX88179`/`AX88178a` chips.

# Introduction

`AX88179` and `AX88178a` is a chip from ASIX Electronics Corporation, which is a leading fabless semiconductor supplier with focus on networking, communication and connectivity applications, founded in May 1995 in Hsinchu Science Park, Taiwan.

`AX88179` is a USB3.0 to 10/100/1000M Gigabit Ethernet Controller, and `AX88178a` is the one for USB2.0. Since there are still lots of devices which are using USB 2.0, they are usually integrated into one single adapter to provide backward-compatibility.

More information about the chips can be found on the offcial website of ASIX:

- [AX88179](https://www.asix.com.tw/products.php?op=pItemdetail&PItemID=131;71;112)
- [AX88178a](https://www.asix.com.tw/products.php?op=pItemdetail&PItemID=134;71;100)

The one which I'm using is an adapter from `Edimax`, named `Edimax EU-4306 Adaptateur USB Ethernet`.

{% asset_img edimax-eu-4306.jpg Edimax EU-4306 Adaptateur USB Ethernet %}

Everyone can buy it with a fair price - about 25 euros in France.

# Driver Selection

The source code of the driver in current version kernel is located at `drivers/net/usb/ax88179_178a.c`.

Its [first commit](https://github.com/torvalds/linux/commit/e2ca90c276e1fc410d7cd3c1a4eee245ec902a20#diff-f2b04890e4605b9554cc77093cfc9e2a) is on Mar 2, 2013. So, up to now, we should be able to use it without panic.

To validate that it can be rightly loaded in your system, just plug in. Use this command to find information of your device and the software assoiated with it:

```
> usb-devices
...
T:  Bus=02 Lev=01 Prnt=01 Port=00 Cnt=01 Dev#=  2 Spd=5000 MxCh= 0
D:  Ver= 3.00 Cls=ff(vend.) Sub=ff Prot=00 MxPS= 9 #Cfgs=  1
P:  Vendor=0b95 ProdID=1790 Rev=01.00
S:  Manufacturer=ASIX Elec. Corp.
S:  Product=AX88179
S:  SerialNumber=xxxxxx
C:  #Ifs= 1 Cfg#= 1 Atr=a0 MxPwr=496mA
I:  If#= 0 Alt= 0 #EPs= 3 Cls=ff(vend.) Sub=ff Prot=00 Driver=ax88179_178a
```

We can see at the last line, there is `Driver=ax88179_178a`, which means my device uses the right driver.

To associate a device and a usb driver, one important thing is the vendor ID and product ID, showing in the third line: `Vendor=0b95 ProdID=1790`.

So, if your device cannot be allocated with an appropriate driver, pleas check the vendor ID and product ID of it.

The ID table of compatible devices for AX88179/178a is defined as below:

```c
static const struct usb_device_id products[] = {
{
	/* ASIX AX88179 10/100/1000 */
	USB_DEVICE(0x0b95, 0x1790),
	.driver_info = (unsigned long)&ax88179_info,
}, {
	/* ASIX AX88178A 10/100/1000 */
	USB_DEVICE(0x0b95, 0x178a),
	.driver_info = (unsigned long)&ax88178a_info,
}, {
	/* Cypress GX3 SuperSpeed to Gigabit Ethernet Bridge Controller */
	USB_DEVICE(0x04b4, 0x3610),
	.driver_info = (unsigned long)&cypress_GX3_info,
}, {
	/* D-Link DUB-1312 USB 3.0 to Gigabit Ethernet Adapter */
	USB_DEVICE(0x2001, 0x4a00),
	.driver_info = (unsigned long)&dlink_dub1312_info,
}, {
	/* Sitecom USB 3.0 to Gigabit Adapter */
	USB_DEVICE(0x0df6, 0x0072),
	.driver_info = (unsigned long)&sitecom_info,
}, {
	/* Samsung USB Ethernet Adapter */
	USB_DEVICE(0x04e8, 0xa100),
	.driver_info = (unsigned long)&samsung_info,
}, {
	/* Lenovo OneLinkDock Gigabit LAN */
	USB_DEVICE(0x17ef, 0x304b),
	.driver_info = (unsigned long)&lenovo_info,
}, {
	/* Belkin B2B128 USB 3.0 Hub + Gigabit Ethernet Adapter */
	USB_DEVICE(0x050d, 0x0128),
	.driver_info = (unsigned long)&belkin_info,
},
	{ },
};
MODULE_DEVICE_TABLE(usb, products);
```

Notice that `USB_DEVICE` is a macro defined in `include/linux/usb.h`, to quickly assign vendor ID and product ID. Meanwhile, make the mode be strictly matching, which means that only device has this vendor ID **AND** product ID will be allowed to use this driver.

```c
#define USB_DEVICE(vend, prod) \
	.match_flags = USB_DEVICE_ID_MATCH_DEVICE, \
	.idVendor = (vend), \
	.idProduct = (prod)
```

More, `products` is a table of type `struct usb_device_id`, defined in `include/linux/mod_devicetable.h`. Since we've already included `include/linux/usb.h\(<linux/usb.h>\)`, we do not need import it once more.

```c
struct usb_device_id {
	/* which fields to match against? */
	__u16		match_flags;

	/* Used for product specific matches; range is inclusive */
	__u16		idVendor;
	__u16		idProduct;
	__u16		bcdDevice_lo;
	__u16		bcdDevice_hi;

	/* Used for device class matches */
	__u8		bDeviceClass;
	__u8		bDeviceSubClass;
	__u8		bDeviceProtocol;

	/* Used for interface class matches */
	__u8		bInterfaceClass;
	__u8		bInterfaceSubClass;
	__u8		bInterfaceProtocol;

	/* Used for vendor-specific interface matches */
	__u8		bInterfaceNumber;

	/* not matched against */
	kernel_ulong_t	driver_info
		__attribute__((aligned(sizeof(kernel_ulong_t))));
};
```

But, if yours is not one of them, it might be another device. This post will have limited usage to you.

# Driver module registration

To make system be able to allocate the right driver, we need register the driver.

## usb_driver structure

The structure to describe a driver for USB is defined in `include/linux/usb.h`:

```c
struct usb_driver {
	const char *name;

	int (*probe) (struct usb_interface *intf,
		      const struct usb_device_id *id);

	void (*disconnect) (struct usb_interface *intf);

	int (*unlocked_ioctl) (struct usb_interface *intf, unsigned int code,
			void *buf);

	int (*suspend) (struct usb_interface *intf, pm_message_t message);
	int (*resume) (struct usb_interface *intf);
	int (*reset_resume)(struct usb_interface *intf);

	int (*pre_reset)(struct usb_interface *intf);
	int (*post_reset)(struct usb_interface *intf);

	const struct usb_device_id *id_table;
	const struct attribute_group **dev_groups;

	struct usb_dynids dynids;
	struct usbdrv_wrap drvwrap;
	unsigned int no_dynamic_id:1;
	unsigned int supports_autosuspend:1;
	unsigned int disable_hub_initiated_lpm:1;
	unsigned int soft_unbind:1;
};
```

It's a huge one, but we need not define all of them. What we need is just:

```c
static struct usb_driver ax88179_178a_driver = {
	.name =		"ax88179_178a",
	.id_table =	products,
	.probe =	usbnet_probe,
	.suspend =	ax88179_suspend,
	.resume =	ax88179_resume,
	.reset_resume =	ax88179_resume,
	.disconnect =	usbnet_disconnect,
	.supports_autosuspend = 1,
	.disable_hub_initiated_lpm = 1,
};
```

### .name

This is the name of driver, and it will be shown at the last line of the output of usb-devices.

{% asset_img name.png USB driver name %}

I got the output above by changing the name to `ax88179_178a_inoki`.

### struct usb_interface *intf

We can see that many of fields are pointers to functions with an argument of type `struct usb_interface *intf`.

It's defined in `include/linux/usb.h`.

```c
struct usb_interface {
	/* array of alternate settings for this interface,
	 * stored in no particular order */
	struct usb_host_interface *altsetting;

	struct usb_host_interface *cur_altsetting;	/* the currently
					 * active alternate setting */
	unsigned num_altsetting;	/* number of alternate settings */

	/* If there is an interface association descriptor then it will list
	 * the associated interfaces */
	struct usb_interface_assoc_descriptor *intf_assoc;

	int minor;			/* minor number this interface is
					 * bound to */
	enum usb_interface_condition condition;		/* state of binding */
	unsigned sysfs_files_created:1;	/* the sysfs attributes exist */
	unsigned ep_devs_created:1;	/* endpoint "devices" exist */
	unsigned unregistering:1;	/* unregistration is in progress */
	unsigned needs_remote_wakeup:1;	/* driver requires remote wakeup */
	unsigned needs_altsetting0:1;	/* switch to altsetting 0 is pending */
	unsigned needs_binding:1;	/* needs delayed unbind/rebind */
	unsigned resetting_device:1;	/* true: bandwidth alloc after reset */
	unsigned authorized:1;		/* used for interface authorization */

	struct device dev;		/* interface specific device info */
	struct device *usb_dev;
	struct work_struct reset_ws;	/* for resets in atomic context */
};
```

With this parameter, we can distinguish which device is under operating. As well, it requires the caller pass a right reference :)

###	.probe = usbnet_probe

The `usbnet_probe` is a function defined in `include/linux/usb/usbnet.h`.

```c
extern int usbnet_probe(struct usb_interface *, const struct usb_device_id *);
```

When a device is plugged into the USB bus that matches the device ID that your driver registered with the USB core, the probe function is called, with the interface instance, and the device information.

### .disconnect = usbnet_disconnect

Conversely, when the device is removed from the USB bus, the disconnect function is called with the device pointer.

For this callback and the callback which will be used in probing, the driver uses the standard USB net functions in `include/linux/usb/usbnet.h`.

```c
extern void usbnet_disconnect(struct usb_interface *);
```

There are lots of **standard** functions defined in this header file. But we cannot expect the **standard** stuff can handle with all devices. So, in most case, we need write our own handlers for specific devices.

### .suspend = ax88179_suspend

Called when the device is going to be suspended by the system either from system sleep or runtime suspend context.

This line can let the specific function `suspend` in the driver codebase be called.

### .resume = ax88179_resume and .reset_resume = ax88179_resume

`.resume` will be called when the device is being resumed by the system.

`.reset_resume` will be called when the suspended device has been reset instead of being resumed.

Both two can let the specific function `resume` in the driver codebase be called.

## Registration

Then, register the driver in the system.

```
module_usb_driver(ax88179_178a_driver);
```

It's not a function, but a macro defined in `include/linux/usb.h`:

```c
#define module_usb_driver(__usb_driver) \
	module_driver(__usb_driver, usb_register, \
		       usb_deregister)
```

Then it will be expanded to a set of instructions in `include/linux/device.h`.

```c
#define module_driver(__driver, __register, __unregister, ...) \
static int __init __driver##_init(void) \
{ \
	return __register(&(__driver) , ##__VA_ARGS__); \
} \
module_init(__driver##_init); \
static void __exit __driver##_exit(void) \
{ \
	__unregister(&(__driver) , ##__VA_ARGS__); \
} \
module_exit(__driver##_exit);
```

Such instructions can control the life cycle of a driver module. But we'll not go deeper into the module functions, becaus they are out of scope.

Here, we come back to the `module_usb_driver` macro. Except `__usb_driver` is the specific driven instance, `usb_register` and `usb_deregister` could be also an interesting point in this post.

In fact, they are defined in `include/linux/usb.h` as well:

```c
/*
 * use these in module_init()/module_exit()
 * and don't forget MODULE_DEVICE_TABLE(usb, ...)
 */
extern int usb_register_driver(struct usb_driver *, struct module *,
			       const char *);

/* use a define to avoid include chaining to get THIS_MODULE & friends */
#define usb_register(driver) \
	usb_register_driver(driver, THIS_MODULE, KBUILD_MODNAME)

extern void usb_deregister(struct usb_driver *);
```

The 2 functions will be called while module is being initialized or is being exited.

# Core Functions

After the module life cycle management, here we need talk more about the actions of driver, while there are arriving packets.

Except vendor ID and product ID, there is also `driver_info` field which is set according to the different devices.

```c
{
	/* ASIX AX88179 10/100/1000 */
	USB_DEVICE(0x0b95, 0x1790),
	.driver_info = (unsigned long)&ax88179_info,
}, {
	/* ASIX AX88178A 10/100/1000 */
	USB_DEVICE(0x0b95, 0x178a),
	.driver_info = (unsigned long)&ax88178a_info,
}
```

## Driver Info

We can take a look at the `0x0b95, 0x1790(AX88179)` and `0x0b95, 0x178(AX88178A)`. The driver info is an unsigned long pointer to the `struct driver_info` instance. Thus, Linux kernel can find the driver info instance when it needs.

The driver info structure is in fact a USB network driver info structure, defined in `include/linux/usb/usbnet.h`:

```c
struct driver_info {
	char		*description;
	int		flags;
	int	(*bind)(struct usbnet *, struct usb_interface *);
	void	(*unbind)(struct usbnet *, struct usb_interface *);
	int	(*reset)(struct usbnet *);
	int	(*stop)(struct usbnet *);
	int	(*check_connect)(struct usbnet *);
	int	(*manage_power)(struct usbnet *, int);
	void	(*status)(struct usbnet *, struct urb *);
	int	(*link_reset)(struct usbnet *);
	int	(*rx_fixup)(struct usbnet *dev, struct sk_buff *skb);
	struct sk_buff	*(*tx_fixup)(struct usbnet *dev,
				struct sk_buff *skb, gfp_t flags);
	void	(*recover)(struct usbnet *dev);
	int	(*early_init)(struct usbnet *dev);
	void	(*indication)(struct usbnet *dev, void *ind, int indlen);
	void	(*set_rx_mode)(struct usbnet *dev);
	int		in;		/* rx endpoint */
	int		out;		/* tx endpoint */
	unsigned long	data;		/* Misc driver specific data */
};
```

Just like the other huge structure, we will only use a small part of it.

### AX88179 Driver Info

```c
static const struct driver_info ax88179_info = {
	.description = "ASIX AX88179 USB 3.0 Gigabit Ethernet",
	.bind = ax88179_bind,
	.unbind = ax88179_unbind,
	.status = ax88179_status,
	.link_reset = ax88179_link_reset,
	.reset = ax88179_reset,
	.stop = ax88179_stop,
	.flags = FLAG_ETHER | FLAG_FRAMING_AX,
	.rx_fixup = ax88179_rx_fixup,
	.tx_fixup = ax88179_tx_fixup,
};
```

### AX88178a Driver Info

```c
static const struct driver_info ax88178a_info = {
	.description = "ASIX AX88178A USB 2.0 Gigabit Ethernet",
	.bind = ax88179_bind,
	.unbind = ax88179_unbind,
	.status = ax88179_status,
	.link_reset = ax88179_link_reset,
	.reset = ax88179_reset,
	.stop = ax88179_stop,
	.flags = FLAG_ETHER | FLAG_FRAMING_AX,
	.rx_fixup = ax88179_rx_fixup,
	.tx_fixup = ax88179_tx_fixup,
};
```

### .flags

In flags, we might have several bitwise flag. This is created for some special feature of each device.

In these two devices, we have Ethernet device feature and ASIX specific device features.

```c
#define FLAG_ETHER	0x0020		/* maybe use "eth%d" names */
#define FLAG_FRAMING_AX 0x0040		/* AX88772/178 packets */
```

### .bind

init device

### .unbind

cleanup device

### .reset

reset device

### .stop

stop device

### .status

for status polling

### .link_reset

link reset handling, called from defer_kevent

### .rx_fixup

fixup rx packet (strip framing)

### .tx_fixup

fixup tx packet (add framing)

# Conclusion

By analyzing this codebase, we should be able to know how a USB network device works.

In the next post, I'll talk about a serious bug which is found in this driver.

See you!
