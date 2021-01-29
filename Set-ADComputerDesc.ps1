<#
    Authors: Rachel Catches-Ford & Brandon Kessler
    Date: 2020.09.17
    Purpose: Set the Active Directory Computer Description to Serial Number and Asset Tag, in our case, the Lease Expiration Date.
    Example: Set-ADDescription -CompEnv Local   # This will set the Computer Description running locally.
    Example: Set-ADDescription -CompEnv TS      # This will set the Computer Description via a Task Sequence and set the TS Variable.
#>

function Set-ADDescription{
    param(
        [parameter(Mandatory=$true)][validateset('Local','TS')][string]$CompEnv,
        [parameter(Mandatory=$true)][validateset('AssetTag','Warranty')][string]$ExpType,
        [parameter][string]$RegLoc = 'HKLM:\SOFTWARE\CustomInv'
    )
    
    
    if(!(Test-Path -Path $RegLoc)){
        Write-Error "Cannot find location $RegLoc"
        Exit 1
    }
    
    
    if($CompEnv -eq 'Local'){
        $CompName = $env:COMPUTERNAME
    }else{
        $CompName = $sAMCompName
    }

    if(!(Get-ItemProperty -Path $RegLoc | Select-Object AssetTag)){
        Write-Error "Asset Tag not found at $RegLoc."
        Exit 1
    }

    if(!(Get-ItemProperty -Path $RegLoc | Select-Object WarrantyEndDate)){
        Write-Error "Warranty End Date not found at $RegLoc."
        Exit 1
    }

    if($ExpType -eq 'AssetTag'){
        $Exp = (Get-ItemProperty -Path $RegLoc).AssetTag
    }else{
        $Exp = (Get-ItemProperty -Path $RegLoc).WarrantyEndDate
    }

    $BIOS = Get-CimInstance -ClassName Win32_SystemEnclosure
    $SN = $BIOS.SerialNumber
    $SiteCode = (Get-ItemProperty -Path $RegLoc).SiteCode
    $ComputerDn = ([ADSISEARCHER]"sAMAccountName=$($CompName)$").FindOne().Path
    $ADComputer = [ADSI]$ComputerDn
    
    if($CompName -match "[DHS]$SN"){
        $ADComputer.description = "Site: $SiteCode | Exp: $Exp"
    }Else{
        $ADComputer.description = "SN: $SN | Exp: $Exp"
    }
    $ADComputer.SetInfo()
}

$BIOS.Manufacturer

[string]$Description = $args[0]

    try {
        $TSEnv = New-Object -ComObject Microsoft.SMS.TSEnvironment
        $TSEnv.Value("OSDComputerName") = $env:COMPUTERNAME
        $sAMCompName = $TSEnv.Value("OSDComputerName")        
        Set-ADDescription -CompEnv TS
        Write-Host("Setting the Active Directory Computer Description in a Task Sequence Environment to $($ADComputer.description)")
    }
    catch {
        Set-ADDescription -CompEnv Local
        Write-Host("Setting the Active Directory Computer Description Locally to $($ADComputer.description)")
    }