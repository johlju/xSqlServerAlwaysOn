function Import-SQLPSModule {
    [CmdletBinding()]
    param()

    # If SQLPS is not removed between sessions (if it was started by another DSC resource) loading objects will fail in some instances
    # because of inconsistancy between sessions (or something)  
    if( (Get-Module SQLPS).Count -ne 0 ) {
        Write-Debug "Unloading SQLPS module."
        Remove-Module -Name SQLPS -Force -Verbose:$False
    }
    
    if( (Get-Module SQLASCMDLETS).Count -ne 0 ) {
        Write-Debug "Unloading SQLASCMDLETS module."
        Remove-Module -Name SQLASCMDLETS -Force -Verbose:$False
    }

    Write-Debug "SQLPS module changes CWD to SQLSERVER:\ when loading, pushing location to pop it when module is loaded."
    Push-Location

    Write-Verbose "Importing SQLPS module."
    Import-Module -Name SQLPS -DisableNameChecking -Verbose:$False -ErrorAction Stop # SQLPS has unapproved verbs, disable checking to ignore Warnings.
    Write-Debug "SQLPS module imported." 

    Write-Debug "Poping location back to what it was before importing SQLPS module."
    Pop-Location
}

function Get-SQLInstanceName
{
    [CmdletBinding()]
    [OutputType([string])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $InstanceName
    )

    if( $InstanceName -eq "MSSQLSERVER" ) {
        $InstanceName = "DEFAULT"            
    }
    
    return $InstanceName
}

function Get-SQLPSInstance
{
    [CmdletBinding()]
    [OutputType([string])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $InstanceName,

        [parameter(Mandatory = $true)]
        [System.String]
        $NodeName 
    )

    Import-SQLPSModule

    $InstanceName = Get-SQLInstanceName -InstanceName $InstanceName 
    $Path = "SQLSERVER:\SQL\$NodeName\$InstanceName"
    
    Write-Verbose "Connecting to $Path as $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)"
    
    $instance = Get-Item $Path
    
    return $instance
}

function Get-SQLAlwaysOnEndpoint
{
    [CmdletBinding()]
    [OutputType()]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [parameter(Mandatory = $true)]
        [System.String]
        $InstanceName,

        [parameter(Mandatory = $true)]
        [System.String]
        $NodeName 
    )

    $instance = Get-SQLPSInstance -InstanceName $InstanceName -NodeName $NodeName
    $Path = "$($instance.PSPath)\Endpoints"

    Write-Debug "Connecting to $Path as $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)"
    
    [string[]]$presentEndpoint = Get-ChildItem $Path
    if( $presentEndpoint.Count -ne 0 -and $presentEndpoint.Contains("[$Name]") ) {
        Write-Debug "Connecting to endpoint $Name as $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)"
        $endpoint = Get-Item "$Path\$Name"
    } else {
        $endpoint = $null
    }    

    return $endpoint
}

Export-ModuleMember -Function *-SQL*