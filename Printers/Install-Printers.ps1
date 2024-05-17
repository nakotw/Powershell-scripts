Function Set-LocalPrinters {
    param (
        [string]$server,

        [string]$printerName
    )
    $printerPath = $null
    $PrinterPath = "\\$($server)\$($printerName)"
    $netConn = Test-NetConnection -ComputerName $Server | select-object PingSucceeded, NameResolutionSucceeded
    if (($netconn.PingSucceeded) -and ($netConn.NameResolutionSucceeded)) {
        write-host "Installing $printerName.." -ForegroundColor Green
        if (Get-Printer -Name "\\SRVPRINT2\203 Photocopieur" -ErrorAction SilentlyContinue) {
            Write-Host "Printer $printerPath already installed" -ForegroundColor Green
        }
        else {
            Write-Host "Installing $printerPath" -ForegroundColor Green
            & cscript /noLogo C:\windows\System32\Printing_Admin_Scripts\en-US\prnmngr.vbs -ac -p $printerPath
            if (Get-Printer -Name "\\SRVPRINT2\203 Photocopieur" -ErrorAction SilentlyContinue) {
                Write-Host "$printerPath successfully installed.."
                New-Item "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\$printerName.log" -Force
            }
            else {
                Write-Warning "$printerPath not successfully installed"
            }
        }
    }
    else {
        Write-Host "Print server not pingable. $printerPath will not be installed" -ForegroundColor Red
    }
}


$printers = @(
    [PSCustomObject]@{
        Printer = "COP203P01"
        Server = "SRVPRINT2.csjs.qc.ca"
    }
)

Set-LocalPrinters -server $p.Server -printerName $p.Printer