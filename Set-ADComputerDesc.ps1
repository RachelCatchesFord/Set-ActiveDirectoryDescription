<#
    Authors: Rachel Catches-Ford & Brandon Kessler
    Date: 2020.09.17
    Purpose: Set the Active Directory Computer Description to Serial Number and Asset Tag, in our case, the Lease Expiration Date.
    Example: Set-ADDescription -CompEnv Local   # This will set the Computer Description running locally.
    Example: Set-ADDescription -CompEnv TS      # This will set the Computer Description via a Task Sequence and set the TS Variable.
#>

function Get-ExpirationType {
    param(
        [parameter(Mandatory=$true)][string]$RegLoc,
        [parameter(Mandatory=$true)][validateset('AssetTag','WarrantyEndDate')][string]$ExpType
    )
    
    if(!(Test-Path -Path $RegLoc)){ ## Test for Registry Location
        Write-Error "Cannot find location $RegLoc"
        Exit 1
    }

    if(!(Get-ItemProperty -Path $RegLoc | Select-Object $ExpType)){ ## Look for Asset Tag in Registry
        Write-Error "$ExpType not found at $RegLoc."
        Exit 1
    }

    $Exp = (Get-ItemProperty -Path $RegLoc).$ExpType
    Return $Exp
}

function Set-ADDescription{
    param(
        [parameter(Mandatory=$true)][validateset('Local','TS')][string]$CompEnv,
        [parameter(Mandatory=$true)][string]$SiteCode,
        [parameter(Mandatory=$true)][string]$Exp
    )
     
    if($CompEnv -eq 'Local'){ ## use Parameter to determine whether in TS or not
        $CompName = $env:COMPUTERNAME
    }else{
        $CompName = $sAMCompName
    }

    $BIOS = Get-CimInstance -ClassName Win32_SystemEnclosure
    $SN = $BIOS.SerialNumber
    $ComputerDn = ([ADSISEARCHER]"sAMAccountName=$($CompName)$").FindOne().Path
    $ADComputer = [ADSI]$ComputerDn
    
    if($CompName -match "[DHS]$SN"){ ## RegEx to determine if new naming convention
        $ADComputer.description = "Site: $SiteCode | Exp: $Exp"
    }Else{
        $ADComputer.description = "SN: $SN | Exp: $Exp"
    }
    $ADComputer.SetInfo()
}

$BIOS = Get-CimInstance -ClassName Win32_SystemEnclosure
$Manufacturer = $BIOS.Manufacturer
$RegLoc = 'HKLM:\SOFTWARE\CustomInv'
$SiteCode = (Get-ItemProperty -Path $RegLoc).SiteCode

switch($Manufacturer){
    'Dell'{$Exp = Get-ExpirationType -RegLoc $RegLoc -ExpType 'WarrantyEndDate'}
    'HP'{$Exp = Get-ExpirationType -RegLoc $RegLoc -ExpType 'AssetTag'}
    'Lenovo'{$Exp = Get-ExpirationType -RegLoc $RegLoc -ExpType 'WarrantyEndDate'}
    'Microsoft'{$Exp = Get-ExpirationType -RegLoc $RegLoc -ExpType 'WarrantyEndDate'}
}



[string]$Description = $args[0]

try {
    $TSEnv = New-Object -ComObject Microsoft.SMS.TSEnvironment
    $TSEnv.Value("OSDComputerName") = $env:COMPUTERNAME
    $sAMCompName = $TSEnv.Value("OSDComputerName")        
    Set-ADDescription -CompEnv TS -SiteCode $SiteCode -Exp $Exp
    Write-Host("Setting the Active Directory Computer Description in a Task Sequence Environment to $($ADComputer.description)")
}catch {
    Set-ADDescription -CompEnv Local -SiteCode $SiteCode -Exp $Exp
    Write-Host("Setting the Active Directory Computer Description Locally to $($ADComputer.description)")
}