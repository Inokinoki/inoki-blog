---
title: Win 10 IoT - Blink
date: 2019-05-07 22:58:40
tags:
- Embedded System
- Win 10 IoT
- Raspberry Pi
categories:
- [Embedded System, IoT, Win 10 IoT]
- [Embedded System, Raspberry Pi]
---

Thanks to Microsoft and its UWP application, Win 10 IoT device can share the same framework of normal Win 10 application.
In this post, we'll build a simple short blink application for Win 10 IoT platform. It assums that you've already have some knowledgements about GPIO.

# Connection
The Raspberry Pi GPIO pins are defined in Win 10 IoT as following:

{% asset_img rp2_pinout.png PIN Mapping %}

There is also a "Power-on Pull" state for each pin. "PullDown" means the pin has no tension, meanwhile "PullUp" means the pin has a high tension. Please check [PIN Mapping](https://docs.microsoft.com/en-us/windows/iot-core/learn-about-hardware/pinmappings/pinmappingsrpi) for some more details.

Here we choose `PIN 11` and `PIN 9(Ground)` to use. The circuit is like this:
{% asset_img circuit.jpg Circuit %}

The green wire is connected to `PIN 11`, the brown to `PIN 9`.

# Code
1. Use `GpioController gpio = GpioController.GetDefault();` to get GPIO controller.
2. Use `GpioPin pin = gpio.OpenPin(17)` to open a gpio port. `PIN 11` is `GPIO 17` in Win 10 IoT.
3. Write HIGH to this port `pin.Write(GpioPinValue.High);`.
4. Set to output mode `pin.SetDriveMode(GpioPinDriveMode.Output);`.
5. Close port(Here we use `using` to make it close automately).

```C#
public sealed partial class MainPage : Page
{
    public MainPage()
    {
        this.InitializeComponent();
        this.GPIO();
    }
    
    DispatcherTimer dispatcherTimer;
    
    public void GPIO()
    {
        // Create a timer and call dispatcherTimer_Tick every 1 second
        dispatcherTimer = new DispatcherTimer();
        dispatcherTimer.Tick += dispatcherTimer_Tick;
        dispatcherTimer.Interval = new TimeSpan(0, 0, 1);
        dispatcherTimer.Start();
    }
    
    public void dispatcherTimer_Tick(object sender, object e)
    {
        // Get the default GPIO controller on the system
        GpioController gpio = GpioController.GetDefault();
        if (gpio == null) return; // GPIO not available on this system
        // Open GPIO 17
        using (GpioPin pin = gpio.OpenPin(17))
        {
            // Latch HIGH value first. This ensures a default value when the pin is set as output
            pin.Write(GpioPinValue.High);

            // Set the IO direction as output
            pin.SetDriveMode(GpioPinDriveMode.Output);
        } // Close pin - will revert to its power-on state
    }
}
```

# Conclusion
This video shows you the result:
<video src='/2019/05/07/Win10-IoT-Blink/blink.mp4' type='video/mp4' controls='controls' width='100%' height='100%'></video>
