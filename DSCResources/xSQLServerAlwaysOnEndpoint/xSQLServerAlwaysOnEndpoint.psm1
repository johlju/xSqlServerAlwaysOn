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

    try {
        $endpoint = Get-SQLAlwaysOnEndpoint -Name $Name -NodeName $NodeName -InstanceName $InstanceName -Verbose:$VerbosePreference
        
        if( $null -ne $endpoint ) {
            Write-Verbose "Endpoint $Name already exist"

            $Ensure = "Present"
            $Port = $endpoint.Protocol.Tcp.ListenerPort
            $IpAddress = $endpoint.Protocol.Tcp.ListenerIPAddress.IPAddressToString
        } else {
            Write-Verbose "Endpoint $Name does not exist"

            $Ensure = "Absent"
        }
    } catch {
        throw "Unexpected result when trying to verify existance of endpoint $Name. Error: $($_.Exception.Message)"
    }

    $returnValue = @{
        InstanceName = [System.String]$InstanceName
        NodeName = [System.String]$NodeName
        Ensure = [System.String]$Ensure
        Name = [System.String]$Name
        Port = [System.UInt16]$Port
        IpAddress = [System.String]$IpAddress
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

        [ValidateSet("Present","Absent")] # If not present will return empty string ("")
        [System.String]
        $Ensure,

        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [System.UInt16]
        $Port = 5022, # Defaults to the port that was supposed to be default for the paramater Port in the New-SqlHADREndpoint cmdlet (but it's not)

        [System.String]
        $IpAddress = "0.0.0.0"
    )

    Write-Debug "Doing conversion of IP-address from string"
    [ipaddress]$IpAddress = $IpAddress #Throws an exception if conversion fails!
   
    $parameters = @{
        InstanceName = [System.String]$InstanceName
        NodeName = [System.String]$NodeName
        Name = [System.String]$Name
    }
    
    # TEST: New-SqlHADREndpoint : An endpoint of the requested type already exists.  Only one endpoint of this type is supported.  Use ALTER ENDPOINT or DROP the existing endpoint and execute the CREATE ENDPOINT statement.
    
    $endPointState = Get-TargetResource @parameters 
    if( $null -ne $endPointState ) {
        if( $Ensure -ne "" -and $endPointState.Ensure -ne $Ensure ) {
            if( $Ensure -eq "Present") {
                if( ( $PSCmdlet.ShouldProcess( $Name, "Create Endpoint" ) ) ) {
                    $InstanceName = Get-SQLInstanceName -InstanceName $InstanceName

                    $newEndPointParams = @{
                        Name = $Name
                        Path = "SQLSERVER:\SQL\$NodeName\$InstanceName"
                        Port = $Port
                        IpAddress = $IpAddress
                    }

                    New-SqlHADREndpoint @newEndPointParams -Verbose:$False | Out-Null   # Suppressing Verbose because it prints the entire T-SQL statement otherwise
                }
            } else {
                if( ( $PSCmdlet.ShouldProcess( $Name, "Remove Endpoint" ) ) ) {
                    $endpoint = Get-SQLAlwaysOnEndpoint -Name $Name -NodeName $NodeName -InstanceName $InstanceName -Verbose:$VerbosePreference
                    if( $null -ne $endpoint ) {
                        $endpoint.Drop()
                    } else {
                        throw "Endpoint $Name does not exist. Could not remove endpoint."
                    }
                }
            }
        } else {
            if( $Ensure -ne "" ) { Write-Verbose "State is already $Ensure" }
            
            if( $endPointState.Ensure -eq "Present") {
                if( $endPointState.Port -ne $Port -or $endPointState.IpAddress -ne $IpAddress ) {
                    Write-Verbose "Endpoint differ in configuration."
                    if( ( $PSCmdlet.ShouldProcess( $Name, "Changing Endpoint configuration" ) ) ) {
                        $InstanceName = Get-SQLInstanceName -InstanceName $InstanceName
                        
                        $setEndPointParams = @{
                            Path = "SQLSERVER:\SQL\$NodeName\$InstanceName\Endpoints\$Name"
                            Port = $Port
                            IpAddress = $IpAddress
                        }

                        Set-SqlHADREndpoint @setEndPointParams -Verbose:$False | Out-Null # Suppressing Verbose because it prints the entire T-SQL statement otherwise
                    }
                } else {
                    Write-Verbose "Endpoint configuration is already correct."
                }
            } else {
                throw "Trying to make a change to an endpoint that does not exist."
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

        [ValidateSet("Present","Absent")] # If not present will return empty string ("")
        [System.String]
        $Ensure,

        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [System.UInt16]
        $Port = 5022,

        [System.String]
        $IpAddress = "0.0.0.0"
    )

    Write-Debug "Doing conversion of IP-address from string"
    [ipaddress]$IpAddress = $IpAddress #Throws an exception if conversion fails!
    
    $parameters = @{
        InstanceName = [System.String]$InstanceName
        NodeName = [System.String]$NodeName
        Name = [System.String]$Name
    }
    
    Write-Verbose "Testing state of endpoint $Name"
    
    $endPointState = Get-TargetResource @parameters 
    if( $null -ne $endPointState ) {
        if( ( $Ensure -eq "" -or ( $Ensure -ne "" -and $endPointState.Ensure -eq $Ensure) ) -and $endPointState.Port -eq $Port -and $endPointState.IpAddress -eq $IpAddress ) {
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

