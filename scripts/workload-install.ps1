#
# Copyright (c) HavenDV and Samsung Electronics. All rights reserved.
# Licensed under the MIT license. See LICENSE file in the project root for full license information.
#

<#
.SYNOPSIS
Installs WebAssembly workload manifest.
.DESCRIPTION
Installs the WorkloadManifest.json and WorkloadManifest.targets files for WebAssembly to the dotnet sdk.
.PARAMETER Version
Use specific VERSION
.PARAMETER DotnetInstallDir
Dotnet SDK Location installed
#>

[cmdletbinding()]
param(
    [Alias('v')][string]$Version="<latest>",
    [Alias('d')][string]$DotnetInstallDir="<auto>",
    [Alias('t')][string]$DotnetTargetVersionBand="<auto>",
    [Alias('s')][string]$Source="<auto>",
    [Alias('u')][switch]$UpdateAllWorkloads
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ManifestBaseName = "WebAssembly.Sdk.Manifest"

function New-TemporaryDirectory {
    $parent = [System.IO.Path]::GetTempPath()
    $name = [System.IO.Path]::GetRandomFileName()
    New-Item -ItemType Directory -Path (Join-Path $parent $name)
}

function Ensure-Directory([string]$TestDir) {
    Try {
        New-Item -ItemType Directory -Path $TestDir -Force -ErrorAction stop | Out-Null
        [io.file]::OpenWrite($(Join-Path -Path $TestDir -ChildPath ".test-write-access")).Close()
        Remove-Item -Path $(Join-Path -Path $TestDir -ChildPath ".test-write-access") -Force
    }
    Catch [System.UnauthorizedAccessException] {
        Write-Error "No permission to install. Try run with administrator mode."
    }
}

function Get-LatestVersion([string]$Id) {
    return "0.3.0"
    
    $attempts=3
    $sleepInSeconds=3
    do
    {
        try
        {
            $Response = Invoke-WebRequest -Uri https://api.nuget.org/v3-flatcontainer/$Id/index.json -UseBasicParsing | ConvertFrom-Json
            return $Response.versions | Select-Object -Last 1
        }
        catch {
            Write-Host "Id: $Id"
            Write-Host "An exception was caught: $($_.Exception.Message)"
        }

        $attempts--
        if ($attempts -gt 0) { Start-Sleep $sleepInSeconds }
    } while ($attempts -gt 0)
    
    return "0.3.0"
}

function Get-Package([string]$Id, [string]$Version, [string]$Destination, [string]$Source = "", [string]$FileExt = "nupkg") {
    $OutFileName = "$Id.$Version.$FileExt"
    $OutFilePath = Join-Path -Path $Destination -ChildPath $OutFileName
    
    if ($Source -eq "<auto>") {
        Invoke-WebRequest -Uri "https://www.nuget.org/api/v2/package/$Id/$Version" -OutFile $OutFilePath
    }
    else {
        Copy-Item "$Source/$Id.$Version.nupkg" -Destination $OutFilePath
    }
    
    return $OutFilePath
}

function Install-Pack([string]$Id, [string]$Version, [string]$Kind, [string]$Source) {
    $TempZipFile = $(Get-Package -Id $Id -Version $Version -Destination $TempDir -Source $Source -FileExt "zip")
    $TempUnzipDir = Join-Path -Path $TempDir -ChildPath "unzipped\$Id"

    switch ($Kind) {
        "manifest" {
            Expand-Archive -Path $TempZipFile -DestinationPath $TempUnzipDir
            New-Item -Path $WebAssemblyManifestDir -ItemType "directory" -Force | Out-Null
            Copy-Item -Path "$TempUnzipDir\data\*" -Destination $WebAssemblyManifestDir -Force
        }
        {($_ -eq "sdk") -or ($_ -eq "framework")} {
            Expand-Archive -Path $TempZipFile -DestinationPath $TempUnzipDir
            $TargetDirectory = $(Join-Path -Path $DotnetInstallDir -ChildPath "packs\$Id\$Version")
            New-Item -Path $TargetDirectory -ItemType "directory" -Force | Out-Null
            Copy-Item -Path "$TempUnzipDir/*" -Destination $TargetDirectory -Recurse -Force
        }
        "template" {
            $TargetFileName = "$Id.$Version.nupkg".ToLower()
            $TargetDirectory = $(Join-Path -Path $DotnetInstallDir -ChildPath "template-packs")
            New-Item -Path $TargetDirectory -ItemType "directory" -Force | Out-Null
            Copy-Item $TempZipFile -Destination $(Join-Path -Path $TargetDirectory -ChildPath "$TargetFileName") -Force
        }
    }
}

function Remove-Pack([string]$Id, [string]$Version, [string]$Kind) {
    switch ($Kind) {
        "manifest" {
            Remove-Item -Path $WebAssemblyManifestDir -Recurse -Force
        }
        {($_ -eq "sdk") -or ($_ -eq "framework")} {
            $TargetDirectory = $(Join-Path -Path $DotnetInstallDir -ChildPath "packs\$Id\$Version")
            Remove-Item -Path $TargetDirectory -Recurse -Force
        }
        "template" {
            $TargetFileName = "$Id.$Version.nupkg".ToLower();
            Remove-Item -Path $(Join-Path -Path $DotnetInstallDir -ChildPath "template-packs\$TargetFileName") -Force
        }
    }
}

function Install-WebAssemblyWorkload([string]$DotnetVersion, [string]$Source)
{
    $VersionSplitSymbol = '.'
    $SplitVersion = $DotnetVersion.Split($VersionSplitSymbol)

    $CurrentDotnetVersion = [Version]"$($SplitVersion[0]).$($SplitVersion[1])"
    $DotnetVersionBand = $SplitVersion[0] + $VersionSplitSymbol + $SplitVersion[1] + $VersionSplitSymbol + $SplitVersion[2][0] + "00"
    $ManifestName = "$ManifestBaseName"

    if ($DotnetTargetVersionBand -eq "<auto>" -or $UpdateAllWorkloads.IsPresent) {
        if ($CurrentDotnetVersion -ge "7.0")
        {
            $IsPreviewVersion = $DotnetVersion.Contains("-preview") -or $DotnetVersion.Contains("-rc") -or $DotnetVersion.Contains("-alpha")
            if ($IsPreviewVersion -and ($SplitVersion.Count -ge 4)) {
                $DotnetTargetVersionBand = $DotnetVersionBand + $SplitVersion[2].SubString(3) + $VersionSplitSymbol + $($SplitVersion[3])
                $ManifestName = "$ManifestBaseName"
            }
            else {
                $DotnetTargetVersionBand = $DotnetVersionBand
            }
        }
        else {
            $DotnetTargetVersionBand = $DotnetVersionBand
        }
    }

    # Check latest version of manifest.
    if ($Version -eq "<latest>" -or $UpdateAllWorkloads.IsPresent) {
        $Version = Get-LatestVersion -Id $ManifestName
    }

    # Check workload manifest directory.
    $ManifestDir = Join-Path -Path $DotnetInstallDir -ChildPath "sdk-manifests" | Join-Path -ChildPath $DotnetTargetVersionBand
    $WebAssemblyManifestDir = Join-Path -Path $ManifestDir -ChildPath "webassembly.sdk.manifest"
    $WebAssemblyManifestFile = Join-Path -Path $WebAssemblyManifestDir -ChildPath "WorkloadManifest.json"

    # Check and remove already installed old version.
    if (Test-Path $WebAssemblyManifestFile) {
        $ManifestJson = $(Get-Content $WebAssemblyManifestFile | ConvertFrom-Json)
        $OldVersion = $ManifestJson.version
        if ($OldVersion -eq $Version) {
            $DotnetWorkloadList = Invoke-Expression "& '$DotnetCommand' workload list | Select-String -Pattern '^webassembly'"
            if ($DotnetWorkloadList)
            {
                Write-Host "WebAssembly Workload $Version version is already installed."
                Continue
            }
        }

        Ensure-Directory $ManifestDir
        Write-Host "Removing $ManifestName/$OldVersion from $ManifestDir..."
        Remove-Pack -Id $ManifestName -Version $OldVersion -Kind "manifest"
        $ManifestJson.packs.PSObject.Properties | ForEach-Object {
            Write-Host "Removing $($_.Name)/$($_.Value.version)..."
            Remove-Pack -Id $_.Name -Version $_.Value.version -Kind $_.Value.kind
        }
    }

    Ensure-Directory $ManifestDir
    $TempDir = $(New-TemporaryDirectory)

    # Install workload manifest.
    Write-Host "Installing $ManifestName/$Version to $ManifestDir..."
    Install-Pack -Id $ManifestName -Version $Version -Kind "manifest" -Source $Source

    # Download and install workload packs.
    $NewManifestJson = $(Get-Content $WebAssemblyManifestFile | ConvertFrom-Json)
    $NewManifestJson.packs.PSObject.Properties | ForEach-Object {
        Write-Host "Installing $($_.Name)/$($_.Value.version)..."
        Install-Pack -Id $_.Name -Version $_.Value.version -Kind $_.Value.kind -Source $Source
    }

    # Add webassembly to the installed workload metadata.
    # Featured version band for metadata does NOT include any preview specifier.
    # https://github.com/dotnet/sdk/blob/main/documentation/general/workloads/user-local-workloads.md
    New-Item -Path $(Join-Path -Path $DotnetInstallDir -ChildPath "metadata\workloads\$DotnetVersionBand\InstalledWorkloads\webassembly") -Force | Out-Null
    if (Test-Path $(Join-Path -Path $DotnetInstallDir -ChildPath "metadata\workloads\$DotnetVersionBand\InstallerType\msi")) {
        New-Item -Path "HKLM:\SOFTWARE\Microsoft\dotnet\InstalledWorkloads\Standalone\x64\$DotnetTargetVersionBand\webassembly" -Force | Out-Null
    }

    # Clean up
    Remove-Item -Path $TempDir -Force -Recurse

    Write-Host "Done installing WebAssembly workload $Version"
}

# Check dotnet install directory.
if ($DotnetInstallDir -eq "<auto>") {
    if ($Env:DOTNET_ROOT -And $(Test-Path "$Env:DOTNET_ROOT")) {
        $DotnetInstallDir = $Env:DOTNET_ROOT
    } else {
        $DotnetInstallDir = Join-Path -Path $Env:Programfiles -ChildPath "dotnet"
    }
}
if (-Not $(Test-Path "$DotnetInstallDir")) {
    Write-Error "No installed dotnet '$DotnetInstallDir'."
}

# Check installed dotnet version
$DotnetCommand = "$DotnetInstallDir\dotnet"
if (Get-Command $DotnetCommand -ErrorAction SilentlyContinue)
{
    if ($UpdateAllWorkloads.IsPresent)
    {
        $InstalledDotnetSdks = Invoke-Expression "& '$DotnetCommand' --list-sdks | Select-String -Pattern '^6|^7'" | ForEach-Object {$_ -replace (" \[.*","")}
    }
    else
    {
        $InstalledDotnetSdks = Invoke-Expression "& '$DotnetCommand' --version"
    }
}
else
{
    Write-Error "'$DotnetCommand' occurs an error."
}

if (-Not $InstalledDotnetSdks)
{
    Write-Host "`n.NET SDK version 6 or later is required to install WebAssembly Workload."
}
else
{
    foreach ($DotnetSdk in $InstalledDotnetSdks)
    {
        try {
            Write-Host "`nCheck WebAssembly Workload for sdk $DotnetSdk"
            Install-WebAssemblyWorkload -DotnetVersion $DotnetSdk -Source $Source
        }
        catch {
            Write-Host "Failed to install WebAssembly Workload for sdk $DotnetSdk"
            Write-Host "$_"
            Continue
        }
    }
}

Write-Host "`nDone"
