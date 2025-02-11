# กำหนดค่าพารามิเตอร์
$threshold         = 70                # อัตราการใช้ CPU ที่ต้องการ
$processName       = "Example_Process" # Target process name (Example)
$serviceName       = "Example_Service" # Service to restart (Example)
$logFile           = "C:\Example\Logs\ServiceRestart.log" # Log file path (Example)
$checkInterval     = 5                 # ระยะเวลาระหว่างการตรวจสอบ (วินาที)
$doubleCheckDelay  = 10                # ระยะเวลารอก่อนตรวจสอบซ้ำ (วินาที)
$maxLogSize        = 10MB              # ขนาดสูงสุดของไฟล์ log

# ฟังก์ชันสำหรับตรวจสอบและสร้างโฟลเดอร์ log
function Ensure-LogDirectory {
    param (
        [string]$FilePath
    )
    $directory = Split-Path $FilePath
    if (!(Test-Path $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
}

# ฟังก์ชันสำหรับสร้างไฟล์ log ถ้ายังไม่มี
function Ensure-LogFile {
    param (
        [string]$FilePath
    )
    if (!(Test-Path $FilePath)) {
        New-Item -ItemType File -Path $FilePath -Force | Out-Null
    }
}

# ฟังก์ชันสำหรับเขียน log ทั้งแสดงผลและบันทึกลงไฟล์
function Write-Log {
    param (
        [string]$Message,
        [string]$FilePath
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry     = "$timestamp - $Message"
    Add-Content -Path $FilePath -Value $entry
    Write-Output $entry
}

# ฟังก์ชันสำหรับหมุนไฟล์ log เมื่อมีขนาดเกินที่กำหนด
function Rotate-Log {
    param (
        [string]$FilePath,
        [int64]$MaxSize
    )
    $fileItem = Get-Item $FilePath -ErrorAction SilentlyContinue
    if ($fileItem -and $fileItem.Length -gt $MaxSize) {
        $backupFile = $FilePath -replace '\.log$', "_$(Get-Date -Format 'yyyyMMdd').log"
        Move-Item $FilePath $backupFile -Force
        New-Item -ItemType File -Path $FilePath -Force | Out-Null
        Write-Log "Log file rotated, old log moved to $backupFile" $FilePath
    }
}

# ฟังก์ชันสำหรับดึงข้อมูล CPU usage ของโปรเซส
function Get-ProcessCpuUsage {
    param (
        [string]$Name
    )
    $counterPath = "\Process($Name)\% Processor Time"
    try {
        $counter  = Get-Counter $counterPath -ErrorAction Stop
        $cpuUsage = $counter.CounterSamples |
                    Where-Object { $_.InstanceName -eq $Name } |
                    Select-Object -ExpandProperty CookedValue
        return $cpuUsage
    }
    catch {
        return $null
    }
}

# ฟังก์ชันสำหรับจัดการ service (restart/start)
function Manage-Service {
    param (
        [string]$ServiceName,
        [string]$ProcessId,  # เปลี่ยนจาก $Pid เป็น $ProcessId
        [string]$LogFile
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $service   = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($service) {
        if ($service.Status -eq 'Running') {
            Restart-Service -Name $ServiceName -Force
            $msg = "Service '$ServiceName' restarted successfully (Process ID: $ProcessId)."
        }
        else {
            Start-Service -Name $ServiceName -ErrorAction SilentlyContinue
            $msg = "Service '$ServiceName' was stopped. Starting now... (Process ID: $ProcessId)."
        }
    }
    else {
        $msg = "Service '$ServiceName' not found! (Process ID: $ProcessId)."
    }
    Write-Log $msg $LogFile
}

# ตรวจสอบและสร้างโฟลเดอร์/ไฟล์ log
Ensure-LogDirectory -FilePath $logFile
Ensure-LogFile -FilePath $logFile

$lastState = $null  # เก็บสถานะก่อนหน้า

try {
    while ($true) {
        # หมุนไฟล์ log ถ้ามีขนาดเกินที่กำหนด
        Rotate-Log -FilePath $logFile -MaxSize $maxLogSize
        
        # ตรวจสอบสถานะโปรเซส
        $process       = Get-Process -Name $processName -ErrorAction SilentlyContinue
        $processId     = if ($process) { $process.Id } else { "N/A" }  # ใช้ $processId แทน $pid
        $currentState  = if ($process) { "Running" } else { "Not Running" }
        
        # บันทึก log เมื่อสถานะเปลี่ยนไปจากรอบก่อนหน้า
        if ($currentState -ne $lastState) {
            Write-Log "Process $processName (Process ID: $processId) is $currentState" $logFile
            $lastState = $currentState
        }
        
        # ถ้าโปรเซสทำงานอยู่ให้ตรวจสอบ CPU usage
        if ($process) {
            $cpuUsage = Get-ProcessCpuUsage -Name $processName
            if ($cpuUsage -ne $null) {
                Write-Host "CPU Real-time Usage for $processName (Process ID: $processId): $cpuUsage%"
                if ($cpuUsage -gt $threshold) {
                    Write-Host "CPU usage exceeded threshold ($threshold%). Waiting $doubleCheckDelay seconds before rechecking..."
                    Start-Sleep -Seconds $doubleCheckDelay
                    
                    # ตรวจสอบ CPU usage อีกครั้ง
                    $cpuUsage = Get-ProcessCpuUsage -Name $processName
                    if ($cpuUsage -gt $threshold) {
                        Write-Log "CPU usage is high ($cpuUsage%). Threshold is $threshold%. Attempting to restart service '$serviceName' (Process ID: $processId)..." $logFile
                        Manage-Service -ServiceName $serviceName -ProcessId $processId -LogFile $logFile
                    }
                }
            }
            else {
                Write-Log "Error: Cannot retrieve CPU usage for process $processName (Process ID: $processId)." $logFile
            }
        }
        
        Write-Host "Waiting $checkInterval seconds before next check..."
        Start-Sleep -Seconds $checkInterval
    }
} catch {
    Write-Log "Critical script error: $_" $logFile
} finally {
    Write-Log "Script execution terminated" $logFile
}
