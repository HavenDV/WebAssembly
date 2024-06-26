# WebAssembly

[![dotnet](https://github.com/HavenDV/WebAssembly/actions/workflows/dotnet.yml/badge.svg?branch=main)](https://github.com/HavenDV/WebAssembly/actions/workflows/dotnet.yml)
[![License: MIT](https://img.shields.io/github/license/HavenDV/WebAssembly)](https://github.com/HavenDV/WebAssembly/blob/main/LICENSE.txt)
[![Discord](https://img.shields.io/discord/1115206893015662663?label=Discord&logo=discord&logoColor=white&color=d82679)](https://discord.gg/Ca2xhfBf3v)

<b>WebAssembly</b> is separate TPM for developing WebAssembly applications within a single project, if there are other TargetFrameworks using the main `net8.0` TPM.

## Usage
Just install and add `net8.0-webassembly` to `TargetFrameworks`.

## Install
You can install WebAssembly workload for .NET 6.0/7.0/8.0 by using the installer script.
- On Linux / macOS:
```
curl -sSL https://raw.githubusercontent.com/HavenDV/WebAssembly/main/scripts/workload-install.sh | sudo bash
```
if you want to install a specific version of WebAssembly workload or install to a specific directory, use the following command:
```
curl -sSL https://raw.githubusercontent.com/HavenDV/WebAssembly/main/workload/scripts/workload-install.sh | bash /dev/stdin -v <version> -d <directory>
```
- On Windows:
```
Invoke-WebRequest 'https://raw.githubusercontent.com/HavenDV/WebAssembly/main/workload/scripts/workload-install.ps1' -OutFile 'workload-install.ps1';
./workload-install.ps1 [-v <version>] [-d <directory>]
```
You can see the WebAssembly workload as follows if it is properly installed.
```
PS D:\workspace> dotnet workload list

This command lists only workloads that were installed via `dotnet workload install` in this version of the SDK and not those that were installed via Visual Studio.

Installed Workload Ids
----------------------
maui
webassembly

Use `dotnet workload search` to find additional workloads to install.

Updates are avaliable for the following workload(s): maui webassembly. Run `dotnet workload update` to get the latest  
```

## Development
You can test this project using these commands(tested on macOS) in `src/tasks/tasks` folder:
```
dotnet build /t:TestWorkload
dotnet build /t:WorkloadUninstall

other possible targets(it already included in targets above):
DownloadDotnetInstall
DotnetInstall
WorkloadInstall
BuildPackages
CleanArtifactsAndTemporaryFiles

You can override these properties:
/p:UseCurrentDotnet=true - Will install workload to current dotnet instead downloaded.
```

### Disclaimer
Although this is a working solution, I have simplified some things regarding workload and manifest,
which could theoretically cause problems (for example, when upgrading to a new sdk version).  
I'll be glad to hear about it in issues.

### Docs
Official documentation regarding the design of Workloads and Sdks:
- https://github.com/dotnet/sdk/tree/main/documentation/general/workloads
- https://github.com/dotnet/designs/blob/main/accepted/2020/workloads/workloads.md
- https://github.com/dotnet/designs/blob/main/accepted/2020/workloads/workload-resolvers.md
- https://github.com/dotnet/designs/blob/main/accepted/2020/workloads/workload-manifest.md
- https://github.com/dotnet/designs/blob/main/accepted/2021/workloads/workload-installation.md
- MAUI Workload - https://github.com/dotnet/maui/tree/main/src/Workload
- Tizen Workload - https://github.com/Samsung/Tizen.NET/tree/main/workload

### Support
Priority place for bugs: https://github.com/HavenDV/WebAssembly/issues  
Priority place for ideas and general questions: https://github.com/HavenDV/WebAssembly/discussions  
Discord: https://discord.gg/g8u2t9dKgE  