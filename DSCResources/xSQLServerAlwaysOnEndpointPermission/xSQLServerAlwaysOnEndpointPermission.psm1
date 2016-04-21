$ErrorActionPreference = "Stop"

$currentPath = Split-Path -Parent $MyInvocation.MyCommand.Path
import-module $currentPath\..\..\xSqlServerAlwaysOnUtil.psm1 -ErrorAction Stop

function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $InstanceName,

        [parameter(Mandatory = $true)]
        [System.String]
        $NodeName,

        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [parameter(Mandatory = $true)]
        [System.String]
        $Principal
    )

    try {
        $endpoint = Get-SQLAlwaysOnEndpoint -Name $Name -NodeName $NodeName -InstanceName $InstanceName -Verbose:$VerbosePreference
        
        if( $null -ne $endpoint ) {
            Write-Verbose "Enumerating permissions for Endpoint $Name"

            $permissionSet = New-Object -Property @{ Connect = $True } -TypeName Microsoft.SqlServer.Management.Smo.ObjectPermissionSet

            $endpointPermission = $endpoint.EnumObjectPermissions( $permissionSet ) | Where-Object { $_.PermissionState -eq "Grant" -and $_.Grantee -eq $Principal }
            if( $endpointPermission.Count -ne 0 ) {
                $Ensure = "Present"
                $Permission = "CONNECT"
            } else {
                $Ensure = "Absent"
                $Permission = ""
            }
        } else {
            throw "Endpoint $Name does not exist"
        }
    } catch {
        throw "Unexpected result when trying to verify existance of endpoint $Name. Error: $($_.Exception.Message)"
    }

    $returnValue = @{
        InstanceName = [System.String]$InstanceName
        NodeName = [System.String]$NodeName
        Ensure = [System.String]$Ensure
        Name = [System.String]$Name
        Principal = [System.String]$Principal
        Permission = [System.String]$Permission
    }

    return $returnValue
}


function Set-TargetResource
{
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $InstanceName,

        [parameter(Mandatory = $true)]
        [System.String]
        $NodeName,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure,

        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [parameter(Mandatory = $true)]
        [System.String]
        $Principal,

        [ValidateSet("CONNECT")]
        [System.String]
        $Permission
    )

    $parameters = @{
        InstanceName = [System.String]$InstanceName
        NodeName = [System.String]$NodeName
        Name = [System.String]$Name
        Principal = [System.String]$Principal
    }
    
    $endPointPermissionState = Get-TargetResource @parameters 
    if( $null -ne $endPointPermissionState ) {
        if( $endPointPermissionState.Ensure -ne $Ensure ) {
            $endpoint = Get-SQLAlwaysOnEndpoint -Name $Name -NodeName $NodeName -InstanceName $InstanceName -Verbose:$VerbosePreference
            if( $null -ne $endpoint ) {
                $permissionSet = New-Object -Property @{ Connect = $True } -TypeName Microsoft.SqlServer.Management.Smo.ObjectPermissionSet
                
                if( $Ensure -eq "Present") {
                    if( ( $PSCmdlet.ShouldProcess( $Name, "Grant permission to $Principal on Endpoint" ) ) ) {
                        $endpoint.Grant($permissionSet, $Principal )
                    }
                } else {
                    if( ( $PSCmdlet.ShouldProcess( $Name, "Revoke permission to $Principal on Endpoint" ) ) ) {
                        $endpoint.Revoke($permissionSet, $Principal )
                    }
                }
            } else {
                throw "Endpoint $Name does not exist. Could not set permission on endpoint."
            }
        } else {
            Write-Verbose "State is already $Ensure"
        }
    } else {
        throw "Got unexpected result from Get-TargetResource. No change is made."
    }

    #Include this line if the resource requires a system reboot.
    #$global:DSCMachineStatus = 1
}


function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $InstanceName,

        [parameter(Mandatory = $true)]
        [System.String]
        $NodeName,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure,

        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [parameter(Mandatory = $true)]
        [System.String]
        $Principal,

        [ValidateSet("CONNECT")]
        [System.String]
        $Permission
    )

    $parameters = @{
        InstanceName = [System.String]$InstanceName
        NodeName = [System.String]$NodeName
        Name = [System.String]$Name
        Principal = [System.String]$Principal
    }
    
    Write-Verbose "Testing state of endpoint permission for $Principal"

    $endPointPermissionState = Get-TargetResource @parameters 
    if( $null -ne $endPointPermissionState ) {
        if( $endPointPermissionState.Ensure -eq $Ensure) {
            [System.Boolean]$result = $True
        } else {
            [System.Boolean]$result = $False
        }
    } else {
        throw "Got unexpected result from Get-TargetResource. No change is made."
    }

    return $result
}

Export-ModuleMember -Function *-TargetResource

