$ErrorActionPreference = "Stop"

$currentPath = Split-Path -Parent $MyInvocation.MyCommand.Path
import-module $currentPath\..\..\xSqlServerAlwaysOnUtil.psm1 -ErrorAction Stop

# Get-TargetResource should return details of the current state of the resource. Make sure you test it by calling Get-DscConfiguration after you apply the configuration and verifying 
# that output correctly reflects the current state of the machine. It’s important to test it separately, since any issues in this area won’t appear when calling Start-DscConfiguration.
#
# The Get-TargetResource function implements all Key properties defined in the resource schema file. If a DSC resource requires the Required and/or Write properties to successfully 
# fetch the state of the modeled entity, then Required or Write properties can also be in the Get-TargetResource input parameter list, and the values for these properties are propagated 
# to Get-TargetResource during the command execution.
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
        $NodeName
    )

    Write-Verbose "Getting state of AlwaysOn HA"

    try {
        $enabled = Get-SQLAlwaysOnState -NodeName $NodeName -InstanceName $InstanceName -Verbose:$VerbosePreference
        if( $null -ne $enabled ) { 
            if( $enabled ) {
                $Ensure = "Present"
            } else {
                $Ensure = "Absent"
            }
        } else {
            throw "Unexpected result, no column matching column name IsHadrEnabled."
        }
    } catch {
        throw "Could not access the SQL Server."
    }
  
    #The Get-TargetResource returns the status of the modeled entities in a hash table format. This hash table must contain all properties, including the Read properties (along with their values) 
    #that are defined in the resource schema. In the example above, the hash table returned by #Get-TargetResource contains Name, DisplayName and Ensure properties, along with their values.
    $returnValue = @{
        InstanceName = [System.String]$InstanceName
        NodeName = [System.String]$NodeName
        Ensure = [System.String]$Ensure
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
        $Ensure
    )

    $parameters = @{
        InstanceName = [System.String]$InstanceName
        NodeName = [System.String]$NodeName
    }
    
    $state = Get-TargetResource @parameters 
    if( $null -ne $state ) {
        if( $state.Ensure -ne $Ensure ) {
            $InstanceName = Get-SQLInstanceName -InstanceName $InstanceName
                        
            # More information regarding enable and disable AlwaysOn: https://msdn.microsoft.com/en-us/library/ff878259.aspx
            if( $Ensure -eq "Present") {
                if( ( $PSCmdlet.ShouldProcess( $InstanceName, "Enable AlwaysOn" ) ) ) {
                    Enable-SqlAlwaysOn -Path "SQLSERVER:\SQL\$NodeName\$InstanceName" -Force   # When Cmdlet restarts sql: https://msdn.microsoft.com/en-us/library/ff878259.aspx#WhenCmdletRestartsSQL
                }
            } else {
                if( ( $PSCmdlet.ShouldProcess( $InstanceName, "Disable AlwaysOn" ) ) ) {
                    Disable-SqlAlwaysOn -Path "SQLSERVER:\SQL\$NodeName\$InstanceName" -Force
                }
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
        $Ensure
    )

    $parameters = @{
        InstanceName = [System.String]$InstanceName
        NodeName = [System.String]$NodeName
    }
    
    Write-Verbose "Testing state on AlwaysOn"
    
    $state = Get-TargetResource @parameters 
    
    if( $null -ne $state ) {
        if( $state.Ensure -eq $Ensure ) {
            [System.Boolean]$result = $True
        } else {
            [System.Boolean]$result = $False
        }
    } else {
        throw "Got unexpected result from Get-TargetResource. Test-TargetResource will return unexpected value."
    }
         
    $result
}

# This function was created so that we could mock the function in the test. 
function Get-SQLAlwaysOnState
{
    [CmdletBinding()]
    [OutputType([bool])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $InstanceName,

        [parameter(Mandatory = $true)]
        [System.String]
        $NodeName 
    )

    $instance = Get-SQLPSInstance -NodeName $NodeName -InstanceName $InstanceName 
    $enabled = ($instance | Select-Object IsHadrEnabled).IsHadrEnabled # https://msdn.microsoft.com/en-us/library/ff878259.aspx

    return $enabled
}

Export-ModuleMember -Function *-TargetResource
