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

    Write-Verbose "Getting state of endpoint $Name"
    
    try {
        $endpoint = Get-SQLAlwaysOnEndpoint -Name $Name -NodeName $NodeName -InstanceName $InstanceName -Verbose:$VerbosePreference
        
        if( $null -ne $endpoint ) {
            $State = $endpoint.EndpointState
        } else {
            throw "Endpoint $Name does not exist"
        }
    } catch {
        throw "Unexpected result when trying to verify existance of endpoint $Name. Error: $($_.Exception.Message)"
    }

    $returnValue = @{
        InstanceName = [System.String]$InstanceName
        NodeName = [System.String]$NodeName
        Name = [System.String]$Name
        State = [System.String]$State
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

        [ValidateSet("Started","Stopped","Disabled")]
        [System.String]
        $State
    )
  
    $parameters = @{
        InstanceName = [System.String]$InstanceName
        NodeName = [System.String]$NodeName
        Name = [System.String]$Name
    }
    
    $endPointState = Get-TargetResource @parameters 
    if( $null -ne $endPointState ) {
        if( $endPointState.State -ne $State ) {
            if( ( $PSCmdlet.ShouldProcess( $Name, "Changing state of Endpoint" ) ) ) {
                $endpoint = Get-SQLAlwaysOnEndpoint -Name $Name -NodeName $NodeName -InstanceName $InstanceName -Verbose:$VerbosePreference
                $InstanceName = Get-SQLInstanceName -InstanceName $InstanceName
    
                $setEndPointParams = @{
                    Path = "SQLSERVER:\SQL\$NodeName\$InstanceName\Endpoints\$Name"
                    Port = $endpoint.Protocol.Tcp.ListenerPort
                    IpAddress = $endpoint.Protocol.Tcp.ListenerIPAddress.IPAddressToString
                    State = $State
                }
                
                Set-SqlHADREndpoint @setEndPointParams -Verbose:$False | Out-Null # Suppressing Verbose because it prints the entire T-SQL statement otherwise
            }
        } else {
            Write-Verbose "Endpoint configuration is already correct."
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

        [ValidateSet("Started","Stopped","Disabled")]
        [System.String]
        $State
    )

    $parameters = @{
        InstanceName = [System.String]$InstanceName
        NodeName = [System.String]$NodeName
        Name = [System.String]$Name
    }

    Write-Verbose "Testing state $State on endpoint $Name"
    
    $endPointState = Get-TargetResource @parameters 
    if( $null -ne $endPointState ) {
        if( $endPointState.State -eq $State ) {
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

