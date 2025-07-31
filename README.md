# Reset-WazuhEnrollment

```
$script = "$env:TEMP\Reset-WazuhEnrollment.ps1"; iwr -UseBasicParsing "https://raw.githubusercontent.com/socfortress/Reset-WazuhEnrollment/refs/heads/main/Reset-WazuhEnrollment.ps1" -OutFile $script; powershell -ExecutionPolicy Bypass -File $script; Remove-Item $script -Force
```
