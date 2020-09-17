<#
    Authors: Rachel Catches-Ford & Brandon Kessler
    Date: 2020.09.17
    Purpose: Set the Active Directory Computer Description to Serial Number and Asset Tag, in our case, the Lease Expiration Date.
    Example: Set-ADDescription -CompEnv Local   # This will set the Computer Description running locally.
    Example: Set-ADDescription -CompEnv TS      # This will set the Computer Description via a Task Sequence and set the TS Variable.
#>

function Set-ADDescription{
    param(
        [parameter(Mandatory=$true)][validateset('Local','TS')][string]$CompEnv
    )
    if($CompEnv -eq 'Local'){
        $CompName = $env:COMPUTERNAME
    }else{
        $CompName = $sAMCompName
    }
    $BIOS = Get-CimInstance -ClassName Win32_SystemEnclosure
    $SN = $BIOS.SerialNumber
    $Exp = $BIOS.SMBIOSAssetTag
    $ComputerDn = ([ADSISEARCHER]"sAMAccountName=$($CompName)$").FindOne().Path
    $ADComputer = [ADSI]$ComputerDn
    if($SN -eq $Exp){
        $ADComputer.description = $SN
    }Else{
        $ADComputer.description = "SN: $SN | Exp: $Exp"
    }
    $ADComputer.SetInfo()
}


[string]$Description = $args[0]

    try {
        $TSEnv = New-Object -ComObject Microsoft.SMS.TSEnvironment
        $TSEnv.Value("OSDComputerName") = $env:COMPUTERNAME
        $sAMCompName = $TSEnv.Value("OSDComputerName")
        Write-Host("Setting the Active Directory Computer Description in a Task Sequence Environment")
        Set-ADDescription -CompEnv TS
    }
    catch {
        Write-Host("Setting the Active Directory Computer Description Normally")
        Set-ADDescription -CompEnv Local
    }