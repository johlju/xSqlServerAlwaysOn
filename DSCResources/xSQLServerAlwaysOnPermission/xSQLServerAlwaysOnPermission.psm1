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
        $Principal,

        [ValidateSet("ALTER ANY AVAILABILITY GROUP","VIEW SERVER STATE","ALTER ANY ENDPOINT")]
        [System.String[]]
        $Permission
    )

    Write-Verbose "Enumerating permissions for $Principal"

    try {
        $instance = Get-SQLPSInstance -NodeName $NodeName -InstanceName $InstanceName -Verbose:$VerbosePreference

        $permissionSet = Get-SQLServerPermissionSet -Permission $Permission
        $enumeratedPermission = $instance.EnumServerPermissions( $Principal, $permissionSet ) | Where-Object { $_.PermissionState -eq "Grant" }
        if( $null -ne $enumeratedPermission) {
            $grantedPermissionSet = Get-SQLServerPermissionSet -PermissionSet $enumeratedPermission.PermissionType
            if( -not ( Compare-Object -ReferenceObject $permissionSet -DifferenceObject $grantedPermissionSet ) ) { 
                $ensure = "Present"
            } else {
                $ensure = "Absent"
            }

            $grantedPermission = Get-SQLPermission -ServerPermissionSet $grantedPermissionSet
        } else {
            $ensure = "Absent"
            $grantedPermission = ""
        }
    } catch {
        throw "Unexpected result when trying to fetch permissions for $Principal. Error: $($_.Exception.Message)"
    }

    $returnValue = @{
        InstanceName = [System.String]$InstanceName
        NodeName = [System.String]$NodeName
        Ensure = [System.String]$ensure
        Principal = [System.String]$Principal
        Permission = [System.String[]]$grantedPermission
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
        $Principal,

        [ValidateSet("ALTER ANY AVAILABILITY GROUP","VIEW SERVER STATE","ALTER ANY ENDPOINT")]
        [System.String[]]
        $Permission
    )

    $parameters = @{
        InstanceName = [System.String]$InstanceName
        NodeName = [System.String]$NodeName
        Principal = [System.String]$Principal
        Permission = [System.String[]]$Permission
    }
    
    $permissionState = Get-TargetResource @parameters 
    if( $null -ne $permissionState ) {
        if( $Ensure -ne "" ) {
            if( $permissionState.Ensure -ne $Ensure ) {
                $instance = Get-SQLPSInstance -NodeName $NodeName -InstanceName $InstanceName -Verbose:$VerbosePreference
                if( $null -ne $instance ) {
                    $permissionSet = Get-SQLServerPermissionSet -Permission $Permission
                    
                    if( $Ensure -eq "Present") {
                        if( ( $PSCmdlet.ShouldProcess( $Principal, "Grant permission" ) ) ) {
                            $instance.Grant($permissionSet, $Principal )
                        }
                    } else {
                        if( ( $PSCmdlet.ShouldProcess( $Principal, "Revoke permission" ) ) ) {
                            $instance.Revoke($permissionSet, $Principal )
                        }
                    }
                } else {
                    throw "$Principal does not exist. Could not set permission."
                }
            } else {
                Write-Verbose "State is already $Ensure"
            }
        } else  {
            throw "Ensure is not set. No change can be made."    
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
        $Principal,

        [ValidateSet("ALTER ANY AVAILABILITY GROUP","VIEW SERVER STATE","ALTER ANY ENDPOINT")]
        [System.String[]]
        $Permission
    )

    $parameters = @{
        InstanceName = [System.String]$InstanceName
        NodeName = [System.String]$NodeName
        Principal = [System.String]$Principal
        Permission = [System.String[]]$Permission
    }
    
    Write-Verbose "Testing state of permissions for $Principal"

    $permissionState = Get-TargetResource @parameters 
    if( $null -ne $permissionState ) {
        if( $permissionState.Ensure -eq $Ensure) {
            [System.Boolean]$result = $True
        } else {
            [System.Boolean]$result = $False
        }
    } else {
        throw "Got unexpected result from Get-TargetResource. No change is made."
    }

    return $result
}

# TODO: This function is meant to handle all types of PermissionSet that are based on PermissionSetBase 
function Get-SQLPermission
{
    [CmdletBinding()]
    [OutputType([string[]])]
    param (
        # Takes a PermissionSet which will be enumerated to return a string array
        [Parameter(Mandatory,ParameterSetName="ServerPermissionSet")]
        [Microsoft.SqlServer.Management.Smo.ServerPermissionSet]
        [ValidateNotNullOrEmpty()]
        $ServerPermissionSet
    )

    [string[]]$permission = @()
    
    if( $ServerPermissionSet ) {
        foreach( $Property in $($ServerPermissionSet | Get-Member -Type Property) ) {
            if( $ServerPermissionSet.$($Property.Name) ) {
                switch( $Property.Name ) {
                    "AlterAnyAvailabilityGroup" {
                        $permission += @("ALTER ANY AVAILABILITY GROUP")
                    }

                    "ViewServerState" {
                        $permission += @("VIEW SERVER STATE")
                    }

                    "AlterAnyEndPoint" {
                        $permission += @("ALTER ANY ENDPOINT")
                    }
                }
            }
        }
    }
    
    return [string[]]$permission
}

function Get-SQLServerPermissionSet
{
    [CmdletBinding()]
    # TODO: Remove this because it could not load the module without SQLPS. Error: Multiple ambiguous overloads found for ".ctor" and the argument count: "1". Maybe make sure the SQLPS module is loaded in the .psd1 file as a dependency.
    #[OutputType([Microsoft.SqlServer.Management.Smo.ServerPermissionSet])]
    [OutputType([Object])] 
    param (
        # Takes an array of string which will be concatenated to a single ServerPermissionSet
        [Parameter(Mandatory,ParameterSetName="Permission")]
        [System.String[]]
        [ValidateNotNullOrEmpty()]
        $Permission,
        
        # Takes an array of ServerPermissionSet which will be concatenated to a single ServerPermissionSet
        [Parameter(Mandatory,ParameterSetName="ServerPermissionSet")]
        [Microsoft.SqlServer.Management.Smo.ServerPermissionSet[]]
        [ValidateNotNullOrEmpty()]
        $PermissionSet
    )

    if( $Permission ) {
        [Microsoft.SqlServer.Management.Smo.ServerPermissionSet]$permissionSet = New-Object -TypeName Microsoft.SqlServer.Management.Smo.ServerPermissionSet
        
        switch( $Permission ) {
            "ALTER ANY AVAILABILITY GROUP" {
                $permissionSet.AlterAnyAvailabilityGroup = $True
            }

            "VIEW SERVER STATE" {
                $permissionSet.ViewServerState = $True
            }

            "ALTER ANY ENDPOINT" {
                $permissionSet.AlterAnyEndPoint = $True
            }
        }
    } else {
        $permissionSet = Merge-SQLPermissionSet -Object $PermissionSet 
    }
    
    return $permissionSet
}

function Merge-SQLPermissionSet {
    param (
        [Parameter(Mandatory)]
        [Microsoft.SqlServer.Management.Smo.PermissionSetBase[]]
        [ValidateNotNullOrEmpty()]
        $Object
    )
 
    $baseObject = New-Object -TypeName ($Object[0].GetType())

    foreach ( $currentObject in $Object ) {
        foreach( $Property in $($currentObject | Get-Member -Type Property) ) {
            if( $currentObject.$($Property.Name) ) {
                $baseObject.$($Property.Name) = $currentObject.$($Property.Name)
            }
        }
    }

    return $baseObject
}

Export-ModuleMember -Function *-TargetResource

