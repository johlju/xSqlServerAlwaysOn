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
        $Name
    )

    Write-Verbose "Getting state of availability group $Name"

    try {
        $group = Get-SQLAlwaysOnAvailabilityGroup -Name $Name -NodeName $NodeName -InstanceName $InstanceName -Verbose:$VerbosePreference
        
        if( $null -ne $group ) {
            Write-Verbose "Availability Group $Name already exist"

            $Ensure = "Present"
            
            $primaryReplica = $group.AvailabilityReplicas | Where-Object Role -eq Primary
            $availabilityMode = $primaryReplica.AvailabilityMode
            $failoverMode = $primaryReplica.FailoverMode
            $healthCheckTimeout = $group.HealthCheckTimeout
            $failureConditionLevel = $group.FailureConditionLevel
            
        } else {
            Write-Verbose "Availability Group $Name does not exist"

            $Ensure = "Absent"
            $availabilityMode = ""
            $failoverMode = ""
        }
    } catch {
        throw "Unexpected result when trying to verify existance of Availability Group $Name. Error: $($_.Exception.Message)"
    }

    $returnValue = @{
        InstanceName = [System.String]$InstanceName
        NodeName = [System.String]$NodeName
        Name = [System.String]$Name
        Ensure = [System.String]$ensure
        AvailabilityMode = [System.String]$availabilityMode
        FailoverMode = [System.String]$failoverMode
        HealthCheckTimeout = [System.UInt32]$healthCheckTimeout
        FailureConditionLevel = [System.String]$failureConditionLevel
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

        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure,

        [ValidateSet("SynchronousCommit","AsynchronousCommit")]
        [System.String]
        $AvailabilityMode = "SynchronousCommit",

        [ValidateSet("Automatic","Manual")]
        [System.String]
        $FailoverMode = "Automatic",

        [System.UInt32]
        $HealthCheckTimeout,

        [ValidateSet("OnServerDown","OnServerUnresponsive","OnCriticalServerErrors","OnModerateServerErrors","OnAnyQualifiedFailureCondition")]
        [System.String]
        $FailureConditionLevel
    )

    $parameters = @{
        InstanceName = [System.String]$InstanceName
        NodeName = [System.String]$NodeName
        Name = [System.String]$Name
    }
    
    $groupState = Get-TargetResource @parameters 
    if( $null -ne $groupState ) {
        $InstanceName = Get-SQLInstanceName -InstanceName $InstanceName
        $hostname  = $NodeName -split '.', 2, "simplematch" | Select-Object -First 1
                
        if( $Ensure -ne "" -and $groupState.Ensure -ne $Ensure ) {
            if( $Ensure -eq "Present") {
                if( ( $PSCmdlet.ShouldProcess( $Name, "Create Availabilty Group" ) ) ) {
                    $instance = Get-SQLPSInstance -NodeName $NodeName -InstanceName $InstanceName
                    $version = $instance.Version.Major

                    if( $InstanceName -eq "DEFAULT" ) {
                        $replicaInstanceName = ""
                    } else {
                        $replicaInstanceName = "\$InstanceName"
                    }
                    
                    $newReplicaParams = @{
                        Name = "$hostname$replicaInstanceName"
                        AvailabilityMode = $AvailabilityMode
                        FailoverMode = $FailoverMode
                        EndpointUrl = "TCP://$($NodeName):5022"
                        Version = $version
                    }
                    
                    $primaryReplica = New-SqlAvailabilityReplica @newReplicaParams -AsTemplate 

                    $newAvailabilityGroupParams = @{
                        Name = $Name
                        AvailabilityReplica = $primaryReplica
                        Path = "SQLSERVER:\SQL\$NodeName\$InstanceName"
                    }

                    if( $HealthCheckTimeout -ne "" ) {
                        $newAvailabilityGroupParams += @{ HealthCheckTimeout = $HealthCheckTimeout }
                    }                    

                    if( $FailureConditionLevel -ne "" ) {
                        $newAvailabilityGroupParams += @{ FailureConditionLevel = $FailureConditionLevel }
                    }                    
                    
                    New-SqlAvailabilityGroup @newAvailabilityGroupParams -Verbose:$False | Out-Null   # Suppressing Verbose because it prints the entire T-SQL statement otherwise
                }
            } else {
                if( ( $PSCmdlet.ShouldProcess( $Name, "Remove Availability Group" ) ) ) {
                    # On a secondary replica, DROP AVAILABILITY GROUP should only be used only for emergency purposes. 
                    # https://msdn.microsoft.com/en-us/library/ff878113.aspx
                    $availabilityGroup = Get-Item "SQLSERVER:\SQL\$NodeName\$InstanceName\AvailabilityGroups\$Name"
                    if( $availabilityGroup.PrimaryReplicaServerName -eq $hostname ) {
                        Remove-SqlAvailabilityGroup -Path "SQLSERVER:\SQL\$NodeName\$InstanceName\AvailabilityGroups\$Name" -Verbose:$False    
                    } else {
                        throw "$NodeName is not Primary Replica. Cannot remove availability group from a secondary replica."
                    }
                }
            }
        } else {
            if( $Ensure -ne "" ) { Write-Verbose "State is already $Ensure" }
            
            if( $groupState.Ensure -eq "Present") {
                if( $groupState.HealthCheckTimeout -ne $HealthCheckTimeout -or $groupState.FailureConditionLevel -ne $FailureConditionLevel ) {
                    Write-Verbose "Availability Group differ in configuration."

                    if( ( $PSCmdlet.ShouldProcess( $Name, "Changing Availability Group configuration" ) ) ) {
                        $setAvailabilityGroupParams = @{
                            Path = "SQLSERVER:\SQL\$NodeName\$InstanceName\AvailabilityGroups\$Name"
                        }

                        if( $groupState.HealthCheckTimeout -ne $HealthCheckTimeout ) {
                            $setAvailabilityGroupParams += @{ HealthCheckTimeout = $HealthCheckTimeout }
                        } 

                        if( $groupState.FailureConditionLevel -ne $FailureConditionLevel ) {
                            $setAvailabilityGroupParams += @{ FailureConditionLevel = $FailureConditionLevel }
                        }

                        $availabilityGroup = Get-Item "SQLSERVER:\SQL\$NodeName\$InstanceName\AvailabilityGroups\$Name"
                        if( $availabilityGroup.PrimaryReplicaServerName -eq $hostname ) {
                            Set-SqlAvailabilityGroup @setAvailabilityGroupParams -Verbose:$False
                        } else {
                            throw "$NodeName is not Primary Replica. Cannot remove availability group from a secondary replica."
                        }
                    }
                } else {
                    Write-Verbose "Availability Group configuration is already correct."
                }
            } else {
                throw "Trying to make a change to an Availabilty Group that does not exist."
            }
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

        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure,

        [ValidateSet("SynchronousCommit","AsynchronousCommit")]
        [System.String]
        $AvailabilityMode = "SynchronousCommit",

        [ValidateSet("Automatic","Manual")]
        [System.String]
        $FailoverMode = "Automatic",

        [System.UInt32]
        $HealthCheckTimeout,

        [ValidateSet("OnServerDown","OnServerUnresponsive","OnCriticalServerErrors","OnModerateServerErrors","OnAnyQualifiedFailureCondition")]
        [System.String]
        $FailureConditionLevel
    )

    $parameters = @{
        InstanceName = [System.String]$InstanceName
        NodeName = [System.String]$NodeName
        Name = [System.String]$Name
    }
    
    Write-Verbose "Testing state of Availability Group $Name"
    
    $groupState = Get-TargetResource @parameters 
    if( $null -ne $groupState ) {
        if( ( $Ensure -eq "" -or ( $Ensure -ne "" -and $groupState.Ensure -eq $Ensure) ) `
                -and $groupState.AvailabilityMode -eq $AvailabilityMode `
                -and $groupState.FailoverMode -eq $FailoverMode ) {

            if( ( $HealthCheckTimeout -ne "" -and $groupState.HealthCheckTimeout -ne $HealthCheckTimeout ) `
                    -or ( $FailureConditionLevel -ne "" -and $groupState.FailureConditionLevel -ne $FailureConditionLevel ) ) {

                [System.Boolean]$result = $False
            } else {
                [System.Boolean]$result = $True
            }                    
        } else {
            [System.Boolean]$result = $False
        }
    } else {
        throw "Got unexpected result from Get-TargetResource. No change is made."
    }

    return $result
}

function Get-SQLAlwaysOnAvailabilityGroup
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
    $Path = "$($instance.PSPath)\AvailabilityGroups"

    Write-Debug "Connecting to $Path as $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)"
    
    [string[]]$presentAvailabilityGroup = Get-ChildItem $Path
    if( $presentAvailabilityGroup.Count -ne 0 -and $presentAvailabilityGroup.Contains("[$Name]") ) {
        Write-Debug "Connecting to availability group $Name as $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)"
        $group = Get-Item "$Path\$Name"
    } else {
        $group = $null
    }    

    return $group
}

Export-ModuleMember -Function *-TargetResource

