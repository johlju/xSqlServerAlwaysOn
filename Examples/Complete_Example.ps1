
$ConfigData = @{
    AllNodes = @(
        @{
            NodeName= "*"
            
            # The path to the .cer file containing the public key of the certificate used to encrypt the credentials 
            CertificateFile = "C:\Certificates\dsc-public.cer" 
            
            # The thumbprint of the certificate used to encrypt the credentials. This tells LCM which ertificate to use to decrypt the credentials. 
            # A certificate that is stored on the local machine store and identified in the LCM Configuration file
            Thumbprint = "D6F57B6BE46A7162138687FB74DBAA1D4EB1A59B" 

            # Name of the Cluster Named Object (CNO). This account must be prestaged, disabled and have the right permission.
            ClusterName = "CLUSTER01"
            
            # Valid IP-adress for the Cluster Named Object (CNO). 
            ClusterIPAddress = "192.168.0.10/24"

            # Default instance
            SqlInstanceName = "MSSQLSERVER"
            
            # Use same values as the /FEATURES parameter used by SQL Server setup.exe. See https://msdn.microsoft.com/en-us/library/ms144259(v=sql.120).aspx#Feature
            # These values must be UPPERCASE.
            SqlInstallFeatures = "SQLENGINE,SSMS" 

            # Location of SQL Server installation media
            SourcePath = "\\files.company.local\media"
            SourceFolder = "SQL2014SP1"

            # Location of Windows Server sxs folder.
            WindowsSourceSxs = "\\files.company.local\media\Win2k12R2\Sources\Sxs"

            PSDscAllowDomainUser = $true
        },

        @{ 
            NodeName = "SQLNODE01.company.local"
            Role = "PrimaryReplica"
            
            # Unique guid for this node (created random with New-Guid)
            Guid = "527e76ec-f179-79f6-a0f4-2c7d86036373"
        },

        @{
            NodeName = "SQLNODE02.company.local" 
            Role = "SecondaryReplica" 
            
            # Unique guid for this node (created random with New-Guid)
            Guid = "9fb5cb33-5539-4721-9e09-08fcbce94d65"
        }

        @{
            NodeName = "SQLNODE03.company.local" 
            Role = "SecondaryReplica"
            
            # Unique guid for this node (created random with New-Guid)
            Guid = "423d70aa-c776-4678-a90c-e73279bf15ba"
        }
    )
}

[DSCLocalConfigurationManager()]
configuration LCMConfig 
{
    Node $AllNodes.NodeName
    {
        Settings
        {
            ConfigurationID = $node.Guid
            RefreshMode = "Push"
            RebootNodeIfNeeded = $true
            ConfigurationMode = "ApplyAndAutoCorrect"
            CertificateId = $node.Thumbprint 
            AllowModuleOverwrite = $true
        }

        ResourceRepositoryShare FileShare
        {
            # Non-existing modules on the nodes are downloaded from this location
            SourcePath = "\\files.company.local\media\Modules"
        }
    }
}

Configuration SQLAlwaysOnNodeConfig
{
    param
    (
        [Parameter(Mandatory=$true)] 
        [ValidateNotNullorEmpty()] 
        [PsCredential]$ClusterAdminCredential,

        [Parameter(Mandatory=$true)] 
        [ValidateNotNullorEmpty()] 
        [PsCredential]$SqlInstallCredential, 

        [Parameter(Mandatory=$false)] 
        [ValidateNotNullorEmpty()] 
        [PsCredential]$SqlAdministratorCredential = $SqlInstallCredential, 

        [Parameter(Mandatory=$true)] 
        [ValidateNotNullorEmpty()] 
        [PsCredential]$SqlServiceCredentialNode1, 

        [Parameter(Mandatory=$false)] 
        [ValidateNotNullorEmpty()] 
        [PsCredential]$SqlAgentServiceCredentialNode1 = $SqlServiceCredentialNode1, 

        [Parameter(Mandatory=$true)] 
        [ValidateNotNullorEmpty()] 
        [PsCredential]$SqlServiceCredentialNode2, 

        [Parameter(Mandatory=$false)] 
        [ValidateNotNullorEmpty()] 
        [PsCredential]$SqlAgentServiceCredentialNode2 = $SqlServiceCredentialNode2
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xFailOverCluster -ModuleVersion 1.1.1
    Import-DscResource -ModuleName xSqlServer -ModuleVersion 1.5.0.0
    Import-DscResource -ModuleName xSqlServerAlwaysOn -ModuleVersion 1.0.0.0

    Node $AllNodes.Where{$_.Role -eq "PrimaryReplica" }.NodeName
    {
        #region Install prerequisites for SQL Server
        WindowsFeature NET35 {
           Name = "NET-Framework-Core"
           Source = $node.WindowsSourceSxs
           Ensure = "Present"
        }

        WindowsFeature NET45 {
           Name = "NET-Framework-45-Core"
           Ensure = "Present"
        }
        #endregion Install prerequisites for SQL Server

        #region SQL Server Always On/Failover Cluster prerequisites
        WindowsFeature MSMQTriggers
        {
            Ensure = "Present"
            Name      = "MSMQ-Triggers"
        }
        #endregion SQL Server Always On/Failover Cluster prerequisites

        #region Install Failover Cluster components
        WindowsFeature FailoverFeature
        {
            Ensure = "Present"
            Name      = "Failover-clustering"
        }

        WindowsFeature RSATClusteringMgmt
        {
            Name   = "RSAT-Clustering-Mgmt"   
            Ensure = "Present"
            DependsOn = "[WindowsFeature]FailoverFeature"
        }

        WindowsFeature RSATClusteringPowerShell
        {
            Ensure = "Present"
            Name   = "RSAT-Clustering-PowerShell"   

            DependsOn = "[WindowsFeature]FailoverFeature"
        }

        WindowsFeature RSATClusteringCmdInterface
        {
            Ensure = "Present"
            Name   = "RSAT-Clustering-CmdInterface"

            DependsOn = "[WindowsFeature]RSATClusteringPowerShell"
        }
        #endregion Install Failover Cluster components

        #region Configure Failover Cluster
        xCluster CreateClusterAndJoinPrimaryNode 
        {
            Name = $Node.ClusterName
            StaticIPAddress = $Node.ClusterIPAddress
            DomainAdministratorCredential = $ClusterAdminCredential  

            DependsOn = “[WindowsFeature]RSATClusteringCmdInterface”
        }

        xWaitForCluster WaitForCluster
        {
            Name = $Node.ClusterName
            RetryIntervalSec = 10
            RetryCount = 60

            DependsOn = “[xCluster]CreateClusterAndJoinPrimaryNode” 
        }

        xClusterQuorum ClusterConfigureQuorum
        {
            Type = "NodeAndFileShareMajority"
            Resource = '\\witness.company.local\clusterwitness$' 

            PsDscRunAsCredential = $ClusterAdminCredential   

            DependsOn = "[xWaitForCluster]WaitForCluster"
        }
        #endregion Configure Failover Cluster

        #region Install SQL Server
        xSQLServerSetup InstallSqlServer
        {
            InstanceName = $Node.SqlInstanceName
            Features= $Node.SqlInstallFeatures
            BrowserSvcStartupType = "Automatic"
            SQLCollation = "Latin1_General_CI_AS_KS_WS"
            SQLSvcAccount = $SqlServiceCredentialNode1
            AgtSvcAccount = $SqlAgentServiceCredentialNode1
            SQLSysAdminAccounts = "COMPANY\SQL Administrators", $SqlAdministratorCredential.UserName
            SetupCredential = $SqlInstallCredential

            SourcePath = $Node.SourcePath
            SourceFolder = $Node.SourceFolder
            SourceCredential = $SqlInstallCredential
            UpdateEnabled = "False"

            SuppressReboot = $False
            ForceReboot = $False

            DependsOn = "[WindowsFeature]NET35","[WindowsFeature]NET45", "[xWaitForCluster]WaitForCluster"
        }
        #endregion Install SQL Server

        #region Configure SQL Server
        xSQLServerFirewall SQLFirewallConfiguration
        {
            Ensure = "Present"
            SourcePath = $Node.SourcePath
            SourceFolder = $Node.SourceFolder
            InstanceName = $Node.SqlInstanceName
            Features= $Node.SqlInstallFeatures  # Same values as /FEATURES parameter on SQL setup.exe

            PsDscRunAsCredential = $SqlInstallCredential

            DependsOn = "[xSQLServerSetup]InstallSqlServer"
        }

        # This one is only needed if the instance is used for SharePoint 
        xSQLServerMaxDop SQLConfigureMaxDop
        {
            Ensure = "Present"
            MaxDop = 1
            DynamicAlloc = $False
            SQLServer = $Node.NodeName
            SQLInstanceName = $Node.SqlInstanceName

            PsDscRunAsCredential = $SqlAdministratorCredential

            DependsOn = "[xSQLServerSetup]InstallSqlServer"
        }
        #endregion Configure SQL Server

        #region Configure SQL Server Always On
        xSQLServerAlwaysOnService SQLConfigureAlwaysOnService
        {
            Ensure = "Present"
            NodeName = $Node.NodeName
            InstanceName = $Node.SqlInstanceName

            PsDscRunAsCredential = $SqlInstallCredential  # Works without this (as SYSTEM). Automatic RunAs support; https://msdn.microsoft.com/en-us/powershell/wmf/dsc_runas

            DependsOn = "[xSQLServerMaxDop]SQLConfigureMaxDop"
        }

        Service SQLServerServiceStarted
        {
            Name = "MSSQLSERVER"
            State = "Running"

            PsDscRunAsCredential = $SqlInstallCredential

            DependsOn = "[xSQLServerAlwaysOnService]SQLConfigureAlwaysOnService"
        }

        Service SQLServerAgentServiceStarted
        {
            Name = "SQLSERVERAGENT"
            State = "Running"

            PsDscRunAsCredential = $SqlInstallCredential

            DependsOn = "[Service]SQLServerServiceStarted"
        }

        xSQLServerLogin SQLConfigureLoginPrimary
        {
            Name = $SqlServiceCredentialNode1.UserName
            LoginType = "WindowsUser"
            SQLServer = $Node.NodeName
            SQLInstanceName = $Node.SqlInstanceName

            PsDscRunAsCredential = $SqlAdministratorCredential

            DependsOn = "[Service]SQLServerServiceStarted"
        }

        xSQLServerLogin SQLConfigureLoginSecondary
        {
            Name = $SqlServiceCredentialNode2.UserName
            LoginType = "WindowsUser"
            SQLServer = $Node.NodeName
            SQLInstanceName = $Node.SqlInstanceName
        
            PsDscRunAsCredential = $SqlAdministratorCredential
        
            DependsOn = "[Service]SQLServerServiceStarted"
        }

        xSQLServerLogin SQLAlwaysOnHealthDetectionAccount
        {
            Name = "NT AUTHORITY\SYSTEM"
            LoginType = "WindowsUser"
            SQLServer = $Node.NodeName
            SQLInstanceName = $Node.SqlInstanceName

            PsDscRunAsCredential = $SqlAdministratorCredential

            DependsOn = "[Service]SQLServerServiceStarted"
        }

        xSQLServerAlwaysOnEndpoint SQLConfigureAlwaysOnEndpoint
        {
            Ensure = "Present"
            NodeName = $Node.NodeName
            InstanceName = $Node.SqlInstanceName
            Name = "DefaultMirrorEndpoint"

            PsDscRunAsCredential = $SqlAdministratorCredential

            DependsOn = "[Service]SQLServerServiceStarted" 
        }

        xSQLServerAlwaysOnEndpointState SQLConfigureAlwaysOnEndpointState
        {
            NodeName = $Node.NodeName
            InstanceName = $Node.SqlInstanceName
            Name = "DefaultMirrorEndpoint"
            State = "Started"

            PsDscRunAsCredential = $SqlAdministratorCredential

            DependsOn = "[xSQLServerAlwaysOnEndpoint]SQLConfigureAlwaysOnEndpoint"
        }

        xSQLServerAlwaysOnEndpointPermission SQLConfigureAlwaysOnEndpointPermissionPrimary
        {
            Ensure = "Present"
            NodeName = $Node.NodeName
            InstanceName = $Node.SqlInstanceName
            Name = "DefaultMirrorEndpoint"
            Principal = $SqlServiceCredentialNode1.UserName 
            Permission = "CONNECT"

            PsDscRunAsCredential = $SqlAdministratorCredential

            DependsOn = "[xSQLServerAlwaysOnEndpoint]SQLConfigureAlwaysOnEndpoint"
        }

        xSQLServerAlwaysOnEndpointPermission SQLConfigureAlwaysOnEndpointPermissionSecondary
        {
           Ensure = "Present"
           NodeName = $Node.NodeName
           InstanceName = $Node.SqlInstanceName
           Name = "DefaultMirrorEndpoint"
           Principal = $SqlServiceCredentialNode2.UserName 
           Permission = "CONNECT"
        
           PsDscRunAsCredential = $SqlAdministratorCredential
        
           DependsOn = "[xSQLServerAlwaysOnEndpoint]SQLConfigureAlwaysOnEndpoint"
        }

        xSQLServerAlwaysOnPermission SQLConfigureAlwaysOnPermissionHealthDetectionAccount
        {
            Ensure = "Present"
            NodeName = $Node.NodeName
            InstanceName = $Node.SqlInstanceName
            Principal = "NT AUTHORITY\SYSTEM" 
            Permission = "ALTER ANY AVAILABILITY GROUP","VIEW SERVER STATE"

            PsDscRunAsCredential = $SqlAdministratorCredential

            DependsOn = "[xSQLServerLogin]SQLAlwaysOnHealthDetectionAccount"
        }

        xSQLServerAlwaysOnAvailabilityGroup SQLCreateAlwaysOnAvailabilityGroupForFirstAG
        {
            Ensure = "Present"
            NodeName = $Node.NodeName
            InstanceName = $Node.SqlInstanceName
            Name = "AG-01"
            AvailabilityMode = "SynchronousCommit"
            FailoverMode = "Automatic"

            PsDscRunAsCredential = $SqlAdministratorCredential

            DependsOn = "[xSQLServerAlwaysOnPermission]SQLConfigureAlwaysOnPermissionHealthDetectionAccount" 
        }

        xSQLServerAlwaysOnAvailabilityGroupListner SQLCreateAlwaysOnAvailabilityGroupFirstAGListner
        {
            Ensure = "Present"
            NodeName = $Node.NodeName
            InstanceName = $Node.SqlInstanceName
            AvailabilityGroup = "AG-01"
            Name = "AG-01"
            IpAddress = "192.168.0.73/255.255.255.0"
            Port = 5304

            PsDscRunAsCredential = $SqlAdministratorCredential
            
            DependsOn = "[xSQLServerAlwaysOnAvailabilityGroup]SQLCreateAlwaysOnAvailabilityGroupForFirstAG"
        }

        xSQLServerAlwaysOnAvailabilityGroup SQLCreateAlwaysOnAvailabilityGroupForSecondAG
        {
            Ensure = "Present"
            NodeName = $Node.NodeName
            InstanceName = $Node.SqlInstanceName
            Name = "AG-02"
            AvailabilityMode = "SynchronousCommit"
            FailoverMode = "Automatic"

            PsDscRunAsCredential = $SqlAdministratorCredential

            DependsOn = "[xSQLServerAlwaysOnPermission]SQLConfigureAlwaysOnPermissionHealthDetectionAccount" 
        }

        xSQLServerAlwaysOnAvailabilityGroupListner SQLCreateAlwaysOnAvailabilityGroupSecondAGListner
        {
            Ensure = "Present"
            NodeName = $Node.NodeName
            InstanceName = $Node.SqlInstanceName
            AvailabilityGroup = "AG-02"
            Name = "AG-02"
            IpAddress = "192.168.0.74/255.255.255.0"
            Port = 5301

            PsDscRunAsCredential = $SqlAdministratorCredential
            
            DependsOn = "[xSQLServerAlwaysOnAvailabilityGroup]SQLCreateAlwaysOnAvailabilityGroupForSecondAG"
        }

        xSQLServerAlwaysOnAvailabilityGroup SQLCreateAlwaysOnAvailabilityGroupForThirdAG
        {
            Ensure = "Present"
            NodeName = $Node.NodeName
            InstanceName = $Node.SqlInstanceName
            Name = "AG-03"
            AvailabilityMode = "SynchronousCommit"
            FailoverMode = "Automatic"

            PsDscRunAsCredential = $SqlAdministratorCredential

            DependsOn = "[xSQLServerAlwaysOnPermission]SQLConfigureAlwaysOnPermissionHealthDetectionAccount" 
        }

        xSQLServerAlwaysOnAvailabilityGroupListner SQLCreateAlwaysOnAvailabilityGroupThirdAGListner
        {
            Ensure = "Present"
            NodeName = $Node.NodeName
            InstanceName = $Node.SqlInstanceName
            AvailabilityGroup = "AG-03"
            Name = "AG-03"
            IpAddress = "192.168.0.75/255.255.255.0"
            Port = 5302

            PsDscRunAsCredential = $SqlAdministratorCredential
            
            DependsOn = "[xSQLServerAlwaysOnAvailabilityGroup]SQLCreateAlwaysOnAvailabilityGroupForThirdAG"
        }

        # Can use long name in AG Group name as long as listner is max 15 characters.
        xSQLServerAlwaysOnAvailabilityGroup SQLCreateAlwaysOnAvailabilityGroupForFourthAG
        {
            Ensure = "Present"
            NodeName = $Node.NodeName
            InstanceName = $Node.SqlInstanceName
            Name = "AvailabilityGroup-ZeroFour"
            AvailabilityMode = "SynchronousCommit"
            FailoverMode = "Automatic"

            PsDscRunAsCredential = $SqlAdministratorCredential

            DependsOn = "[xSQLServerAlwaysOnPermission]SQLConfigureAlwaysOnPermissionHealthDetectionAccount" 
        }

        # Listner name is limited to 15 characters, but AG name can be longer.  
        xSQLServerAlwaysOnAvailabilityGroupListner SQLCreateAlwaysOnAvailabilityGroupFourthAGListner
        {
            Ensure = "Present"
            NodeName = $Node.NodeName
            InstanceName = $Node.SqlInstanceName
            AvailabilityGroup = "AvailabilityGroup-ZeroFour"
            Name = "AG-Fourth"
            IpAddress = "192.168.0.76/255.255.255.0"
            Port = 5303

            PsDscRunAsCredential = $SqlAdministratorCredential
            
            DependsOn = "[xSQLServerAlwaysOnAvailabilityGroup]SQLCreateAlwaysOnAvailabilityGroupForFourthAG"
        }
        #endregion Configure SQL Server Always On
    }

    Node $AllNodes.Where{ $_.Role -eq "SecondaryReplica" }.NodeName
    {         
        #region Install prerequisites for SQL Server
        WindowsFeature NET35 {
           Name = "NET-Framework-Core"
           Source = $node.WindowsSourceSxs
           Ensure = "Present"
        }

        WindowsFeature NET45 {
           Name = "NET-Framework-45-Core"
           Ensure = "Present"
        }
        #endregion Install prerequisites for SQL Server

        #region SQL Server Always On/Failover Cluster prerequisites
        WindowsFeature MSMQTriggers
        {
            Ensure = "Present"
            Name      = "MSMQ-Triggers"
        }
        #endregion SQL Server Always On/Failover Cluster prerequisites

        #region Install Failover Cluster components
        WindowsFeature FailoverFeature
        {
            Ensure = "Present"
            Name      = "Failover-clustering"
        }

        WindowsFeature RSATClusteringMgmt
        {
            Name   = "RSAT-Clustering-Mgmt"   
            Ensure = "Present"
            DependsOn = "[WindowsFeature]FailoverFeature"
        }

        WindowsFeature RSATClusteringPowerShell
        {
            Ensure = "Present"
            Name   = "RSAT-Clustering-PowerShell"   

            DependsOn = "[WindowsFeature]FailoverFeature"
        }

        WindowsFeature RSATClusteringCmdInterface
        {
            Ensure = "Present"
            Name   = "RSAT-Clustering-CmdInterface"

            DependsOn = "[WindowsFeature]RSATClusteringPowerShell"
        }
        #endregion Install Failover Cluster components

        #region Configure Failover Cluster
        xWaitForCluster WaitForCluster
        {
            Name = $Node.ClusterName
            RetryIntervalSec = 10
            RetryCount = 60

            DependsOn = “[WindowsFeature]RSATClusteringCmdInterface” 
        }

        xCluster JoinReplicaNodeToCluster
        {
            Name = $Node.ClusterName
            StaticIPAddress = $Node.ClusterIPAddress
            DomainAdministratorCredential = $DomainAdminCredential

            DependsOn = "[xWaitForCluster]WaitForCluster"
        }
        #endregion Configure Failover Cluster

        #region Install SQL Server
        xSQLServerSetup InstallSqlServer
        {
            InstanceName = $Node.SqlInstanceName
            Features= $Node.SqlInstallFeatures
            BrowserSvcStartupType = "Automatic"
            SQLCollation = "Latin1_General_CI_AS_KS_WS"
            SQLSvcAccount = $SqlServiceCredentialNode2
            AgtSvcAccount = $SqlAgentServiceCredentialNode2
            SQLSysAdminAccounts = "COMPANY\SQL Administrators", $SqlAdministratorCredential.UserName
            SetupCredential = $SqlInstallCredential

            SourcePath = $Node.SourcePath
            SourceFolder = $Node.SourceFolder
            SourceCredential = $SqlInstallCredential
            UpdateEnabled = "False"

            SuppressReboot = $False
            ForceReboot = $False

            DependsOn = "[WindowsFeature]NET35","[WindowsFeature]NET45", "[xCluster]JoinReplicaNodeToCluster"
        }
        #endregion Install SQL Server
        
        #region Configure SQL Server
        xSQLServerFirewall SQLFirewallConfiguration
        {
            Ensure = "Present"
            SourcePath = $Node.SourcePath
            SourceFolder = $Node.SourceFolder
            InstanceName = $Node.SqlInstanceName
            Features= $Node.SqlInstallFeatures  # Same values as /FEATURES parameter on SQL setup.exe

            PsDscRunAsCredential = $SqlInstallCredential

            DependsOn = "[xSQLServerSetup]InstallSqlServer"
        }

        # This one is only needed if the instance is used for SharePoint 
        xSQLServerMaxDop SQLConfigureMaxDop
        {
            Ensure = "Present"
            MaxDop = 1
            DynamicAlloc = $False
            SQLServer = $Node.NodeName
            SQLInstanceName = $Node.SqlInstanceName

            PsDscRunAsCredential = $SqlAdministratorCredential

            DependsOn = "[xSQLServerSetup]InstallSqlServer"
        }
        #endregion Configure SQL Server

        #region Configure SQL Server Always On
        xSQLServerAlwaysOnService SQLConfigureAlwaysOnService
        {
            Ensure = "Present"
            NodeName = $Node.NodeName
            InstanceName = $Node.SqlInstanceName
            
            PsDscRunAsCredential = $SqlInstallCredential

            DependsOn = "[xSQLServerMaxDop]SQLConfigureMaxDop"
        }

        Service SQLServerServiceStarted
        {
            Name = "MSSQLSERVER"
            State = "Running"

            DependsOn = "[xSQLServerAlwaysOnService]SQLConfigureAlwaysOnService"
        }

        Service SQLServerAgentServiceStarted
        {
            Name = "SQLSERVERAGENT"
            State = "Running"

            DependsOn = "[Service]SQLServerServiceStarted"
        }

        xSQLServerLogin SQLConfigureLoginPrimary
        {
            Name = $SqlServiceCredentialNode1.UserName
            LoginType = "WindowsUser"
            SQLServer = $Node.NodeName
            SQLInstanceName = $Node.SqlInstanceName
        
            PsDscRunAsCredential = $SqlAdministratorCredential
        
            DependsOn = "[Service]SQLServerServiceStarted"
        }

        xSQLServerLogin SQLConfigureLoginSecondary
        {
            Name = $SqlServiceCredentialNode2.UserName
            LoginType = "WindowsUser"
            SQLServer = $Node.NodeName
            SQLInstanceName = $Node.SqlInstanceName

            PsDscRunAsCredential = $SqlAdministratorCredential
        
            DependsOn = "[Service]SQLServerServiceStarted"
        }

        xSQLServerLogin SQLAlwaysOnHealthDetectionAccount
        {
            Name = "NT AUTHORITY\SYSTEM"
            LoginType = "WindowsUser"
            SQLServer = $Node.NodeName
            SQLInstanceName = $Node.SqlInstanceName

            PsDscRunAsCredential = $SqlAdministratorCredential

            DependsOn = "[Service]SQLServerServiceStarted"
        }

        xSQLServerAlwaysOnEndpoint SQLConfigureAlwaysOnEndpoint
        {
            Ensure = "Present"
            NodeName = $Node.NodeName
            InstanceName = $Node.SqlInstanceName
            Name = "DefaultMirrorEndpoint"

            PsDscRunAsCredential = $SqlAdministratorCredential

            DependsOn = "[Service]SQLServerServiceStarted"
        }

        xSQLServerAlwaysOnEndpointState SQLConfigureAlwaysOnEndpointState
        {
            NodeName = $Node.NodeName
            InstanceName = $Node.SqlInstanceName
            Name = "DefaultMirrorEndpoint"
            State = "Started"

            PsDscRunAsCredential = $SqlAdministratorCredential

            DependsOn = "[xSQLServerAlwaysOnEndpoint]SQLConfigureAlwaysOnEndpoint"
        }

        xSQLServerAlwaysOnEndpointPermission SQLConfigureAlwaysOnEndpointPermissionPrimary
        {
            Ensure = "Present"
            NodeName = $Node.NodeName
            InstanceName = $Node.SqlInstanceName
            Name = "DefaultMirrorEndpoint"
            Principal = $SqlServiceCredentialNode1.UserName 
            Permission = "CONNECT"
        
            PsDscRunAsCredential = $SqlAdministratorCredential
        
            DependsOn = "[xSQLServerAlwaysOnEndpoint]SQLConfigureAlwaysOnEndpoint"
        }

        xSQLServerAlwaysOnEndpointPermission SQLConfigureAlwaysOnEndpointPermissionSecondary
        {
            Ensure = "Present"
            NodeName = $Node.NodeName
            InstanceName = $Node.SqlInstanceName
            Name = "DefaultMirrorEndpoint"
            Principal = $SqlServiceCredentialNode2.UserName 
            Permission = "CONNECT"
        
            PsDscRunAsCredential = $SqlAdministratorCredential
        
            DependsOn = "[xSQLServerAlwaysOnEndpoint]SQLConfigureAlwaysOnEndpoint"
        }

        xSQLServerAlwaysOnPermission SQLConfigureAlwaysOnPermissionHealthDetectionAccount
        {
            Ensure = "Present"
            NodeName = $Node.NodeName
            InstanceName = $Node.SqlInstanceName
            Principal = "NT AUTHORITY\SYSTEM" 
            Permission = "ALTER ANY AVAILABILITY GROUP","VIEW SERVER STATE"

            PsDscRunAsCredential = $SqlAdministratorCredential

            DependsOn = "[xSQLServerLogin]SQLAlwaysOnHealthDetectionAccount"
        }

        xSQLServerAlwaysOnAvailabilityGroupReplica SQLAddSecondaryReplicaToFirstAG
        {
            AvailabilityGroup = "AG-01"
            NodeName = $Node.NodeName
            InstanceName = $Node.SqlInstanceName
            PrimaryReplicaInstanceName = $AllNodes.Where{$_.Role -eq "PrimaryReplica" }.SqlInstanceName
            PrimaryReplicaNodeName = $AllNodes.Where{$_.Role -eq "PrimaryReplica" }.NodeName
            Ensure = "Present"
            AvailabilityMode = "SynchronousCommit"
            FailoverMode = "Automatic"
            Timeout = 600

            PsDscRunAsCredential = $SqlAdministratorCredential

            DependsOn = "[xSQLServerAlwaysOnPermission]SQLConfigureAlwaysOnPermissionHealthDetectionAccount"
        }

        xSQLServerAlwaysOnAvailabilityGroupReplica SQLAddSecondaryReplicaToSecondAG
        {
            AvailabilityGroup = "AG-02"
            NodeName = $Node.NodeName
            InstanceName = $Node.SqlInstanceName
            PrimaryReplicaInstanceName = $AllNodes.Where{$_.Role -eq "PrimaryReplica" }.SqlInstanceName
            PrimaryReplicaNodeName = $AllNodes.Where{$_.Role -eq "PrimaryReplica" }.NodeName
            Ensure = "Present"
            AvailabilityMode = "SynchronousCommit"
            FailoverMode = "Automatic"
            Timeout = 600

            PsDscRunAsCredential = $SqlAdministratorCredential 

            DependsOn = "[xSQLServerAlwaysOnPermission]SQLConfigureAlwaysOnPermissionHealthDetectionAccount"
        }

        xSQLServerAlwaysOnAvailabilityGroupReplica SQLAddSecondaryReplicaToThirdAG
        {
            AvailabilityGroup = "AG-03"
            NodeName = $Node.NodeName
            InstanceName = $Node.SqlInstanceName
            PrimaryReplicaInstanceName = $AllNodes.Where{$_.Role -eq "PrimaryReplica" }.SqlInstanceName
            PrimaryReplicaNodeName = $AllNodes.Where{$_.Role -eq "PrimaryReplica" }.NodeName
            Ensure = "Present"
            AvailabilityMode = "SynchronousCommit"
            FailoverMode = "Automatic"
            Timeout = 600

            PsDscRunAsCredential = $SqlAdministratorCredential

            DependsOn = "[xSQLServerAlwaysOnPermission]SQLConfigureAlwaysOnPermissionHealthDetectionAccount"
        }

        xSQLServerAlwaysOnAvailabilityGroupReplica SQLAddSecondaryReplicaToFourthAG
        {
            AvailabilityGroup = "AvailabilityGroup-ZeroFour"
            NodeName = $Node.NodeName
            InstanceName = $Node.SqlInstanceName
            PrimaryReplicaInstanceName = $AllNodes.Where{$_.Role -eq "PrimaryReplica" }.SqlInstanceName
            PrimaryReplicaNodeName = $AllNodes.Where{$_.Role -eq "PrimaryReplica" }.NodeName
            Ensure = "Present"
            AvailabilityMode = "SynchronousCommit"
            FailoverMode = "Automatic"
            Timeout = 600

            PsDscRunAsCredential = $SqlAdministratorCredential

            DependsOn = "[xSQLServerAlwaysOnPermission]SQLConfigureAlwaysOnPermissionHealthDetectionAccount"
        }
        #endregion Configure SQL Server Always On
    }
}

# The following line invokes the LCM configuration and creates a .meta.mof file,  at the specified path, for each server in the $ConfigData hash table.
LCMConfig `
    -ConfigurationData $ConfigData `
    -OutputPath "C:\Configuration"

# Get all the credentials needed
$ActiveDirectoryAdminCredential = Get-Credential -Message "Enter credentials for Active Directory administrator"
$SqlInstallCredential = Get-Credential -Message "Enter credentials for SQL Setup account"
$SqlAdministratorCredential = Get-Credential -Message "Enter credentials for SQL Server administrator account"
$SqlServiceCredentialNode1 = Get-Credential -Message "Enter credentials for SQL Service account for primary replica"
# For simplicity this example uses the same credentials for both secondary replicas
$SqlServiceCredentialNode2 = Get-Credential -Message "Enter credentials for SQL Service account for all secondary replicas" 

# The following line invokes the DSC configuration and creates a .mof file,  at the specified path, for each server in the $ConfigData hash table.
SQLAlwaysOnNodeConfig `
    -DomainAdminCredential $ActiveDirectoryAdminCredential `
    -SqlInstallCredential $SqlInstallCredential `
    -SqlAdministratorCredential $SqlAdministratorCredential `
    -SqlServiceCredentialNode1 $SqlServiceCredentialNode1 `
    -SqlServiceCredentialNode2 $SqlServiceCredentialNode2 `
    -ConfigurationData $ConfigData `
    -OutputPath 'C:\Configuration'