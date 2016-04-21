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
        [ValidateLength(1,15)]
        [System.String]
        $Name,

        [parameter(Mandatory = $true)]
        [System.String]
        $AvailabilityGroup
    )

    try {
        $listner = Get-SQLAlwaysOnAvailabilityGroupListner -Name $Name -AvailabilityGroup $AvailabilityGroup -NodeName $NodeName -InstanceName $InstanceName
        
        if( $null -ne $listner ) {
            Write-Verbose "Listner $Name already exist"

            $ensure = "Present"
            
            $port = [uint16]( $listner | Select-Object -ExpandProperty PortNumber )

            $presentIpAddress = $listner.AvailabilityGroupListenerIPAddresses

            $dhcp = [bool]( $presentIpAddress | Select-Object -first 1 IsDHCP )

            $ipAddress = @()
            foreach( $currentIpAddress in $presentIpAddress ) {
                $ipAddress += "$($currentIpAddress.IPAddress)/$($currentIpAddress.SubnetMask)"
            } 
        } else {
            Write-Verbose "Listner $Name does not exist"

            $ensure = "Absent"
            $port = 0
            $dhcp = $false
            $ipAddress = $null
        }
    } catch {
        throw "Unexpected result when trying to verify existance of listner $Name. Error: $($_.Exception.Message)"
    }

    $returnValue = @{
        InstanceName = [System.String]$InstanceName
        NodeName = [System.String]$NodeName
        Name = [System.String]$Name
        Ensure = [System.String]$ensure
        AvailabilityGroup = [System.String]$AvailabilityGroup
        IpAddress = [System.String[]]$ipAddress
        Port = [System.UInt16]$port
        DHCP = [System.Boolean]$dhcp
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
        [ValidateLength(1,15)]
        [System.String]
        $Name,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure,

        [parameter(Mandatory = $true)]
        [System.String]
        $AvailabilityGroup,

        [System.String[]]
        $IpAddress,

        [System.UInt16]
        $Port,

        [System.Boolean]
        $DHCP
    )
   
    $parameters = @{
        InstanceName = [System.String]$InstanceName
        NodeName = [System.String]$NodeName
        Name = [System.String]$Name
        AvailabilityGroup = [System.String]$AvailabilityGroup
    }
    
    $listnerState = Get-TargetResource @parameters 
    if( $null -ne $listnerState ) {
        if( $Ensure -ne "" -and $listnerState.Ensure -ne $Ensure ) {
            $InstanceName = Get-SQLInstanceName -InstanceName $InstanceName
            
            if( $Ensure -eq "Present") {
                if( ( $PSCmdlet.ShouldProcess( $Name, "Create listner on $AvailabilityGroup" ) ) ) {
                    $newListnerParams = @{
                        Name = $Name
                        Path = "SQLSERVER:\SQL\$NodeName\$InstanceName\AvailabilityGroups\$AvailabilityGroup"
                    }

                    if( $Port ) {
                        Write-Verbose "Listner port set to $Port"
                        $newListnerParams += @{
                            Port = $Port
                        }
                    }

                    if( $DHCP -and $IpAddress.Count -gt 0 ) {
                        Write-Verbose "Listner set to DHCP with subnet $IpAddress"
                        $newListnerParams += @{
                            DhcpSubnet = [string]$IpAddress
                        }
                    } elseif ( -not $DHCP -and $IpAddress.Count -gt 0 ) {
                        Write-Verbose "Listner set to static IP-address(es); $($IpAddress -join ', ')"
                        $newListnerParams += @{
                            StaticIp = $IpAddress
                        }
                    } else {
                        Write-Verbose "Listner using DHCP with server default subnet"
                    }
                                        
                    New-SqlAvailabilityGroupListener @newListnerParams -Verbose:$False | Out-Null   # Suppressing Verbose because it prints the entire T-SQL statement otherwise
                }
            } else {
                if( ( $PSCmdlet.ShouldProcess( $Name, "Remove listner from $AvailabilityGroup" ) ) ) {
                    Remove-Item "SQLSERVER:\SQL\$NodeName\$InstanceName\AvailabilityGroups\$AvailabilityGroup\AvailabilityGroupListeners\$Name"
                }
            }
        } else {
            if( $Ensure -ne "" ) { Write-Verbose "State is already $Ensure" }
            
            if( $listnerState.Ensure -eq "Present") {
                if( -not $DHCP -and $listnerState.IpAddress.Count -lt $IpAddress.Count ) { # Only able to add a new IP-address, not change existing ones.
                    Write-Verbose "Found at least one new IP-address."
                    $ipAddressEqual = $False
                } else {
                    # No new IP-address
                    if( $null -eq $IpAddress -or -not ( Compare-Object -ReferenceObject $IpAddress -DifferenceObject $listnerState.IpAddress ) ) { 
                       $ipAddressEqual = $True
                    } else {
                        throw "IP-address configuration mismatch. Expecting $($IpAddress -join ', ') found $($listnerState.IpAddress -join ', '). Resource does not support changing IP-address. Listner needs to be removed and then created again."
                    }
                }
                
                if( $listnerState.Port -ne $Port -or -not $ipAddressEqual ) {
                    Write-Verbose "Listner differ in configuration."

                    if( $listnerState.Port -ne $Port ) {
                        if( ( $PSCmdlet.ShouldProcess( $Name, "Changing port configuration" ) ) ) {
                            $InstanceName = Get-SQLInstanceName -InstanceName $InstanceName
                            
                            $setListnerParams = @{
                                Path = "SQLSERVER:\SQL\$NodeName\$InstanceName\AvailabilityGroups\$AvailabilityGroup\AvailabilityGroupListeners\$Name"
                                Port = $Port
                            }

                            Set-SqlAvailabilityGroupListener @setListnerParams -Verbose:$False | Out-Null # Suppressing Verbose because it prints the entire T-SQL statement otherwise
                        }
                    }

                    if( -not $ipAddressEqual ) {
                        if( ( $PSCmdlet.ShouldProcess( $Name, "Adding IP-address(es)" ) ) ) {
                            $InstanceName = Get-SQLInstanceName -InstanceName $InstanceName
                            
                            $newIpAddress = @()
                            
                            foreach( $currentIpAddress in $IpAddress ) {
                                if( -not $listnerState.IpAddress -contains $currentIpAddress ) {
                                    $newIpAddress += $currentIpAddress
                                }
                            }
                            
                            $setListnerParams = @{
                                Path = "SQLSERVER:\SQL\$NodeName\$InstanceName\AvailabilityGroups\$AvailabilityGroup\AvailabilityGroupListeners\$Name"
                                StaticIp = $newIpAddress
                            }

                            Add-SqlAvailabilityGroupListenerStaticIp @setListnerParams -Verbose:$False | Out-Null # Suppressing Verbose because it prints the entire T-SQL statement otherwise
                        }
                    }

                } else {
                    Write-Verbose "Listner configuration is already correct."
                }
            } else {
                throw "Trying to make a change to an listner that does not exist."
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
        [ValidateLength(1,15)]
        [System.String]
        $Name,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure,

        [parameter(Mandatory = $true)]
        [System.String]
        $AvailabilityGroup,

        [System.String[]]
        $IpAddress,

        [System.UInt16]
        $Port,

        [System.Boolean]
        $DHCP
    )

    $parameters = @{
        InstanceName = [System.String]$InstanceName
        NodeName = [System.String]$NodeName
        Name = [System.String]$Name
        AvailabilityGroup = [System.String]$AvailabilityGroup
    }
    
    Write-Verbose "Testing state of listner $Name"
    
    $listnerState = Get-TargetResource @parameters 
    if( $null -ne $listnerState ) {
        if( $null -eq $IpAddress -or ($null -ne $listnerState.IpAddress -and -not ( Compare-Object -ReferenceObject $IpAddress -DifferenceObject $listnerState.IpAddress ) ) ) { 
            $ipAddressEqual = $True
        } else {
            $ipAddressEqual = $False
        }
        
        if( ( $Ensure -eq "" -or ( $Ensure -ne "" -and $listnerState.Ensure -eq $Ensure) ) -and ($Port -eq "" -or $listnerState.Port -eq $Port) -and $ipAddressEqual ) {
            [System.Boolean]$result = $True
        } else {
            [System.Boolean]$result = $False
        }
    } else {
        throw "Got unexpected result from Get-TargetResource. No change is made."
    }

    return $result
}

function Get-SQLAlwaysOnAvailabilityGroupListner
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
        $AvailabilityGroup,

        [parameter(Mandatory = $true)]
        [System.String]
        $InstanceName,

        [parameter(Mandatory = $true)]
        [System.String]
        $NodeName 
    )

    $instance = Get-SQLPSInstance -InstanceName $InstanceName -NodeName $NodeName
    $Path = "$($instance.PSPath)\AvailabilityGroups\$AvailabilityGroup\AvailabilityGroupListeners"

    Write-Debug "Connecting to $Path as $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)"
    
    [string[]]$presentListner = Get-ChildItem $Path
    if( $presentListner.Count -ne 0 -and $presentListner.Contains("[$Name]") ) {
        Write-Debug "Connecting to availability group $Name as $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)"
        $listner = Get-Item "$Path\$Name"
    } else {
        $listner = $null
    }    

    return $listner
}

Export-ModuleMember -Function *-TargetResource

