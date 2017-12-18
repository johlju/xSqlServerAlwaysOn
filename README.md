# xSqlServerAlwaysOn
PowerShell DSC module for configure SQL Server Always On

**THIS MODULE IS OBSOLETE**  This functionality has been moved to PowerShell DSC Resource Kit module [SqlServerDsc](https://github.com/PowerShell/SqlServerDsc). The functionality of the resources in SqlServerDsc is much more improved.
If there is any functionality you are missing in the xSQLServer resources, please submit an [issue in SqlServerDsc](https://github.com/PowerShell/SqlServerDsc/issues)

## Resources
* **xSQLServerAlwaysOnService** Enabled or disables Always On.
* **xSQLServerAlwaysOnPermission** Grant or revoke permission on the SQL Server.
* **xSQLServerAlwaysOnEndpoint** Create or remove and endpoint.
* **xSQLServerAlwaysOnEndpointState** Change state of the endpoint.
* **xSQLServerAlwaysOnEndpointPermission** Grant or revoke permission on the endpoint.
* **xSQLServerAlwaysOnAvailabilityGroup** Create or remove an availability group on the primary replica (also creates the primary replica).
* **xSQLServerAlwaysOnAvailabilityGroupListner** Create or remove an availability group listner.
* **xSQLServerAlwaysOnAvailabilityGroupReplica** Create or remove an availability group secondary replica. 

## xSQLServerAlwaysOnService
* **InstanceName** The SQL Server instance name.
* **NodeName** The host name or FQDN.
* **Ensure** If Always On should be present (enabled) or absent (disabled).

## xSQLServerAlwaysOnPermission
* **InstanceName** The SQL Server instance name.
* **NodeName** The host name or FQDN.
* **Ensure** If the permission should be present or absent.
* **Principal** The login to which permission will be set.
* **Permission** The permission to set for the login. Valid values are ALTER ANY AVAILABILITY GROUP, VIEW SERVER STATE or ALTER ANY ENDPOINT.

## xSQLServerAlwaysOnEndpoint
* **InstanceName** The SQL Server instance name.
* **NodeName** The host name or FQDN.
* **Ensure** If the endpoint should be present or absent.
* **Name** The name of the endpoint.
* **Port** The network port the endpoint is listening on. Default value is 5022.
* **IpAddress** The network IP address the endpoint is listening on. Default the endpoint will listen on all valid IP addresses.

## xSQLServerAlwaysOnEndpointState
* **InstanceName** The SQL Server instance name.
* **NodeName** The host name or FQDN.
* **Name** The name of the endpoint.
* **State** The state of the endpoint. Valid states are Started, Stopped or Disabled.

## xSQLServerAlwaysOnEndpointPermission
* **InstanceName** The SQL Server instance name.
* **NodeName** The host name or FQDN.
* **Ensure** If the permission should be present or absent.
* **Name** The name of the endpoint.
* **Principal** The login to which permission will be set.
* **Permission** The permission to set for the login. Valid value for permission are only CONNECT.

## xSQLServerAlwaysOnAvailabilityGroup
* **InstanceName** The SQL Server instance name of the primary replica.
* **NodeName** The host name or FQDN of the primary replica.
* **Ensure** If the availability group should be present or absent.
* **Name** The name of the availability group.
* **AvailabilityMode** The availability mode for the primary replica. Valid values are SynchronousCommit or AsynchronousCommit.
* **FailoverMode** The failover mode for the primary replica. Valid values are Automatic or Manual.
* **HealthCheckTimeout** The length of time, in milliseconds, after which the availability group declares an unresponsive server to be unhealthy.
* **FailureConditionLevel** The automatic failover behavior of the availability group.

## xSQLServerAlwaysOnAvailabilityGroupListner
* **InstanceName** The SQL Server instance name of the primary replica.
* **NodeName** The host name or FQDN of the primary replica.
* **Ensure** If the availability group listner should be present or absent.
* **Name** The name of the availability group listner, max 15 characters. This name will be used as the Virtual Computer Object (VCO).
* **AvailabilityGroup** The name of the availability group to which the availability group listner is or will be connected.
* **IpAddress** The IP address used for the availability group listener, in the format 192.168.10.45/255.255.252.0. If using DCHP, set to the first IP-address of the DHCP subnet, in the format 192.168.8.1/255.255.252.0. Must be valid in the cluster-allowed IP range.
* **Port** The port used for the availability group listner.
* **DHCP** If DHCP should be used for the availability group listner instead of static IP address.

## xSQLServerAlwaysOnAvailabilityGroupReplica
* **InstanceName** The SQL Server instance name of the secondary replica.
* **NodeName** The host name or FQDN of the secondary replica.
* **Ensure** If the secondary replica should be present or absent.
* **PrimaryReplicaInstanceName** The SQL Server instance name of the primary replica.
* **PrimaryReplicaNodeName** The host name or FQDN of the primary replica.
* **AvailabilityGroup** The name of the availability group to which the secondary replica is or will be connected.
* **AvailabilityMode** The availability mode for the secondary replica. Valid values are SynchronousCommit or AsynchronousCommit.
* **FailoverMode** The failover mode for the secondary replica. Valid values are Automatic or Manual.
* **Timeout** If the primary replica has not responded, or can not be verified to be the primary replica within this time period, an error will be thrown.
