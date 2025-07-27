<#
.SYNOPSIS
  Disables Wazuh agent enrollment and replaces ossec.conf with minimal config.
.DESCRIPTION
  - Stops the Wazuh agent service
  - Reads address and port from existing ossec.conf
  - Writes a new minimal ossec.conf with enrollment disabled
  - Restarts the Wazuh agent service
  - Posts status to webhook if defined
#>

# ======== Configuration ========
$confPath      = "C:\Program Files (x86)\ossec-agent\ossec.conf"
$serviceName   = "WazuhSvc"
$backupPath    = "$confPath.bak"
$webhookUrl    = "https://california.shuffler.io/api/v1/hooks/webhook_ee4ab243-eaf7-4950-802e-5aa1919f265e"  # Set to $null to disable
# ===============================

function Log {
    param([string]$message)
    Write-Output "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $message"
}

function Post-Webhook {
    param(
        [string]$status,
        [string]$message
    )
    if ($webhookUrl) {
        try {
            $payload = @{
                hostname = $env:COMPUTERNAME
                timestamp = (Get-Date).ToString("o")
                status = $status
                message = $message
            } | ConvertTo-Json -Compress

            Invoke-RestMethod -Uri $webhookUrl -Method POST -Body $payload -ContentType "application/json"
            Log "Webhook POST sent: $status"
        } catch {
            Log "Webhook POST failed: $_"
        }
    }
}

# Stop Wazuh service
try {
    Log "Stopping Wazuh service..."
    Stop-Service -Name $serviceName -Force -ErrorAction Stop
} catch {
    Log "Failed to stop Wazuh service: $_"
    Post-Webhook "error" "Failed to stop Wazuh service"
    exit 1
}

# Load and parse config
try {
    [xml]$xml = Get-Content $confPath -ErrorAction Stop
    $serverNode = $xml.ossec_config.client.server
    $address = $serverNode.address
    $port = $serverNode.port
} catch {
    Log "Failed to read or parse ossec.conf: $_"
    Post-Webhook "error" "Failed to parse ossec.conf"
    exit 2
}

if (-not $address -or -not $port) {
    Log "Missing <address> or <port> in ossec.conf"
    Post-Webhook "error" "Missing required fields in ossec.conf"
    exit 3
}

# Backup original config
try {
    Copy-Item $confPath $backupPath -Force -ErrorAction Stop
    Log "Backed up original config to $backupPath"
} catch {
    Log "Failed to backup ossec.conf: $_"
    Post-Webhook "error" "Backup failed"
    exit 4
}

# Write new config
try {
    $newConfig = @"
<ossec_config>
  <client>
    <server>
      <address>$address</address>
      <port>$port</port>
      <protocol>tcp</protocol>
    </server>
    <crypto_method>aes</crypto_method>
    <notify_time>10</notify_time>
    <time-reconnect>60</time-reconnect>
    <auto_restart>yes</auto_restart>
    <enrollment>
      <enabled>no</enabled>
    </enrollment>
  </client>
</ossec_config>
"@

    $newConfig | Set-Content -Path $confPath -Encoding UTF8 -ErrorAction Stop
    Log "New ossec.conf written successfully."
} catch {
    Log "Failed to write new ossec.conf: $_"
    Post-Webhook "error" "Failed to write new config"
    exit 5
}

# Start Wazuh service
try {
    Log "Starting Wazuh service..."
    Start-Service -Name $serviceName -ErrorAction Stop
    Log "Wazuh service started."
} catch {
    Log "Failed to start Wazuh service: $_"
    Post-Webhook "error" "Service start failed"
    exit 6
}

Post-Webhook "success" "Enrollment disabled and config replaced successfully"
Log "Completed successfully."
exit 0
