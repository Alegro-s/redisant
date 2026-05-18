Param(
    [string]$OutZip = ""
)

$ErrorActionPreference = "Stop"
$Eco = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$RepoRoot = (Resolve-Path (Join-Path $Eco "..\..")).Path

if (-not $OutZip) {
    $OutZip = Join-Path $RepoRoot "releases\server-upload.zip"
}

$staging = Join-Path $env:TEMP "waypoint-server-upload"
if (Test-Path $staging) { Remove-Item -Recurse -Force $staging }
New-Item -ItemType Directory -Force -Path "$staging/opt/waypoint" | Out-Null
New-Item -ItemType Directory -Force -Path "$staging/root" | Out-Null

Copy-Item (Join-Path $Eco "server\deploy-all.sh") "$staging/root/deploy-all.sh"
Copy-Item (Join-Path $Eco "docker.secrets.example") "$staging/opt/waypoint/docker.secrets"
Copy-Item (Join-Path $Eco "s3.secrets.example") "$staging/opt/waypoint/s3.secrets"
Copy-Item (Join-Path $Eco "smtp.env.example") "$staging/opt/waypoint/smtp.env"
Copy-Item (Join-Path $Eco "ИНСТРУКЦИЯ.md") "$staging/ИНСТРУКЦИЯ.txt"

@"
Распакуйте на сервере (root):

  cd /root
  unzip server-upload.zip
  cp -r opt/waypoint/* /opt/waypoint/
  cp root/deploy-all.sh /root/deploy-all.sh
  chmod +x /root/deploy-all.sh
  nano /opt/waypoint/docker.secrets
  nano /opt/waypoint/smtp.env
  nano /opt/waypoint/s3.secrets
  bash /root/deploy-all.sh

"@ | Set-Content "$staging/ПРОЧИТАЙ.txt" -Encoding utf8

if (Test-Path $OutZip) { Remove-Item -Force $OutZip }
Compress-Archive -Path "$staging\*" -DestinationPath $OutZip -CompressionLevel Optimal
Remove-Item -Recurse -Force $staging

Write-Host "Архив для сервера: $OutZip"
Write-Host "scp `"$OutZip`" root@72.56.244.26:/root/"
