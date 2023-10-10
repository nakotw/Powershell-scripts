$global:PackageName = "SharedPrinters"

$Path_local_system = "$Env:Programfiles\_MEM"
$Path_local_user = "$Env:LOCALAPPDATA\_MEM"

###########################################################################################
# Input values 
$Prt_Server = "outils01"
$Prt_Shares = "7Ninfo1hp", "7Ninfo2hp", "7CEntrepot2Ricoh", "7NEntrepot2Ricoh"


###########################################################################################


# check if running as system
function Test-RunningAsSystem {
    [CmdletBinding()]
    param()
    process {
        return [bool]($(whoami -user) -match "S-1-5-18")
    }
}

function Invoke-PrinterMapping {
    Param
    (
        [Parameter(Mandatory = $true)] [string] $Prt_Server,
        [Parameter(Mandatory = $true)] [string[]] $Prt_Shares
    )
    Write-Host "Mapping Printers..."
    # process all Printers from $Prt_Server
    foreach ($Printer in $Prt_Shares) {
        $PrinterShareName = "\\$Prt_Server\$Printer"
        Write-Host "Processing: $PrinterShareName" -ForegroundColor Cyan
        # Check if Printer exists
        $checkPrinterExists = Get-Printer -Name $PrinterShareName -ErrorAction SilentlyContinue
        if ($checkPrinterExists) {
            Write-Host "  $Printer, already installed!"
        }
        else {
            # try/catch adding printer
            try {
                Add-Printer -ConnectionName "$PrinterShareName" -ErrorAction Stop
            }
            catch {
                Write-Host "Error adding $PrinterShareName" -ForegroundColor Red
                Write-Host $_
                Write-Host " "
            }
        }
    }
    Write-Host "--------------------------------------------------------------------------"
}


Write-Output "Running as SYSTEM: $(Test-RunningAsSystem)"

# Processing Printers in user context
if (-not (Test-RunningAsSystem)) {
    Start-Transcript -Path "$Path_local_user\Log\$global:PackageName-$env:UserName.log" -Force

    Write-Host "Testing Server connection..."
    $testConnection = $(Test-netConnection $Prt_Server -port 445).TcpTestSucceeded 
    $testConnection
    if ($testConnection -eq $true) {
        if ($Prt_Shares) { Invoke-PrinterMapping $Prt_Server $Prt_Shares }
    }

    Stop-Transcript
}



#!ENDUSERCONTEXT!#

# Create Sceduled Task as System
if (Test-RunningAsSystem) {

    Start-Transcript -Path "$Path_local_system\Log\$global:PackageName-$env:UserName.log" -Force
    Write-Host "Processing scheduled task which will run on user logon and network changes..."

    # get this script content
    $currentScript = Get-Content -Path $($PSCommandPath)
    $schtaskScript = $currentScript[(0) .. ($currentScript.IndexOf("#!ENDUSERCONTEXT!#") - 1)]
    $scriptSavePath = $(Join-Path -Path "$Path_local_system\Data" -ChildPath "printer-mapping")
    # Create Path if not exists
    if (-not (Test-Path $scriptSavePath)) { New-Item -ItemType Directory -Path $scriptSavePath -Force }
    # Save this file on local computer
    $PS_PathName = "$global:PackageName.ps1"
    $PS_ScriptPath = $(Join-Path -Path $scriptSavePath -ChildPath $PS_PathName)
    Write-Host "Saving script on localy ($PS_ScriptPath)..."
    $schtaskScript | Out-File -FilePath $PS_ScriptPath -Force

    # Dummy vbscript to hide PowerShell Window popping up at task execution
    $vbsHiddenPS = "
	Dim shell,fso,file

	Set shell=CreateObject(`"WScript.Shell`")
	Set fso=CreateObject(`"Scripting.FileSystemObject`")

	strPath=WScript.Arguments.Item(0)

	If fso.FileExists(strPath) Then
		set file=fso.GetFile(strPath)
		strCMD=`"powershell -nologo -executionpolicy ByPass -command `" & Chr(34) & `"&{`" &_
		file.ShortPath & `"}`" & Chr(34)
		shell.Run strCMD,0
	End If
	"
    $vbs_Name = "run-ps-hidden.vbs"
    $vbs_ScriptPath = $(Join-Path -Path $scriptSavePath -ChildPath $vbs_Name)
    Write-Host "Savin & create vbs ($vbs_ScriptPath)..."
    $vbsHiddenPS | Out-File -FilePath $vbs_ScriptPath -Force

    # Register scheduled task to run for all users, trigers: logon and network changes
    $schtaskName = "$global:PackageName"
    Write-Host "Creating ScheduledTask ($schtaskName)..."
    $schtaskDescription = "Map network printers on logon and network change. "

    $trigger1 = New-ScheduledTaskTrigger -AtLogOn

    $class = Get-cimclass MSFT_TaskEventTrigger root/Microsoft/Windows/TaskScheduler
    $trigger2 = $class | New-CimInstance -ClientOnly
    $trigger2.Enabled = $True
    $trigger2.Subscription = '<QueryList><Query Id="0" Path="Microsoft-Windows-NetworkProfile/Operational"><Select Path="Microsoft-Windows-NetworkProfile/Operational">*[System[Provider[@Name=''Microsoft-Windows-NetworkProfile''] and EventID=10002]]</Select></Query></QueryList>'
	
    $trigger3 = $class | New-CimInstance -ClientOnly
    $trigger3.Enabled = $True
    $trigger3.Subscription = '<QueryList><Query Id="0" Path="Microsoft-Windows-NetworkProfile/Operational"><Select Path="Microsoft-Windows-NetworkProfile/Operational">*[System[Provider[@Name=''Microsoft-Windows-NetworkProfile''] and EventID=4004]]</Select></Query></QueryList>'
	
    # Execute as user
    $principal = New-ScheduledTaskPrincipal -GroupId "S-1-5-32-545" -Id "Author"
	
    # call the vbscript helper and pass the PosH script as argument
    $action = New-ScheduledTaskAction -Execute $(Join-Path $env:SystemRoot -ChildPath "System32\wscript.exe") -Argument "`"$vbs_ScriptPath`" `"$PS_ScriptPath`""
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    $null = Register-ScheduledTask -TaskName $schtaskName -Trigger $trigger1, $trigger2, $trigger3 -Action $action -Principal $principal -Settings $settings -Description $schtaskDescription -Force
		
    Stop-Transcript

}