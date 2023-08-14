param(
    $url,
    $pat,
    $poolName,
    $agentName,
    $projectName
)

Start-Transcript -path C:\InstallAgentLog.txt -append
Write-Host "*** Set TLS Version ***"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host "*** Check Nuget Module ***"
if (Get-Module -ListAvailable -Name "NuGet") {
    Write-Host "Module Nuget exists"
} 
else {
    Write-Host "Install Nuget"
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
}

Write-Host "*** Check Az Module ***"
if (Get-Module -ListAvailable -Name "Az*"){
    Write-Host "Module Nuget exists"
} 
else {
    Write-Host "Install Az Module"
    Install-Module -Name Az -Repository PSGallery -Force
}

Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi; Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'; rm .\AzureCLI.msi

Write-Host "*** Check if agent is installed ***"
if (test-path "c:\agent") {
    Write-Host "Remove c:\agent"
    Remove-Item -Path "c:\agent" -Force -Confirm:$false -Recurse
}

Write-Host "*** Create c:\agent ***"
new-item -ItemType Directory -Force -Path "c:\agent"
set-location "c:\agent"

Write-Host "*** Download agent ***"
$wr = Invoke-WebRequest https://api.github.com/repos/Microsoft/azure-pipelines-agent/releases/latest -UseBasicParsing
$tag = ($wr | ConvertFrom-Json)[0].tag_name
$tag = $tag.Substring(1)

write-host "$tag is the latest version"
$urlDevOps = "https://vstsagentpackage.azureedge.net/agent/$tag/vsts-agent-win-x64-$tag.zip"

write-host "*** Download and unpack agent files ***"
Invoke-WebRequest $urlDevOps -Out agent.zip -UseBasicParsing
Expand-Archive -Path agent.zip -DestinationPath $PWD

# Write-Host "*** Remove old Agent ***"
# .\config.cmd remove --auth 'PAT' --token $pat

write-host "*** Configure $agentName ***"
cmd /c C:\agent\config.cmd --unattended --url $url --auth pat --token $pat --pool $poolName --agent $agentName --acceptTeeEula --runAsService

#write-host "*** Start $agentName ***"
#.\run

Write-Host "*** Create Working Directory ***"
if (test-path "c:\AgentInstallations") {
    Write-Host "Remove c:\AgentInstallations"
    Remove-Item -Path "c:\AgentInstallations" -Force -Confirm:$false -Recurse
}
new-item -ItemType Directory -Force -Path "c:\AgentInstallations"
set-location "c:\AgentInstallations"

Write-Host "*** Install Dotnet ***"
Invoke-WebRequest -Uri https://dot.net/v1/dotnet-install.ps1 -OutFile .\dotnet-install.ps1; 
.\dotnet-install.ps1

Write-Host "*** Install PWSH ***"
Invoke-WebRequest -Uri https://github.com/PowerShell/PowerShell/releases/download/v7.3.6/PowerShell-7.3.6-win-x64.msi -OutFile .\powerShellInstall.msi; 
msiexec.exe /package powerShellInstall.msi /quiet ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ADD_FILE_CONTEXT_MENU_RUNPOWERSHELL=1 ENABLE_PSREMOTING=1 REGISTER_MANIFEST=1 USE_MU=1 ENABLE_MU=1 ADD_PATH=1

# Visual Studio build tools
Write-Host "*** Install VS 22 ***"
Write-Host "Installing visual studio" -ForegroundColor Cyan
cd $env:USERPROFILE
$exePath = "$env:TEMP\vs.exe"
Invoke-WebRequest -Uri https://aka.ms/vs/17/release/vs_professional.exe -UseBasicParsing -OutFile $exePath
Write-Host "layout..." -ForegroundColor Cyan
Start-Process $exePath -ArgumentList "--layout .\vs_professional --quiet" -Wait
cd vs_BuildTools
Write-Host "actual installation..." -ForegroundColor Cyan
Start-Process vs_professional.exe -ArgumentList "--installPath $env:USERPROFILE\vs_professional --nocache --wait --noUpdateInstaller --noWeb --add Microsoft.VisualStudio.Workload.Azure;includeRecommended;includeOptional --quiet --norestart" -Wait
[Environment]::SetEnvironmentVariable('Path', "$([Environment]::GetEnvironmentVariable('Path', 'Machine'));$env:USERPROFILE\vs_professional", 'Machine')

Write-Host "*** Restart Agent Service ***"
$serviceName="vstsagent.$projectName.Azure Integration Platform.$agentName"
Restart-Service -Name $serviceName
Stop-Transcript

exit 0
