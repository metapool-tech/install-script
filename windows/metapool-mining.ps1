$randomPort = Get-Random -Minimum 49152  -Maximum 65535 

$config = @"
{
    "logPath": "./logs/",
    "diff1TargetNumZero": 30,
    "serverHost": "eu.metapool.tech",
    "serverPort": 20032,
    "proxyPort": $randomPort,
    "addresses": [ 
        "your-mining-address-1",
        "your-mining-address-2", 
        "your-mining-address-3", 
        "your-mining-address-4"
    ]
}
"@
$config = (ConvertFrom-Json $config)

$runMiner = @"
# WORKAROUND: Change the value below to change how often the proxy restarts (total amount of seconds)
`$proxy_restart_time=[int](30*60) # default : 30 minutes


















cd `$PSScriptRoot

if (!(Test-Path "`$PSScriptRoot\config.json" -PathType Leaf)){
	Write-Host "Error, pool configuration file could not be found"
	Write-Host "Press any key to exit..."
	`$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
	Exit
}

`$ErrorActionPreference= 'silentlycontinue'
`$pool_cfg=Get-Content "`$PSScriptRoot\config.json" | ConvertFrom-Json -ErrorAction SilentlyContinue
if (`$pool_cfg -eq `$null){
	Write-Host "Error, pool configuration file is corrupted"
	Write-Host "Press any key to exit..."
	`$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
	Exit
}
`$ErrorActionPreference= 'continue'
`$mining_addresses=`$pool_cfg.addresses
if (`$mining_addresses[0] -eq "your-mining-address-1" -or `$mining_addresses[1] -eq "your-mining-address-2" -or `$mining_addresses[2] -eq "your-mining-address-3" -or `$mining_addresses[3] -eq "your-mining-address-4"){
	Write-Host "Error, one or more of your mining addresses were not properly set in the file ``"config.json``"."
	Write-Host "Press any key to exit..."
	`$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
	Exit
	}

`$proxy_pid=`$null
`$proxy_start_ts=`$null
`$miner_pid=`$null
# Use try-finally to kill the miner automatically when the script stops (ctrl+c only)
try{
	while(`$true){
		# if we don't have an associated PID, spawn the proxy and wait 3 seconds to ensure it started properly
		if (`$proxy_pid -eq `$null){
			`$proxy_pid = (Start-Process "`$PSScriptRoot\alephium-mining-proxy.exe" -PassThru).ID
			`$proxy_start_ts=[int](Get-Date -UFormat %s -Millisecond 0)
			Start-Sleep -Seconds 3
		}
		
		# if we don't have an associated PID, spawn the miner and wait 10 seconds to ensure it started mining properly
		if (`$miner_pid -eq `$null){
			`$miner_pid = (Start-Process "`$PSScriptRoot\alephium-gpu-miner.exe" "-p $randomPort" -PassThru).ID
			Start-Sleep -Seconds 10
		}
		
		# Check if the proxy process died
		if (-not (Get-Process -Id `$proxy_pid -ErrorAction SilentlyContinue)) {
			Write-Host "Proxy died, restarting it..."
			`$proxy_pid=`$null
			continue
		}

		# WORKAROUND : restart the proxy every 30 minutes
		if ( ([int](Get-Date -UFormat %s -Millisecond 0) - `$proxy_start_ts) -gt `$proxy_restart_time) {
			Write-Host "WORKAROUND: Restarting proxy before stale jobs appear..."
			Stop-Process -Id `$proxy_pid -ErrorAction SilentlyContinue
			`$proxy_pid=`$null
			continue
		}
		
		# Check if the miner process died
		if (-not (Get-Process -Id `$miner_pid -ErrorAction SilentlyContinue)) {
			Write-Host "Miner died, restarting it..."
			`$miner_pid=`$null
			continue
		}
		

		# Sleep 10 seconds before checking again
		Start-Sleep -Seconds 10
	}
}
finally
{
	if (`$proxy_pid -ne `$null) {
		Stop-Process -Id `$proxy_pid -ErrorAction SilentlyContinue
	}
	
	if (`$miner_pid -ne `$null) {
		Stop-Process -Id `$miner_pid -ErrorAction SilentlyContinue
	}
}
"@



Write-Output "Thank you for mining with Metapool !"
Write-Output ""

$isNvidia = (Get-WmiObject win32_VideoController).Description.StartsWith("NVIDIA")

if($isNvidia) {
   Write-Output "Detected Nvidia gpu, downloading appropriate miner."
   $ProgressPreference = 'SilentlyContinue'
   Invoke-WebRequest -Uri "https://github.com/alephium/gpu-miner/releases/download/v0.5.4/alephium-0.5.4-cuda-miner-windows.exe" -OutFile "alephium-gpu-miner.exe"
   $ProgressPreference = 'Continue'
   Write-Output "Done."
}else {
   Write-Output "Detected unknown gpu, assuming it's AMD, downloading appropriate miner."
   $ProgressPreference = 'SilentlyContinue'
   Invoke-WebRequest -Uri "https://github.com/alephium/amd-miner/releases/download/v0.2.0/alephium-0.2.0-amd-miner-windows.exe" -OutFile "alephium-gpu-miner.exe"
   $ProgressPreference = 'Continue'
   Write-Output "Done."
}

Write-Output "Downloading mining proxy. (could take a minute)"
$ProgressPreference = 'SilentlyContinue'
Invoke-WebRequest -Uri "https://github.com/alephium/mining-proxy/releases/download/v0.2.1/alephium-mining-proxy-0.2.1-windows.exe" -OutFile "alephium-mining-proxy.exe"
$ProgressPreference = 'Continue'
Write-Output "Done."
Write-Output ""
Set-Content -Path .\metapool-run.ps1 -Value $runMiner
Set-Content -Path .\metapool-run.cmd -Value "powershell -ExecutionPolicy Bypass -File %~dp0\metapool-run.ps1"

# If there is an existing configuration, try to use its addresses
$ErrorActionPreference= 'silentlycontinue'
if ((Test-Path ".\config.json" -PathType Leaf)){
	$existing_cfg = Get-Content ".\config.json" | ConvertFrom-Json -ErrorAction SilentlyContinue
	if ([bool]($existing_cfg -ne $null -and $existing_cfg.PSobject.Properties.name -match "addresses")){
		$config.addresses= $existing_cfg.addresses
	}
}
$ErrorActionPreference= 'continue'

Set-Content -Path .\config.json -Value (ConvertTo-Json $config)

Write-Output "To get started, you must first edit the file `"config.json`", and insert your mining addresses."
Write-Output "Afterward, you can simply start mining with Metapool by using the `"metapool-run.ps1`" powershell script, or the `"metapool-run.cmd`" helper"
