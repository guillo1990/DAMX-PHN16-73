<p align="center">
  <img src="https://github.com/user-attachments/assets/6d383e82-8221-438b-9d6d-a19e998fcc59" alt="icon" width="80" style="vertical-align: middle;">
</p>

<h1 align="center">
  Div Acer Manager Max
</h1>

**Div Acer Manager Max** is a feature-rich Linux GUI utility for Acer laptops powered by the incredible [Linuwu Sense](https://github.com/0x7375646F/Linuwu-Sense) drivers. It replicates and expands on Acer’s NitroSense and PredatorSense capabilities on Linux with full fan control, performance modes, battery optimization, backlight settings, and more — all wrapped in a modern Avalonia-based UI.

This private fork contains the Acer Predator PHN16-73 driver adaptation and KDE Power Profiles synchronization. See [PHN16-73.md](PHN16-73.md) for installation, validation, rollback, and upstream attribution.

> [!CAUTION]
> Project is under active development.

![Title Image](https://github.com/user-attachments/assets/a60898a6-a2b8-432e-b5a2-8d0a45c63484)


<h4 align="center">
⭐ Please star this repository to show support. It motivates me to make the project better for everyone
</h4>  

## ✨ Features

### ✅ Fully Implemented

* 🔋 **Performance / Thermal Profiles**
  Eco, Silent, Balanced, Performance, Turbo — automatically adjusted based on AC/battery status
  (e.g., Turbo hidden when on battery or unsupported)

* 🌡 **Fan Control**
  Manual and Auto fan speed modes
  Manual disabled automatically when in Quiet profile

* 💡 **LCD Override Setting**
  Direct control over LCD power behavior

* 🎨 **Keyboard Backlight Timeout Control**
  Customize the keyboard backlight timeout

* 🔊 **Boot Animation and Sound Toggle**
  Enable/disable Acer's startup animations and sounds

* 💻 **Live System Info Display**
  Shows real-time performance profile, fan settings, calibration state, and more

* 🧠 **Smart Daemon (Low Resource Use)**

  * Auto-detects feature support per device
  * Communicates with GUI in real-time
  * Lightweight: uses \~10MB RAM
  * Can run **independently** of GUI
  * Recursive restart to fix software issues similar to those on Windows

* 🖥️ **Modern GUI**

  * Avalonia-based, clean and responsive
  * Realtime Monitoring with Dashboard and accurate Tempreature Readings
  * Dynamic UI hides unsupported features
  * Real-time feedback from daemon

## 🧭 Compatibilty
Check your deviced compatibility here: [Compatibility List](https://github.com/PXDiv/Div-Acer-Manager-Max/blob/main/Compatibility.md)

> Even if not here, DAMX will still work on most devices. Be sure to put a issue to request your model to be added in the compatiblity list if working.

## 🖥️ Installation

1. Download the Latest release package from the Release section
   
2. Extract the Package and set the setup script to be executable
   
3. Open the setup script with a termial (Right click the setup file to run it as a Program or in Terminal)

4. Choose the option 1 from the menu to install:

   * `1` → Install
   * `2` → Install without Drivers
   * `3` → Uninstall
   * `4` → Reinstall/Update

5. And a Reboot

That’s it!

## 🖥️ Troubleshooting
You can check the logs at /var/log/DAMX_Daemon_Log.log

If you get UNKNOWN as Laptop type, try restarting (it happens somethings) 
But if it still happenes that might mean the Drivers Installation failed, Make sure you have the approprite kernel headers to compile the drivers.

Also, check out the [FAQ page](https://github.com/PXDiv/Div-Acer-Manager-Max/blob/main/FAQ.md) before opening any issues.

Please open a new issue or discussion and include the logs to get support and help the project grow if you need any info, report a bug or just give ideas for the future versions of DAMX

## Screenshots 
![image](https://github.com/user-attachments/assets/10d44e8c-14e4-4441-b60c-538af1840cf6)
![image](https://github.com/user-attachments/assets/89217b26-b94c-4c78-8fe8-3de2b22a7095)
![image](https://github.com/user-attachments/assets/72a7b944-5efc-4520-83b6-88069fc05723)
![image](https://github.com/user-attachments/assets/f9a9d663-70c6-482e-a0c4-15a4ea08a8d2)


## ❤️ Powered by Linuwu

The custom drivers for this project [Div-Linuwu Sense project](https://github.com/PXDiv/Div-Linuwu-Sense) is built entirely on top of the [Linuwu Sense](https://github.com/0x7375646F/Linuwu-Sense) drivers — huge thanks to their developers for enabling hardware-level access on Acer laptops.

## 🤝 Contributing

* Report bugs or request features via GitHub Issues
* Submit pull requests to improve code or UI
* Help test on different Acer laptop models



## 📄 License

This project is licensed under the **GNU General Public License v3.0**.  
See the [LICENSE](LICENSE) file for details.
