[version]$mining_stack_installer_version='0.2.1'
$ADDRESS=""

$runMiner = @"
cd `$PSScriptRoot

# Current mining stack version
[version]`$mining_stack_version='$mining_stack_installer_version'

# get the latest version from website
`$ErrorActionPreference= 'silentlycontinue'
`$cmd = (New-Object system.Net.WebClient).downloadString('http://www.metapool.tech/windows/metapool-mining.ps1')
`$ErrorActionPreference= 'continue'
# If we were able to get it, check if the version changed
if (`$cmd){
    Invoke-Expression (`$cmd -split '\n')[0]
    if (`$mining_stack_installer_version -gt `$mining_stack_version){
        # there is an update, suggest the user to apply it
        Write-Host 'There is an update available to the pool mining software.'

        `$decision = Read-Host 'Do you wish to update ? [Y/n]'
        Write-Host `$decision
        if (`$decision -ne 'n') {
            Write-Host 'applying update...'
            iex ((New-Object System.Net.WebClient).DownloadString('http://www.metapool.tech/windows/metapool-mining.ps1'))
            Write-Host "Update completed, please launch the mining software again..."
            Sleep 5
            Exit
        } else  {
            Write-Host 'Launching miner...'
        }
    }
}


if (!(Test-Path "`$PSScriptRoot\config.txt" -PathType Leaf)){
	Write-Host "Error, pool configuration file could not be found"
	Write-Host "Press any key to exit..."
	`$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
	Exit
}

`$ErrorActionPreference= 'silentlycontinue'
`$pool_cfg=Get-Content "`$PSScriptRoot\config.txt" | ConvertFrom-Json -ErrorAction SilentlyContinue
if (`$pool_cfg -eq `$null){
	Write-Host "Error, pool configuration file is corrupted"
	Write-Host "Press any key to exit..."
	`$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
	Exit
}
`$ErrorActionPreference= 'continue'

if (((Get-Content "`$PSScriptRoot\config.txt" | ConvertFrom-Json).pool_configs -eq `$null) -or
   ((Get-Content "`$PSScriptRoot\config.txt" | ConvertFrom-Json).pool_configs[0] -eq `$null) -or
   ((Get-Content "`$PSScriptRoot\config.txt" | ConvertFrom-Json).pool_configs[0].wallet -eq `$null) -or
   ((Get-Content "`$PSScriptRoot\config.txt" | ConvertFrom-Json).pool_configs[0].wallet -eq "your-mining-address")){
    Write-Host "Error, wallet address can't be found, or is invalid"
    Write-Host "Press any key to exit..."
    `$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Exit
}
Start-Process -Wait -NoNewWindow -FilePath "`$PSScriptRoot\bzminer.exe" -ArgumentList "-c", "`$PSScriptRoot\config.txt"
"@

Write-Output "Thank you for mining with Metapool !"
Write-Output ""

#Code from https://stackoverflow.com/a/21422517
function DownloadFile($url, $targetFile)
{
   $uri = New-Object "System.Uri" "$url"
   $request = [System.Net.HttpWebRequest]::Create($uri)
   $request.set_Timeout(15000) #15 second timeout
   $response = $request.GetResponse()
   $totalLength = [System.Math]::Floor($response.get_ContentLength()/1024)
   $responseStream = $response.GetResponseStream()
   try {
        $targetStream = New-Object -TypeName System.IO.FileStream -ArgumentList $targetFile, Create
   } catch {
        Write-warning "Error, can't write to $targetFile, probably open in another process"
        Exit
   }
   $buffer = new-object byte[] 50KB
   $count = $responseStream.Read($buffer,0,$buffer.length)
   $downloadedBytes = $count
   while ($count -gt 0)
   {
       $targetStream.Write($buffer, 0, $count)
       $count = $responseStream.Read($buffer,0,$buffer.length)
       $downloadedBytes = $downloadedBytes + $count
       Write-Progress -activity "Downloading file '$($url.split('/') | Select -Last 1)'" -status "Downloaded ($([System.Math]::Round($downloadedBytes/1024/1024, 2))M of $([System.Math]::Round($totalLength/1024,2))M): " -PercentComplete ((([System.Math]::Floor($downloadedBytes/1024)) / $totalLength)  * 100)
   }
   Write-Progress -activity "Finished downloading file '$($url.split('/') | Select -Last 1)'"
   $targetStream.Flush()
   $targetStream.Close()
   $targetStream.Dispose()
   $responseStream.Dispose()
}

$DELETE_REF=$false
# If the old ref miner is present
if ((Test-Path ".\alephium-gpu-miner.exe" -PathType Leaf) -or
    (Test-Path ".\alephium-mining-proxy.exe" -PathType Leaf) -or
    (Test-Path ".\config.json" -PathType Leaf)){
    Write-Output "Remaining parts of reference Alephium miner installation were found."
    Write-Output "Proceeding with the installation will remove the reference miner, and replace it with Bzminer."
    $decision = Read-Host 'Do you wish to proceed ? [Y/n]'
    if ($decision -ne 'n') {
        Write-Host 'Continuing installation...'
        if ((Test-Path "config.json" -PathType Leaf) -and
            !((Get-Content "config.json" | ConvertFrom-Json -ErrorAction SilentlyContinue) -eq $null) -and
            !((Get-Content "config.json" | ConvertFrom-Json).address -eq $null) -and
            !((Get-Content "config.json" | ConvertFrom-Json).address -eq "your-mining-address")){
                Write-Host "Existing wallet configuration found, keeping it..."
                $ADDRESS = (Get-Content "config.json" | ConvertFrom-Json).address
        }

        $DELETE_REF=$true
    } else  {
        Write-Host 'Installation canceled !'
        Exit
    }
} else {
    # Otherwise see if we can load the address from the config.txt of Bzminer
    if((Test-Path "config.txt" -PathType Leaf) -and
       !((Get-Content "config.txt" | ConvertFrom-Json -ErrorAction SilentlyContinue) -eq $null) -and
       !((Get-Content "config.txt" | ConvertFrom-Json).pool_configs -eq $null) -and
       !((Get-Content "config.txt" | ConvertFrom-Json).pool_configs[0] -eq $null) -and
       !((Get-Content "config.txt" | ConvertFrom-Json).pool_configs[0].wallet -eq $null) -and
       !((Get-Content "config.txt" | ConvertFrom-Json).pool_configs[0].wallet -eq "your-mining-address")){
            Write-Host "Existing wallet configuration found, keeping it..."
            $ADDRESS = (Get-Content "config.txt" | ConvertFrom-Json).pool_configs[0].wallet
    }
}

Write-host -NoNewline "Downloading Bzminer version 7.2.2 ..."
DownloadFile "https://github.com/bzminer/bzminer/releases/download/v7.2.2/bzminer_v7.2.2_windows_cuda_tk.zip" "./bzminer.zip"
Write-host "Done."
Write-host -NoNewline "Extracting miner..."
Add-Type -Assembly System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead("./bzminer.zip")
$zip.Entries | where {$_.Name -like 'bzminer.exe' -or $_.Name -like 'bzminercore.dll' -or $_.Name -like 'nvrtc64_112_0.dll' -or $_.Name -like 'nvrtc-builtins64_112.dll'} | foreach {[System.IO.Compression.ZipFileExtensions]::ExtractToFile($_, $_.Name, $true)}
$zip.Dispose()
Write-host "Done."
if ([string]::IsNullOrEmpty($ADDRESS)){
    $ADDRESS = Read-Host 'Please enter your wallet address'
}

Write-host -NoNewline "Cleaning up files..."
if($DELETE_REF){
    try{
    Remove-Item -LiteralPath "alephium-mining-proxy.exe" -Force
    } catch {}
    try{
    Remove-Item -LiteralPath "alephium-gpu-miner.exe" -Force
    }  catch {}
    try{
    Remove-Item -LiteralPath "config.json" -Force
    } catch {}
}
Remove-Item -LiteralPath "./bzminer.zip" -Force
Write-host "Done."

$config = @"
{
    "pool_configs": [{
            "algorithm": "alph",
            "wallet": "$ADDRESS",
            "url": ["stratum+tcp://pool.metapool.tech:20032"],
            "username": "worker_name",
            "lhr_only": false
        }],
    "pool": [0],
    "rig_name": "rig",
    "log_file": "",
    "nvidia_only": false,
    "amd_only": false,
    "auto_detect_lhr": false,
    "lock_config": false,
    "advanced_config": false,
    "advanced_display_config": false,
    "device_overrides": []
}
"@

Set-Content -Path .\metapool-run.ps1 -Value $runMiner
Set-Content -Path .\metapool-run.cmd -Value "powershell -ExecutionPolicy Bypass -File %~dp0\metapool-run.ps1"

Set-Content -Path .\config.txt -Value $config

Write-host "To get started mining with Metapool.tech, you can use the `"metapool-run.ps1`" powershell script, or the `"metapool-run.cmd`" helper"
