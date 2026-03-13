# ⚡ Nitro-Burn

**A Blazing Fast, Bare-Metal USB Imager for Linux.**

Nitro-Burn is a next-generation bootable USB creator designed for speed, safety, and reliability. Built with a hyper-optimized **Rust** engine and a beautiful **Flutter** UI, it bypasses the heavy abstractions of modern Linux sandboxes to deliver true bare-metal performance.

![Platform](https://img.shields.io/badge/Platform-Linux-yellow)
![Engine](https://img.shields.io/badge/Engine-Rust-orange)
![UI](https://img.shields.io/badge/UI-Flutter-blue)
![License](https://img.shields.io/badge/License-MIT-green)

---

## 🤔 Why Nitro-Burn?

Most modern Linux USB imagers (especially those distributed via Flatpak/Snap) suffer from severe performance bottlenecks. They route data through multiple layers of IPC (D-Bus), virtualization, and policy kits, turning a 3-minute burn into a 30-minute ordeal. 

Furthermore, standard tools often fall victim to the **Linux Page Cache Illusion**—where the progress bar shoots to 100% instantly while data is merely buffered in RAM, leading to corrupted drives if pulled out too early.

**Nitro-Burn solves this.** It accesses hardware directly, bypasses the RAM cache, and shows you the *actual* write speed and progress.

## ✨ Key Features

* 🚀 **True Bare-Metal I/O:** Utilizes the `O_SYNC` flag and 4 MiB chunk sizes to write directly to the block device. What you see is the *real* speed.
* 🛡️ **Smart Auto-Unmount:** Automatically detects mounted partitions on the target USB and forcefully unmounts them before burning. No manual terminal commands needed.
* 🔒 **Data Integrity Guarantee:** Implements strict `libc_fsync` at 100% to ensure every single bit is physically flushed to the USB controller before marking the job as complete.
* 🎨 **Premium 60FPS UI:** A completely decoupled Flutter frontend communicating with the Rust backend via asynchronous FFI. The UI never freezes.
* 🪶 **Portable & Lightweight:** Distributed as a standalone archive. No heavy Flatpak runtimes required.

## 🏗️ Architecture

Nitro-Burn is a hybrid application representing the ultimate modern tech stack:
1. **The Muscle (Backend):** A multi-threaded Rust shared library (`libnitro_burn.so`) handling low-level OS APIs, memory-safe pointers, and direct hardware manipulation.
2. **The Face (Frontend):** A Dart/Flutter desktop application presenting a modern, responsive, and idiot-proof user experience.

## 🚀 Getting Started

### 📦 Installation (Portable)

1. Download the latest `Nitro-Burn-Linux-1.0.0.tar.gz` from the Releases page.
2. Extract the archive to your preferred location.
3. Open the extracted folder and run the execution script:

```bash
cd Nitro-Burn-Linux
./Run-NitroBurn.sh
