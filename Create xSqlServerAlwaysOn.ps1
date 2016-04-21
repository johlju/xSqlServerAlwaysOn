############
# NOTE!!
############
# Use Update-xDscResource with CAUTION. 
# - If there are default parameters, they will be removed from all the functions (*-TargetResource).
# - If there are Write properties added as parameters to the Get-TargetResource function, they will be removed.
# - If parmaters uses ValidateIfNullOrEmtpy or ValidateLength in parameters, they will be removed.
# - SupportsShouldProcess will be removed from Set-TargetResource function.
############

Import-Module xDSCResourceDesigner

$ModuleName = 'xSQLServerAlwaysOn'
$ModuleRootPath = Split-Path -Parent $MyInvocation.MyCommand.Path

#region xSQLServerAlwaysOnService
if ( $False ) {
    $DscResourceName = 'xSQLServerAlwaysOnService'
    $resourceVariables = @{
        Property = `
        (New-xDscResourceProperty -Name InstanceName -Type String -Attribute Key -Description 'The SQL Server instance name.'), `
        (New-xDscResourceProperty -Name NodeName -Type String -Attribute Required -Description 'The host name or FQDN.'), `
        (New-xDscResourceProperty -Name Ensure -Type String -Attribute Write -ValidateSet "Present", "Absent" -Description 'If Always On should be present (enabled) or absent (disabled).')
    }

    $ResourcePath = Join-Path (Join-Path $ModuleRootPath -ChildPath "DSCResources") -ChildPath $DscResourceName 
    if( -not ( Test-Path $ResourcePath ) ) {
        New-xDscResource  -Name $DscResourceName @resourceVariables -Path $ModuleRootPath -ModuleName $ModuleName
    } else {
        Update-xDscResource -Path $ResourcePath @resourceVariables -Force    
    }
}
#endregion xSQLServerAlwaysOnService

#region xSQLServerAlwaysOnEndpoint
if ( $False ) { 
    $DscResourceName = 'xSQLServerAlwaysOnEndpoint'
    $resourceVariables = @{
        Property = `
        (New-xDscResourceProperty -Name InstanceName -Type String -Attribute Key -Description 'The SQL Server instance name.'), `
        (New-xDscResourceProperty -Name NodeName -Type String -Attribute Required -Description 'The host name or FQDN.'), `
        (New-xDscResourceProperty -Name Ensure -Type String -Attribute Write -ValidateSet "Present", "Absent" -Description 'If the endpoint should be present or absent.'), `
        (New-xDscResourceProperty -Name Name -Type String -Attribute Required -Description 'The name of the endpoint.'), `
        (New-xDscResourceProperty -Name Port -Type Uint16 -Attribute Write -Description 'The network port the endpoint is listening on. Default value is 5022.'), `
        (New-xDscResourceProperty -Name IpAddress -Type String -Attribute Write -Description 'The network IP address the endpoint is listening on. Default the endpoint will listen on all valid IP addresses.')
    }

    $ResourcePath = Join-Path (Join-Path $ModuleRootPath -ChildPath "DSCResources") -ChildPath $DscResourceName 
    if( -not ( Test-Path $ResourcePath ) ) {
        New-xDscResource  -Name $DscResourceName @resourceVariables -Path $ModuleRootPath -ModuleName $ModuleName
    } else {
        Update-xDscResource -Path $ResourcePath @resourceVariables -Force    
    }
}
#endregion xSQLServerAlwaysOnEndpoint

#region xSQLServerAlwaysOnEndpointState
if ( $False ) { 
    $DscResourceName = 'xSQLServerAlwaysOnEndpointState'
    $resourceVariables = @{
        Property = `
        (New-xDscResourceProperty -Name InstanceName -Type String -Attribute Key -Description 'The SQL Server instance name.'), `
        (New-xDscResourceProperty -Name NodeName -Type String -Attribute Required -Description 'The host name or FQDN.'), `
        (New-xDscResourceProperty -Name Name -Type String -Attribute Required -Description 'The name of the endpoint.'), `
        (New-xDscResourceProperty -Name State -Type String -Attribute Write -ValidateSet "Started", "Stopped","Disabled" -Description 'The state of the endpoint. Valid states are Started, Stopped or Disabled.')
    }

    $ResourcePath = Join-Path (Join-Path $ModuleRootPath -ChildPath "DSCResources") -ChildPath $DscResourceName 
    if( -not ( Test-Path $ResourcePath ) ) {
        New-xDscResource  -Name $DscResourceName @resourceVariables -Path $ModuleRootPath -ModuleName $ModuleName
    } else {
        Update-xDscResource -Path $ResourcePath @resourceVariables -Force    
    }
}
#endregion xSQLServerAlwaysOnEndpointState

#region xSQLServerAlwaysOnEndpointPermission
if ( $False ) { 
    $DscResourceName = 'xSQLServerAlwaysOnEndpointPermission'
    $resourceVariables = @{
        Property = `
        (New-xDscResourceProperty -Name InstanceName -Type String -Attribute Key -Description 'The SQL Server instance name.'), `
        (New-xDscResourceProperty -Name NodeName -Type String -Attribute Required -Description 'The host name or FQDN.'), `
        (New-xDscResourceProperty -Name Ensure -Type String -Attribute Write -ValidateSet "Present", "Absent" -Description 'If the permission should be present or absent.'), `
        (New-xDscResourceProperty -Name Name -Type String -Attribute Required -Description 'The name of the endpoint.'), `
        (New-xDscResourceProperty -Name Principal -Type String -Attribute Required -Description 'The login to which permission will be set.'), `
        (New-xDscResourceProperty -Name Permission -Type String -Attribute Write -ValidateSet "CONNECT" -Description 'The permission to set for the login.')
    }

    $ResourcePath = Join-Path (Join-Path $ModuleRootPath -ChildPath "DSCResources") -ChildPath $DscResourceName 
    if( -not ( Test-Path $ResourcePath ) ) {
        New-xDscResource  -Name $DscResourceName @resourceVariables -Path $ModuleRootPath -ModuleName $ModuleName
    } else {
        Update-xDscResource -Path $ResourcePath @resourceVariables -Force    
    }
}
#endregion xSQLServerAlwaysOnEndpointPermission

#region xSQLServerAlwaysOnPermission
if ( $False ) { 
    $DscResourceName = 'xSQLServerAlwaysOnPermission' 
    $resourceVariables = @{
        Property = `
        (New-xDscResourceProperty -Name InstanceName -Type String -Attribute Key -Description 'The SQL Server instance name.'), `
        (New-xDscResourceProperty -Name NodeName -Type String -Attribute Required -Description 'The host name or FQDN.'), `
        (New-xDscResourceProperty -Name Ensure -Type String -Attribute Write -ValidateSet "Present", "Absent" -Description 'If the permission should be present or absent.'), `
        (New-xDscResourceProperty -Name Principal -Type String -Attribute Required -Description 'The login to which permission will be set.'), `
        (New-xDscResourceProperty -Name Permission -Type "String[]" -Attribute Write -ValidateSet "ALTER ANY AVAILABILITY GROUP","VIEW SERVER STATE","ALTER ANY ENDPOINT" -Description 'The permission to set for the login.')
    }

    $ResourcePath = Join-Path (Join-Path $ModuleRootPath -ChildPath "DSCResources") -ChildPath $DscResourceName 
    if( -not ( Test-Path $ResourcePath ) ) {
        New-xDscResource  -Name $DscResourceName @resourceVariables -Path $ModuleRootPath -ModuleName $ModuleName
    } else {
        Update-xDscResource -Path $ResourcePath @resourceVariables -Force    
    }
}
#endregion xSQLServerAlwaysOnPermission

#region xSQLServerAlwaysOnAvailabilityGroup
if ( $False ) { 
    $DscResourceName = 'xSQLServerAlwaysOnAvailabilityGroup'  
    $resourceVariables = @{
        Property = `
        (New-xDscResourceProperty -Name InstanceName -Type String -Attribute Key -Description 'The SQL Server instance name of the primary replica.'), `
        (New-xDscResourceProperty -Name NodeName -Type String -Attribute Required -Description 'The host name or FQDN of the primary replica.'), `
        (New-xDscResourceProperty -Name Name -Type String -Attribute Key -Description 'The name of the availability group.'), `
        (New-xDscResourceProperty -Name Ensure -Type String -Attribute Write -ValidateSet "Present", "Absent" -Description 'If the availability group should be present or absent.'), `
        (New-xDscResourceProperty -Name AvailabilityMode -Type String -Attribute Write  -ValidateSet "SynchronousCommit","AsynchronousCommit" -Description 'The availability mode for the primary replica'), `
        (New-xDscResourceProperty -Name FailoverMode -Type String -Attribute Write -ValidateSet "Automatic","Manual" -Description 'The failover mode for the primary replica'), `
        (New-xDscResourceProperty -Name HealthCheckTimeout -Type UInt32 -Attribute Write -Description 'The length of time, in milliseconds, after which the availability group declares an unresponsive server to be unhealthy.'), `
        (New-xDscResourceProperty -Name FailureConditionLevel -Type String -Attribute Write -ValidateSet "OnServerDown","OnServerUnresponsive","OnCriticalServerErrors","OnModerateServerErrors","OnAnyQualifiedFailureCondition" -Description 'The automatic failover behavior of the availability group')
    }

    $ResourcePath = Join-Path (Join-Path $ModuleRootPath -ChildPath "DSCResources") -ChildPath $DscResourceName 
    if( -not ( Test-Path $ResourcePath ) ) {
        New-xDscResource  -Name $DscResourceName @resourceVariables -Path $ModuleRootPath -ModuleName $ModuleName
    } else {
        Update-xDscResource -Path $ResourcePath @resourceVariables -Force    
    }
}
#endregion xSQLServerAlwaysOnAvailabilityGroup

#region xSQLServerAlwaysOnAvailabilityGroupListner
if ( $False ) { 
    $DscResourceName = 'xSQLServerAlwaysOnAvailabilityGroupListner'  
    $resourceVariables = @{ # Splatting the resource properties
        Property = `
        (New-xDscResourceProperty -Name InstanceName -Type String -Attribute Key -Description 'The SQL Server instance name of the primary replica.'), `
        (New-xDscResourceProperty -Name NodeName -Type String -Attribute Required -Description 'The host name or FQDN of the primary replica.'), `
        (New-xDscResourceProperty -Name Name -Type String -Attribute Required -Description 'The name of the availability group listner, max 15 characters. This name will be used as the Virtual Computer Object (VCO).'), `
        (New-xDscResourceProperty -Name Ensure -Type String -Attribute Write -ValidateSet "Present", "Absent" -Description 'If the availability group listner should be present or absent.'), `
        (New-xDscResourceProperty -Name AvailabilityGroup -Type String -Attribute Key -Description 'The name of the availability group to which the availability group listner is or will be connected.'), `
        (New-xDscResourceProperty -Name IpAddress -Type String[] -Attribute Write `
            -Description 'The IP address used for the availability group listener, in the format 192.168.10.45/255.255.252.0. If using DCHP, set to the first IP-address of the DHCP subnet, in the format 192.168.8.1/255.255.252.0. Must be valid in the cluster-allowed IP range.'), `
        (New-xDscResourceProperty -Name Port -Type UInt16 -Attribute Write -Description 'The port used for the availability group listner.'), `
        (New-xDscResourceProperty -Name DHCP -Type Boolean -Attribute Write -Description 'If DHCP should be used for the availability group listner instead of static IP address.')
    }

    $ResourcePath = Join-Path (Join-Path $ModuleRootPath -ChildPath "DSCResources") -ChildPath $DscResourceName 
    if( -not ( Test-Path $ResourcePath ) ) {
        New-xDscResource  -Name $DscResourceName @resourceVariables -Path $ModuleRootPath -ModuleName $ModuleName
    } else {
        Update-xDscResource -Path $ResourcePath @resourceVariables -Force    
    }
}
#endregion xSQLServerAlwaysOnAvailabilityGroupListner

#region xSQLServerAlwaysOnAvailabilityGroupReplica
if ( $False ) { 
    $DscResourceName = 'xSQLServerAlwaysOnAvailabilityGroupReplica'  
    $resourceVariables = @{
        Property = `
        (New-xDscResourceProperty -Name InstanceName -Type String -Attribute Key -Description 'The SQL Server instance name of the secondary replica.'), `
        (New-xDscResourceProperty -Name NodeName -Type String -Attribute Key -Description 'The host name or FQDN of the secondary replica.'), `
        (New-xDscResourceProperty -Name PrimaryReplicaInstanceName -Type String -Attribute Required -Description 'The SQL Server instance name of the primary replica.'), `
        (New-xDscResourceProperty -Name PrimaryReplicaNodeName -Type String -Attribute Required -Description 'The host name or FQDN of the primary replica.'), `
        (New-xDscResourceProperty -Name AvailabilityGroup -Type String -Attribute Key -Description 'The name of the availability group to which the secondary replica is or will be connected.'), `
        (New-xDscResourceProperty -Name Ensure -Type String -Attribute Write -ValidateSet "Present", "Absent" -Description 'If the secondary replica should be present or absent.'), `
        (New-xDscResourceProperty -Name AvailabilityMode -Type String -Attribute Write  -ValidateSet "SynchronousCommit","AsynchronousCommit" -Description 'The availability mode for the secondary replica.'), `
        (New-xDscResourceProperty -Name FailoverMode -Type String -Attribute Write -ValidateSet "Automatic","Manual" -Description 'The failover mode for the secondary replica.'), `
        (New-xDscResourceProperty -Name Timeout -Type UInt16 -Attribute Write -Description 'If the primary replica has not responded, or can not be verified to be the primary replica within this time period, an error will be thrown.')
    }

    $ResourcePath = Join-Path (Join-Path $ModuleRootPath -ChildPath "DSCResources") -ChildPath $DscResourceName 
    if( -not ( Test-Path $ResourcePath ) ) {
        New-xDscResource  -Name $DscResourceName @resourceVariables -Path $ModuleRootPath -ModuleName $ModuleName
    } else {
        Update-xDscResource -Path $ResourcePath @resourceVariables -Force    
    }
}
#endregion xSQLServerAlwaysOnAvailabilityGroupReplica
