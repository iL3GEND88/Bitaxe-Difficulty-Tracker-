param([string]$Action, [string]$BatPath, [string]$Username)

if ($Action -eq "add") {
    $arg = '/c "' + $BatPath + '"'
    $a = New-ScheduledTaskAction -Execute "cmd.exe" -Argument $arg
    $t = New-ScheduledTaskTrigger -AtLogOn -User $Username
    $s = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    $p = New-ScheduledTaskPrincipal -UserId $Username -RunLevel Highest
    Register-ScheduledTask -TaskName "BitaxeDifficultyTracker" -Action $a -Trigger $t -Settings $s -Principal $p -Force | Out-Null
    Write-Host "Task created"
} elseif ($Action -eq "remove") {
    Unregister-ScheduledTask -TaskName "BitaxeDifficultyTracker" -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "Task removed"
}
