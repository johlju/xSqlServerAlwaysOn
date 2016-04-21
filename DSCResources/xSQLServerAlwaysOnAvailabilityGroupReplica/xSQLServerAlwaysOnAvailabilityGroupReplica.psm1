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
        $PrimaryReplicaInstanceName,

        [parameter(Mandatory = $true)]
        [System.String]
        $PrimaryReplicaNodeName,

        [parameter(Mandatory = $true)]
        [System.String]
        $AvailabilityGroup,

        [System.UInt16]
        $Timeout = 300
    )

    Write-Verbose "Getting state of availability group replica $NodeName\$InstanceName"

    try {
        $params = @{
            AvailabilityGroup = $AvailabilityGroup
            NodeName = $NodeName
            InstanceName = $InstanceName
            PrimaryReplicaNodeName = $PrimaryReplicaNodeName
            PrimaryReplicaInstanceName = $PrimaryReplicaInstanceName
            Timeout = $Timeout
        }
        
        $replica = Get-SQLAlwaysOnAvailabilityGroupReplica @params
        
        if( $null -ne $replica ) {
            Write-Verbose "Availability Group replica $NodeName\$InstanceName already exist"

            $ensure = "Present"
            $availabilityMode = $replica.AvailabilityMode
            $failoverMode = $replica.FailoverMode
        } else {
            Write-Verbose "Availability Group replica $NodeName\$InstanceName does not exist"

            $ensure = "Absent"
            $availabilityMode = ""
            $failoverMode = ""
        }
    } catch {
        throw "Unexpected result when trying to verify existance of Availability Group replica $NodeName\$InstanceName. Error: $($_.Exception.Message)"
    }

    $returnValue = @{
        InstanceName = [System.String]$InstanceName
        NodeName = [System.String]$NodeName
        PrimaryReplicaInstanceName = [System.String]$PrimaryReplicaInstanceName
        PrimaryReplicaNodeName = [System.String]$PrimaryReplicaNodeName
        AvailabilityGroup = [System.String]$AvailabilityGroup
        Ensure = [System.String]$ensure
        AvailabilityMode = [System.String]$availabilityMode
        FailoverMode = [System.String]$failoverMode
        Timeout = [System.UInt16]$Timeout
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
        $PrimaryReplicaInstanceName,

        [parameter(Mandatory = $true)]
        [System.String]
        $PrimaryReplicaNodeName,

        [parameter(Mandatory = $true)]
        [System.String]
        $AvailabilityGroup,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure,

        [ValidateSet("SynchronousCommit","AsynchronousCommit")]
        [System.String]
        $AvailabilityMode = "SynchronousCommit",

        [ValidateSet("Automatic","Manual")]
        [System.String]
        $FailoverMode = "Automatic",

        [System.UInt16]
        $Timeout = 300
    )

    $parameters = @{
        InstanceName = [System.String]$InstanceName
        NodeName = [System.String]$NodeName
        AvailabilityGroup = [System.String]$AvailabilityGroup
        PrimaryReplicaInstanceName = [System.String]$PrimaryReplicaInstanceName
        PrimaryReplicaNodeName = [System.String]$PrimaryReplicaNodeName
        Timeout = [System.UInt16]$Timeout
    }
    
    $replicaState = Get-TargetResource @parameters 
    if( $null -ne $replicaState ) {
        $primaryReplicaHostname  = $PrimaryReplicaNodeName -split '.', 2, "simplematch" | Select-Object -First 1
        $PrimaryReplicaInstanceName = Get-SQLInstanceName -InstanceName $PrimaryReplicaInstanceName
        
        $availabilityGroupObject = Get-Item "SQLSERVER:\SQL\$PrimaryReplicaNodeName\$PrimaryReplicaInstanceName\AvailabilityGroups\$AvailabilityGroup"
        if( $availabilityGroupObject.PrimaryReplicaServerName -eq $primaryReplicaHostname ) {
            $secondaryReplicaHostname  = $NodeName -split '.', 2, "simplematch" | Select-Object -First 1

            $InstanceName = Get-SQLInstanceName -InstanceName $InstanceName
            if( $InstanceName -eq "DEFAULT" ) {
                $secondaryReplicaInstanceName = ""
                $secondaryReplicaDisplayName = $secondaryReplicaHostname
            } else {
                $secondaryReplicaInstanceName = "\$InstanceName"
                $secondaryReplicaDisplayName = "$secondaryReplicaHostname%5C$InstanceName"
            }

            if( $Ensure -ne "" -and $replicaState.Ensure -ne $Ensure ) {
                if( $Ensure -eq "Present") {
                    if( ( $PSCmdlet.ShouldProcess( "$secondaryReplicaHostname$secondaryReplicaInstanceName", "Create Availabilty Group replica" ) ) ) {
                        $PrimaryReplicaInstanceName = Get-SQLInstanceName -InstanceName $PrimaryReplicaInstanceName
                        
                        $newReplicaParams = @{
                            Path = "SQLSERVER:\SQL\$PrimaryReplicaNodeName\$PrimaryReplicaInstanceName\AvailabilityGroups\$AvailabilityGroup"
                            Name = "$secondaryReplicaHostname$secondaryReplicaInstanceName"
                            AvailabilityMode = $AvailabilityMode
                            FailoverMode = $FailoverMode
                            EndpointUrl = "TCP://$($NodeName):5022"
                        }
                        
                        New-SqlAvailabilityReplica @newReplicaParams -Verbose:$False | Out-Null # Suppressing Verbose because it prints the entire T-SQL statement otherwise
                        Join-SqlAvailabilityGroup -Path "SQLSERVER:\SQL\$NodeName\$InstanceName" -Name $AvailabilityGroup -Verbose:$False | Out-Null
                    }
                } else {
                    if( ( $PSCmdlet.ShouldProcess( "$secondaryReplicaHostname$secondaryReplicaInstanceName", "Remove Availability Group replica" ) ) ) {
                        Remove-SqlAvailabilityReplica -Path "SQLSERVER:\SQL\$PrimaryReplicaNodeName\$PrimaryReplicaInstanceName\AvailabilityGroups\$AvailabilityGroup\AvailabilityReplicas\$secondaryReplicaDisplayName" -Verbose:$False
                    }
                }
            } else {
                if( $Ensure -ne "" ) { Write-Verbose "State is already $Ensure" }
                
                if( $replicaState.Ensure -eq "Present") {
                    if( $replicaState.AvailabilityMode -ne $AvailabilityMode -or $replicaState.FailoverMode -ne $FailoverMode ) {
                        Write-Verbose "Availability Group replica differ in configuration."

                        if( ( $PSCmdlet.ShouldProcess( $Name, "Changing Availability Group replica configuration" ) ) ) {
                            $setReplicaParams = @{
                                Path = "SQLSERVER:\SQL\$PrimaryReplicaNodeName\$PrimaryReplicaInstanceName\AvailabilityGroups\$AvailabilityGroup\AvailabilityReplicas\$secondaryReplicaDisplayName"
                            }

                            if( $replicaState.AvailabilityMode -ne $AvailabilityMode ) {
                                $setReplicaParams += @{ AvailabilityMode = $AvailabilityMode }
                            } 

                            if( $replicaState.FailoverMode -ne $FailoverMode ) {
                                $setReplicaParams += @{ FailoverMode = $FailoverMode }
                            }
                            
                            Set-SqlAvailabilityReplica @setReplicaParams -Verbose:$False | Out-Null
                        }
                    } else {
                        Write-Verbose "Availability Group replica configuration is already correct."
                    }
                } else {
                    throw "Trying to make a change to an Availabilty Group replica that does not exist."
                }
            }
        } else {
            throw "$PrimaryReplicaNodeName is not Primary Replica. Cannot remove availability group replica from a secondary replica."
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
        $PrimaryReplicaInstanceName,

        [parameter(Mandatory = $true)]
        [System.String]
        $PrimaryReplicaNodeName,

        [parameter(Mandatory = $true)]
        [System.String]
        $AvailabilityGroup,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure,

        [ValidateSet("SynchronousCommit","AsynchronousCommit")]
        [System.String]
        $AvailabilityMode,

        [ValidateSet("Automatic","Manual")]
        [System.String]
        $FailoverMode,

        [System.UInt16]
        $Timeout = 300
    )

    $parameters = @{
        InstanceName = [System.String]$InstanceName
        NodeName = [System.String]$NodeName
        AvailabilityGroup = [System.String]$AvailabilityGroup
        PrimaryReplicaInstanceName = [System.String]$PrimaryReplicaInstanceName
        PrimaryReplicaNodeName = [System.String]$PrimaryReplicaNodeName
        Timeout = [System.UInt16]$Timeout
    }
    
    Write-Verbose "Testing state of Availability Group replica $NodeName\$InstanceName"
    
    $replicaState = Get-TargetResource @parameters 
    if( $null -ne $replicaState ) {
        if( ( $Ensure -eq "" -or ( $Ensure -ne "" -and $replicaState.Ensure -eq $Ensure) ) `
                -and $replicaState.AvailabilityMode -eq $AvailabilityMode `
                -and $replicaState.FailoverMode -eq $FailoverMode ) {
            [System.Boolean]$result = $True
        } else {
            [System.Boolean]$result = $False
        }
    } else {
        throw "Got unexpected result from Get-TargetResource. No change is made."
    }

    return $result
}

function Get-SQLAlwaysOnAvailabilityGroupReplica
{
    [CmdletBinding()]
    [OutputType()]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $AvailabilityGroup,

        [parameter(Mandatory = $true)]
        [System.String]
        $InstanceName,

        [parameter(Mandatory = $true)]
        [System.String]
        $NodeName, 

        [parameter(Mandatory = $true)]
        [System.String]
        $PrimaryReplicaInstanceName,

        [parameter(Mandatory = $true)]
        [System.String]
        $PrimaryReplicaNodeName, 

        [parameter(Mandatory = $true)]
        [System.UInt16]
        $Timeout
    )

    Write-Verbose "Waiting for Primary Replica $PrimaryReplicaNodeName\$PrimaryReplicaInstanceName and availability group $AvailabilityGroup to go online. Timeout will occur in $Timeout seconds."
    $job = Start-Job -ScriptBlock {
        param
        (
            [parameter(Mandatory=$true)]
            [string]$NodeName,
            
            [parameter(Mandatory=$true)]
            [string]$InstanceName,

            [parameter(Mandatory=$true)]
            [string]$AvailabilityGroup
        )

        while ( $true ) {
            try {
                get-item "SQLSERVER:\SQL\$NodeName\$InstanceName\AvailabilityGroups\$AvailabilityGroup" -ErrorAction Stop
                return
            }
            catch {
                Start-Sleep -Seconds 3
            }
        }        
    } -initializationScript {
        Import-Module SQLPS -Verbose:$False -DisableNameChecking
    } -ArgumentList $PrimaryReplicaNodeName, (Get-SQLInstanceName -InstanceName $PrimaryReplicaInstanceName), $AvailabilityGroup

    $job | Wait-Job -Timeout $Timeout | Out-Null
    $availabilityGroupObject = Receive-Job -Job $job
    $job | Remove-Job -Verbose:$False -Force 

    if( $null -ne $availabilityGroupObject ) { 
        Write-Verbose "Primary Replica is online."
        $primaryReplicaHostname = $PrimaryReplicaNodeName -split '.', 2, "simplematch" | Select-Object -First 1

        if( $availabilityGroupObject.PrimaryReplicaServerName -eq $primaryReplicaHostname ) {
            $primaryReplicaInstance = Get-SQLPSInstance -InstanceName $PrimaryReplicaInstanceName -NodeName $PrimaryReplicaNodeName

            $Path = "$($primaryReplicaInstance.PSPath)\AvailabilityGroups\$AvailabilityGroup\AvailabilityReplicas"
            Write-Debug "Connecting to $Path as $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)"
            $presentReplica = Get-ChildItem $Path

            $hostname  = $NodeName -split '.', 2, "simplematch" | Select-Object -First 1

            $secondaryReplicaInstanceName = Get-SQLInstanceName -InstanceName $InstanceName
            if( $secondaryReplicaInstanceName -eq "DEFAULT") {
                $secondaryReplica = $hostname 
            } else {
                $secondaryReplica = "$hostname%5C$secondaryReplicaInstanceName" 
            }

            if( ($presentReplica | Where-Object DisplayName -eq $secondaryReplica).Count -ne 0 ) {
                Write-Debug "Connecting to replica $Path\$secondaryReplica as $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)"
                $replica = Get-Item "$Path\$secondaryReplica"
            } else {
                $replica = $null
            }    
        } else {
            Throw "$PrimaryReplicaNodeName\$PrimaryReplicaInstanceName is not the primary replica. Seems that $($availabilityGroupObject.PrimaryReplicaServerName) is the primary replica."
        }
    } else {
        Throw "$PrimaryReplicaNodeName\$PrimaryReplicaInstanceName and $AvailabilityGroup did not go online within $Timeout seconds."
   }

    return $replica
}

Export-ModuleMember -Function *-TargetResource
