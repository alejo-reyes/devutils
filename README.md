# DevUtils

A collection of development utilities and shell scripts to streamline common tasks.

## Device Switcher

A powerful Bluetooth device switcher for macOS and Windows that lets you quickly move a Magic Keyboard and Magic Mouse between multiple computers.

### Features

- 🎯 **Unified Interface**: Control both keyboard and mouse with a single command
- 🔄 **Smart Switching**: Handles pairing, unpairing, and connection automatically
- 🎨 **Color-coded Output**: Professional, clean interface with no emojis
- ⚡ **Quick Commands**: Short aliases for fast switching
- 🔍 **Device Discovery**: Finds devices in both paired and nearby lists
- 📊 **Status Checking**: Monitor connection status of your devices
- 🛠️ **Both Device Support**: Switch keyboard and mouse simultaneously
- 🧩 **Cross-Platform**: Bash script for macOS, PowerShell script for Windows

### Prerequisites

#### macOS (Bash script)

Requires [`blueutil`](https://github.com/toy/blueutil), a command-line Bluetooth utility for macOS:

```bash
# Install Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install blueutil
brew install blueutil
```

#### Windows (PowerShell script)

Requires PowerShell 7.3+ with the Windows Bluetooth module (available in Windows 11 22H2 and newer):

```powershell
# Install the Bluetooth module (requires admin)
Install-Module Bluetooth

# or use winget
winget install Microsoft.PowerShell.Bluetooth
```

You can run the script in an elevated PowerShell session or specify `-ExecutionPolicy Bypass` per invocation.

#### Device Setup

1. **Rename your devices** in macOS System Settings > Bluetooth:
   - Magic Keyboard → `A.Reyes MagicKeyboard`
   - Magic Mouse → `A.Reyes MagicMouse`
   
   *Note: You can customize these names by editing the constants at the top of `device_switch.sh`*

### Installation

#### macOS

1. **Clone or download** this repository.
2. **Make the script executable**:
   ```bash
   chmod +x shell_scripts/device_switch.sh
   ```
3. **Add an alias to your shell** (optional but handy):
   ```bash
   echo "alias ds='$(pwd)/shell_scripts/device_switch.sh'" >> ~/.zshrc
   source ~/.zshrc
   ```

#### Windows

1. **Clone or download** this repository.
2. **(Optional) Add a helper function to your PowerShell profile** for a `ds` shortcut:
   ```powershell
   if (-not (Test-Path $PROFILE)) { New-Item -Path $PROFILE -ItemType File -Force | Out-Null }
   Add-Content $PROFILE "`nfunction ds { & '$(Get-Location)\shell_scripts\device_switch.ps1' @Args }"
   ```
   Reload your profile or open a new PowerShell session afterward.

Without the helper function you can run the script directly:
```powershell
powershell -ExecutionPolicy Bypass -File .\shell_scripts\device_switch.ps1 keyboard claim
```

### Usage

#### macOS (alias example)

```bash
# Show help
ds

# Individual devices
ds keyboard claim      # Claim keyboard for this laptop
ds k c                 # Same (short form)
ds mouse release       # Release mouse to other devices
ds m r                 # Same (short form)

# Both devices
ds both claim          # Claim both devices
ds b c                 # Same (short form)
ds both status         # Check status of both devices
ds b s                 # Same (short form)
```

#### Windows (PowerShell)

```powershell
# Show help
.\shell_scripts\device_switch.ps1 -Device keyboard -Action status

# Short forms mirror the macOS script
.\shell_scripts\device_switch.ps1 k c    # Claim keyboard
.\shell_scripts\device_switch.ps1 m r    # Release mouse
.\shell_scripts\device_switch.ps1 b s    # Status of both devices
```

When using the `ds` helper function described earlier, the commands match the macOS alias examples.

#### Device Types
- `keyboard` or `k` - Magic Keyboard
- `mouse` or `m` - Magic Mouse  
- `both` or `b` - Both devices

#### Actions
- `claim` or `c` - Claim device (pair & connect to this machine)
- `release` or `r` - Release device (disconnect and remove pairing)
- `status` or `s` - Check current connection status

### Workflow Examples

#### Switching Between Laptops

**On Laptop A (releasing devices):**
```bash
ds b r    # Release both devices
```

**On Laptop B (claiming devices):**
```bash
ds b c    # Claim both devices
```

#### Individual Device Management

```bash
# Use keyboard on this laptop, but let other laptop use mouse
ds k c    # Claim keyboard
ds m r    # Release mouse

# Check what's connected
ds b s    # Status of both devices
```

### Technical Details

#### How It Works

1. **Device Discovery**: 
   - First searches paired devices
   - Falls back to Bluetooth inquiry for unpaired devices
   - Uses regex to extract MAC addresses and device names

2. **Smart Pairing**:
   - Keyboards use PIN "0000"
   - Mice typically pair without PIN
   - Handles pairing failures gracefully

3. **Connection Management**:
   - Checks current connection status
   - Only pairs if not already paired
   - Provides detailed feedback for each step

#### Configuration

Device names and PINs are configured at the top of `device_switch.sh`:

```bash
readonly KEYBOARD_NAME="A.Reyes MagicKeyboard"
readonly MOUSE_NAME="A.Reyes MagicMouse"
readonly KEYBOARD_PIN="0000"
readonly MOUSE_PIN=""  # Mice typically don't need PIN
```

### Color Coding

- **Blue**: Keyboard operations
- **Green**: Mouse operations & success messages
- **Magenta**: Both device operations
- **Yellow**: Warnings & search messages
- **Red**: Error messages
- **Gray**: Secondary information

### Troubleshooting

#### Common Issues

**Device not found:**
- Ensure device is turned on and in range
- Check that device name matches configuration
- Try putting device in pairing mode

**Pairing fails:**
- Make sure device is in pairing mode
- Check if device is already paired to another device
- Try releasing from other device first

**Connection fails:**
- Wait a few seconds and try again
- Check Bluetooth is enabled
- Restart Bluetooth service if needed

#### Debug Commands

```bash
# List all paired devices
blueutil --paired

# Check if specific device is connected
blueutil --is-connected <device-id>

# Manual pairing
blueutil --pair <device-id> 0000
```

```powershell
# Windows equivalents
Get-BluetoothDevice
Get-BluetoothDevice -Paired:$false
Connect-BluetoothDevice -DeviceAddress <mac>
Remove-BluetoothDevice -DeviceAddress <mac>
```

### File Structure

```
devutils/
├── README.md                    # This file
├── package.json                 # Project configuration
└── shell_scripts/
    ├── device_switch.ps1        # Windows PowerShell device switcher
    ├── device_switch.sh         # Main device switcher script
    ├── keyboard_switch.sh       # Original keyboard-only script
    ├── inject-simple.sh         # Other utility scripts
    └── re_pair.sh
```

### Contributing

Feel free to submit issues and pull requests to improve the functionality or add support for additional device types.

### License

This project is open source and available under the MIT License.
