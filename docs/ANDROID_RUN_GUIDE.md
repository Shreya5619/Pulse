# Android Run Guide (USB Cable Debugging)

This guide covers how to run both the **Pulse Backend Server** and the **Flutter Android Client** on your physical Android device connected via a USB cable.

By following this guide, you will set up a robust, firewall-proof connection using **ADB Port Forwarding**. This routes your phone's requests on port `8080` (where the app looks for the API) through the USB cable directly to the backend server running on your computer.

---

## 📋 Prerequisites

Before starting, ensure your Windows machine has:
1. **Flutter SDK** installed and added to your system `PATH`.
2. **Android SDK** and Command Line Tools installed (usually via Android Studio).
3. **Node.js** (v18+) and a package manager like `npm` or `pnpm` installed.

---

## ⚡ Step-by-Step Setup

### Step 1: Connect your Phone & Authorize USB Debugging

1. Plug your Android phone into your Windows PC using a high-quality USB cable.
2. Pull down your phone's notification shade and ensure the USB connection mode is set to **File Transfer** or **MTP** (not "Charging Only").
3. Run this command in a PowerShell terminal on your computer to verify your device is recognized:
   ```powershell
   adb devices
   ```
4. **Authorize the Connection:**
   * Look at your phone's screen. A popup should appear asking: **"Allow USB debugging?"** along with your computer's RSA key fingerprint.
   * Check **"Always allow from this computer"** and tap **Allow**.
5. Run `adb devices` again. The output should now list your device with the status `device` (instead of `unauthorized` or an empty list):
   ```text
   List of devices attached
   4a8c9b2d      device
   ```

> 💡 **Troubleshooting Device Detection:**
> * If the list is empty, make sure **USB Debugging** is toggled on in your phone's **Developer Options**.
> * Try a different USB cable or a different USB port on your PC.
> * If it still doesn't show up, you might need the [Google USB Driver](https://developer.android.com/studio/run/win-usb) installed on Windows.

---

### Step 2: Establish ADB Port Forwarding (The Secret Sauce)

Since your physical phone runs on a separate network stack from your PC, it cannot naturally resolve `localhost` or `127.0.0.1` to reach the server running on your laptop.

By running this command, you create a direct tunnel over the USB cable:
```powershell
adb reverse tcp:8080 tcp:8080
```
This tells Android: *"Any time the Pulse app makes a request to `127.0.0.1:8080` (or `localhost:8080`), route it through the USB cable to port `8080` on my computer."*

*This is 100% firewall-safe and does not require finding your computer's local Wi-Fi IP address!*

---

### Step 3: Run the Backend Server

Open a new terminal window on your computer and navigate to the `server/` directory:

1. **Install dependencies:**
   ```powershell
   cd server
   npm install   # or pnpm install / yarn install
   ```
2. **Setup environment variables:**
   Ensure you have a `.env` file in the root directory (or `server/` directory if configured there). You can copy the template:
   ```powershell
   cp ../.env.example ../.env
   ```
3. **Start the development server:**
   ```powershell
   npm run dev
   ```
   The backend will start and list output like:
   `[Pulse] Server running on http://0.0.0.0:8080`
   `[Pulse] WebSocket available at ws://0.0.0.0:8080/ws`

---

### Step 4: Run the Flutter Android App

With the server running and `adb reverse` active, you're ready to boot the app.

Open another terminal window on your PC:
1. **Navigate to the mobile directory:**
   ```powershell
   cd mobile
   ```
2. **Fetch Flutter packages:**
   ```powershell
   flutter pub get
   ```
3. **Ensure a device is available:**
   Run:
   ```powershell
   flutter devices
   ```
   You should see your physical Android phone listed.
4. **Compile and Launch the App:**
   Run the following command to compile and launch the app in debug mode on your connected phone:
   ```powershell
   flutter run
   ```

*Once the app launches on your phone, it will seamlessly connect to the backend server and WebSocket. You'll see real-time log messages showing snapshot ingestion and heartbeat ticks over the USB cable!*

---

## 🛠️ Summary of Dev Commands (Cheat Sheet)

Keep these commands handy in your terminal window as you develop:

| Command | Action | Cwd |
| :--- | :--- | :--- |
| `adb devices` | Verifies your phone is properly connected and trusted. | Any |
| `adb reverse tcp:8080 tcp:8080` | Activates port forwarding over the USB cable (Run this once per session). | Any |
| `npm run dev` | Boots the Node/TypeScript backend server. | `server/` |
| `flutter run` | Boots the app on your connected device. | `mobile/` |
