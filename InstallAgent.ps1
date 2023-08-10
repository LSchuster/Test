param(
    $url,
    $pat,
    $poolName,
    $agentName
)

Write-Host "Set TLS Version"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host "Install Nuget"
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force

Write-Host "Install Az Module"
Install-Module -Name Az -Repository PSGallery -Force

Write-Host "Check if agent is installed"
if (test-path "c:\agent") {
    Write-Host "Remove c:\agent"
    Remove-Item -Path "c:\agent" -Force -Confirm:$false -Recurse
}

Write-Host "Create c:\agent"
new-item -ItemType Directory -Force -Path "c:\agent"
set-location "c:\agent"

Write-Host "Download agent"
$wr = Invoke-WebRequest https://api.github.com/repos/Microsoft/azure-pipelines-agent/releases/latest
$tag = ($wr | ConvertFrom-Json)[0].tag_name
$tag = $tag.Substring(1)

write-host "$tag is the latest version"
$url = "https://vstsagentpackage.azureedge.net/agent/$tag/vsts-agent-win-x64-$tag.zip"

write-host "Download and unpack agent files"
Invoke-WebRequest $url -Out agent.zip
Expand-Archive -Path agent.zip -DestinationPath $PWD

write-host "Configure <AGENT_NAME>"
.\config.cmd --unattended --url $url --auth pat --token $pat --pool $poolName --agent $agentName --acceptTeeEula --runAsService

write-host "Start <AGENT_NAME>"
.\start


exit 0
