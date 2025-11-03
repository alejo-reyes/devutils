#requires -RunAsAdministrator
<#
  .SYNOPSIS
  Bluetooth device switcher for Windows.

  .DESCRIPTION
  Mirrors the macOS shell script behaviour using the Windows Bluetooth PowerShell module.
  Supports claiming (pairing/connecting), releasing (disconnecting/removing),
  and status checks for preconfigured keyboard and mouse peripherals.
#>

[CmdletBinding(PositionalBinding = $false)]
param(
  [Parameter(Position = 0)]
  [ValidateNotNullOrEmpty()]
  [string]$Device,

  [Parameter(Position = 1)]
  [ValidateNotNullOrEmpty()]
  [string]$Action
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Device configuration constants
Set-Variable -Name KeyboardName -Option Constant -Scope Script -Value 'A.Reyes MagicKeyboard'
Set-Variable -Name MouseName -Option Constant -Scope Script -Value 'A.Reyes MagicMouse'
Set-Variable -Name KeyboardPin -Option Constant -Scope Script -Value '0000'
Set-Variable -Name MousePin -Option Constant -Scope Script -Value '' # Mice typically skip pairing PINs

function Write-Themed {
  param(
    [ConsoleColor]$Color = [ConsoleColor]::Gray,
    [switch]$Bold,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Message
  )

  $current = $Host.UI.RawUI.ForegroundColor
  if ($Bold) {
    Write-Host ($Message -join ' ') -ForegroundColor $Color -BackgroundColor [ConsoleColor]::Black -NoNewline:$false
  } else {
    Write-Host ($Message -join ' ') -ForegroundColor $Color
  }
  $Host.UI.RawUI.ForegroundColor = $current
}

function Ensure-BluetoothModule {
  if (-not (Get-Module -Name Bluetooth -ListAvailable)) {
    throw "Bluetooth PowerShell module not found. Install via 'winget install Microsoft.PowerShell.Bluetooth' or ensure Windows 11 22H2+."
  }
  Import-Module Bluetooth -ErrorAction Stop
}

function Resolve-Device {
  param(
    [string]$DeviceName
  )

  $device = Get-BluetoothDevice -Name $DeviceName -ErrorAction SilentlyContinue
  if (-not $device) {
    $device = Get-BluetoothDevice | Where-Object { $_.Name -eq $DeviceName } | Select-Object -First 1
  }
  return $device
}

function Resolve-UnpairedDevice {
  param(
    [string]$DeviceName
  )

  if (-not (Get-Command -Name Start-BluetoothScan -ErrorAction SilentlyContinue)) {
    return $null
  }

  $watcher = Start-BluetoothScan -ErrorAction Stop
  try {
    Start-Sleep -Seconds 5
    return Get-BluetoothDevice -Paired:$false | Where-Object { $_.Name -eq $DeviceName } | Select-Object -First 1
  } finally {
    Stop-BluetoothScan -InputObject $watcher -ErrorAction SilentlyContinue | Out-Null
  }
}

function Resolve-DeviceAddress {
  param(
    [Parameter(Mandatory)]
    [psobject]$DeviceInfo
  )

  if ($DeviceInfo.PSObject.Properties['DeviceAddress']) {
    return $DeviceInfo.DeviceAddress
  }

  if ($DeviceInfo.PSObject.Properties['BluetoothAddress']) {
    $value = [uint64]$DeviceInfo.BluetoothAddress
    $bytes = [BitConverter]::GetBytes($value)
    [array]::Reverse($bytes)
    return ($bytes[2..7] | ForEach-Object { $_.ToString('X2') }) -join ':'
  }

  return $null
}

function Invoke-ClaimDevice {
  param(
    [Parameter(Mandatory)]
    [psobject]$DeviceInfo,
    [string]$Pin,
    [string]$DeviceLabel
  )

  Write-Themed -Color Cyan -Bold -Message "`nClaiming $DeviceLabel..."
  $address = Resolve-DeviceAddress -DeviceInfo $DeviceInfo
  if (-not $address) {
    throw "Unable to determine Bluetooth address for $DeviceLabel."
  }
  Write-Themed -Color DarkGray -Message "`tDevice: $($DeviceInfo.Name) [$address]"

  if ($DeviceInfo.IsConnected) {
    Write-Themed -Color Green -Message "`n$DeviceLabel already connected to this device."
    return
  }

  if (-not $DeviceInfo.IsPaired) {
    Write-Themed -Color Yellow -Message "`n$DeviceLabel not paired. Pairing now..."
    if ([string]::IsNullOrEmpty($Pin)) {
      Add-BluetoothDevice -DeviceAddress $address | Out-Null
    } else {
      Add-BluetoothDevice -DeviceAddress $address -Passkey $Pin | Out-Null
    }
    Start-Sleep -Seconds 2
    $DeviceInfo = Resolve-Device -DeviceName $DeviceInfo.Name
    if (-not $DeviceInfo -or -not $DeviceInfo.IsPaired) {
      throw "$DeviceLabel failed to pair. Ensure it is in pairing mode and retry."
    }
    $address = Resolve-DeviceAddress -DeviceInfo $DeviceInfo
    if (-not $address) {
      throw "Unable to determine Bluetooth address for $DeviceLabel after pairing."
    }
  }

  Write-Themed -Color Cyan -Message "`nConnecting..."
  Connect-BluetoothDevice -DeviceAddress $address | Out-Null

  $DeviceInfo = Resolve-Device -DeviceName $DeviceInfo.Name
  if ($DeviceInfo -and $DeviceInfo.IsConnected) {
    Write-Themed -Color Green -Bold -Message "`n$DeviceLabel successfully claimed and connected!"
  } else {
    throw "$DeviceLabel failed to connect. Try running the command again."
  }
}

function Invoke-ReleaseDevice {
  param(
    [Parameter(Mandatory)]
    [psobject]$DeviceInfo,
    [string]$DeviceLabel
  )

  Write-Themed -Color Yellow -Bold -Message "`nReleasing $DeviceLabel..."
  $address = Resolve-DeviceAddress -DeviceInfo $DeviceInfo
  Write-Themed -Color DarkGray -Message "`tDevice: $($DeviceInfo.Name) [$address]"

  if (-not $DeviceInfo.IsConnected) {
    Write-Themed -Color Yellow -Message "`n$DeviceLabel not currently connected to this device."
  } else {
    Write-Themed -Color Cyan -Message "`nDisconnecting..."
    Disconnect-BluetoothDevice -DeviceAddress $address | Out-Null
    Start-Sleep -Seconds 1
  }

  Write-Themed -Color Cyan -Message "Removing pairing..."
  Remove-BluetoothDevice -DeviceAddress $address | Out-Null
  Write-Themed -Color Green -Message "`n$DeviceLabel released and ready for another computer."
}

function Invoke-DeviceStatus {
  param(
    [Parameter(Mandatory)]
    [psobject]$DeviceInfo,
    [string]$DeviceLabel
  )

  Write-Themed -Color Cyan -Bold -Message "`n$DeviceLabel Status:"
  $address = Resolve-DeviceAddress -DeviceInfo $DeviceInfo
  Write-Themed -Color DarkGray -Message "`tDevice: $($DeviceInfo.Name) [$address]"

  if ($DeviceInfo.IsConnected) {
    Write-Themed -Color Green -Message "`nConnected to this device."
  } elseif ($DeviceInfo.IsPaired) {
    Write-Themed -Color Yellow -Message "`nPaired but not connected."
  } else {
    Write-Themed -Color Red -Message "`nNot paired with this device."
  }
}

function Show-PairedDevices {
  Get-BluetoothDevice | Sort-Object -Property Name | ForEach-Object {
    $address = Resolve-DeviceAddress -DeviceInfo $_
    Write-Themed -Color DarkCyan -Message "`t$address - $($_.Name)"
  }
}

function Show-Help {
  Write-Themed -Color Cyan -Bold -Message 'Device Switcher'
  Write-Host ''
  Write-Themed -Color White -Bold -Message 'Usage:' 'device_switch.ps1 <device> <action>'
  Write-Host ''
  Write-Themed -Color White -Bold -Message 'Devices:'
  Write-Themed -Color Blue -Message '  keyboard | k  - Magic Keyboard'
  Write-Themed -Color Green -Message '  mouse | m     - Magic Mouse'
  Write-Themed -Color Magenta -Message '  both | b      - Both devices'
  Write-Host ''
  Write-Themed -Color White -Bold -Message 'Actions:'
  Write-Themed -Color Green -Message '  claim | c     - Claim device for this PC (pair & connect)'
  Write-Themed -Color Yellow -Message '  release | r   - Release device (disconnect & remove pairing)'
  Write-Themed -Color Blue -Message '  status | s    - Check current connection status'
  Write-Host ''
  Write-Themed -Color White -Bold -Message 'Examples:'
  Write-Host '  device_switch.ps1 keyboard claim'
  Write-Host '  device_switch.ps1 k c'
  Write-Host '  device_switch.ps1 mouse release'
  Write-Host '  device_switch.ps1 m r'
  Write-Host '  device_switch.ps1 both status'
  Write-Host '  device_switch.ps1 b s'
  Write-Host ''
  Write-Themed -Color White -Bold -Message 'Device Status Overview:'
  Write-Host '  device_switch.ps1 both status'
}

function Invoke-SwitchDevice {
  param(
    [string]$RequestedDevice,
    [string]$RequestedAction
  )

  if (-not $RequestedDevice -or -not $RequestedAction) {
    Show-Help
    return 1
  }

  Ensure-BluetoothModule

  switch ($RequestedDevice.ToLowerInvariant()) {
    { $_ -in @('keyboard', 'k') } {
      return (Invoke-DeviceAction -DeviceName $KeyboardName -Pin $KeyboardPin -Label 'Keyboard' -RequestedAction $RequestedAction)
    }
    { $_ -in @('mouse', 'm') } {
      return (Invoke-DeviceAction -DeviceName $MouseName -Pin $MousePin -Label 'Mouse' -RequestedAction $RequestedAction)
    }
    { $_ -in @('both', 'b') } {
      Write-Themed -Color Magenta -Bold -Message "`nSwitching both devices..."
      Write-Themed -Color DarkGray -Message 'Processing keyboard first, then mouse.'
      $keyboardResult = Invoke-DeviceAction -DeviceName $KeyboardName -Pin $KeyboardPin -Label 'Keyboard' -RequestedAction $RequestedAction
      Write-Host ''
      Write-Themed -Color DarkGray -Message '----------------------------------------'
      $mouseResult = Invoke-DeviceAction -DeviceName $MouseName -Pin $MousePin -Label 'Mouse' -RequestedAction $RequestedAction
      Write-Host ''
      Write-Themed -Color Magenta -Bold -Message 'Summary:'
      Write-Host ("  Keyboard: " + ($(if ($keyboardResult -eq 0) { 'Success' } else { 'Failed' })))
      Write-Host ("  Mouse: " + ($(if ($mouseResult -eq 0) { 'Success' } else { 'Failed' })))
      return ($(if ($keyboardResult -eq 0 -and $mouseResult -eq 0) { 0 } else { 1 }))
    }
    Default {
      Write-Themed -Color Red -Message "Invalid device type: $RequestedDevice"
      Show-Help
      return 1
    }
  }
}

function Invoke-DeviceAction {
  param(
    [string]$DeviceName,
    [string]$Pin,
    [string]$Label,
    [string]$RequestedAction
  )

  $device = Resolve-Device -DeviceName $DeviceName
  if (-not $device) {
    Write-Themed -Color Yellow -Message "`n$Label not found in paired devices. Searching nearby..."
    $device = Resolve-UnpairedDevice -DeviceName $DeviceName
  }

  if (-not $device) {
    Write-Themed -Color Red -Message "`n$Label not found in paired or nearby devices."
    Write-Themed -Color DarkGray -Message "`t1. Ensure the $Label is powered on and in pairing mode."
    Write-Themed -Color DarkGray -Message "`t2. Confirm it is within Bluetooth range."
    Write-Host ''
    Write-Themed -Color Blue -Message 'Available paired devices:'
    Show-PairedDevices
    return 1
  }

  switch ($RequestedAction.ToLowerInvariant()) {
    { $_ -in @('claim', 'c') } {
      Invoke-ClaimDevice -DeviceInfo $device -Pin $Pin -DeviceLabel $Label
      return 0
    }
    { $_ -in @('release', 'r') } {
      Invoke-ReleaseDevice -DeviceInfo $device -DeviceLabel $Label
      return 0
    }
    { $_ -in @('status', 's') } {
      Invoke-DeviceStatus -DeviceInfo $device -DeviceLabel $Label
      return 0
    }
    Default {
      Write-Themed -Color Red -Message "Invalid action: $RequestedAction"
      Show-Help
      return 1
    }
  }
}

if ($MyInvocation.InvocationName -ne '.') {
  exit (Invoke-SwitchDevice -RequestedDevice $Device -RequestedAction $Action)
}
