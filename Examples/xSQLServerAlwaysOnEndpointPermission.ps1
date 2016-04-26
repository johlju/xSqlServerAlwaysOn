$ConfigData = @{
    AllNodes = @(
        @{
            NodeName= "*"
            CertificateFile = "C:\Certificates\dsc-public.cer" 
            Thumbprint = "D6F57B6BE46A7162138687FB74DBAA1D4EB1A59B" 
            SqlInstanceName = "MSSQLSERVER" # Default instance
            PSDscAllowDomainUser = $true
        },

        @{ 
            NodeName = 'SQLNODE01.company.local'
            Role = "PrimaryReplica"
        },

        @{
            NodeName = 'SQLNODE02.company.local' 
            Role = "SecondaryReplica" 
        }
    )
}
 
Configuration SQLAlwaysOnNodeConfig 
{
    param
    (
        [Parameter(Mandatory=$false)] 
        [ValidateNotNullorEmpty()] 
        [PsCredential]$SqlAdministratorCredential,

        [Parameter(Mandatory=$true)] 
        [ValidateNotNullorEmpty()] 
        [PsCredential]$SqlServiceCredentialNode1, 

        [Parameter(Mandatory=$true)] 
        [ValidateNotNullorEmpty()] 
        [PsCredential]$SqlServiceCredentialNode2
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xSqlServerAlwaysOn -ModuleVersion 1.0.0.0

    Node $AllNodes.Where{$_.Role -eq "PrimaryReplica" }.NodeName
    {
        xSQLServerAlwaysOnEndpoint SQLConfigureAlwaysOnEndpoint
        {
            Ensure = "Present"
            NodeName = $Node.NodeName
            InstanceName = $Node.SqlInstanceName
            Name = "DefaultMirrorEndpoint"

            PsDscRunAsCredential = $SqlAdministratorCredential
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
        
        # Remove endpoint permissions       
        xSQLServerAlwaysOnEndpointPermission RemoveSQLConfigureAlwaysOnEndpointPermissionPrimary
        {
           Ensure = "Absent"
           NodeName = $Node.NodeName
           InstanceName = $Node.SqlInstanceName
           Name = "DefaultMirrorEndpoint"
           Principal = $SqlServiceCredentialNode2.UserName 
           Permission = "CONNECT"
        
           PsDscRunAsCredential = $SqlAdministratorCredential
        
           DependsOn = "[xSQLServerAlwaysOnEndpointPermission]SQLConfigureAlwaysOnEndpointPermissionPrimary"
        }

        xSQLServerAlwaysOnEndpointPermission RemoveSQLConfigureAlwaysOnEndpointPermissionSecondary
        {
           Ensure = "Absent"
           NodeName = $Node.NodeName
           InstanceName = $Node.SqlInstanceName
           Name = "DefaultMirrorEndpoint"
           Principal = $SqlServiceCredentialNode2.UserName 
           Permission = "CONNECT"
        
           PsDscRunAsCredential = $SqlAdministratorCredential
        
           DependsOn = "[xSQLServerAlwaysOnEndpointPermission]SQLConfigureAlwaysOnEndpointPermissionSecondary"
        } 
   }

    Node $AllNodes.Where{ $_.Role -eq "SecondaryReplica" }.NodeName
    {         
        xSQLServerAlwaysOnEndpoint SQLConfigureAlwaysOnEndpoint
        {
            Ensure = "Present"
            NodeName = $Node.NodeName
            InstanceName = $Node.SqlInstanceName
            Name = "DefaultMirrorEndpoint"

            PsDscRunAsCredential = $SqlAdministratorCredential
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

        # Remove endpoint permissions       
        xSQLServerAlwaysOnEndpointPermission RemoveSQLConfigureAlwaysOnEndpointPermissionPrimary
        {
           Ensure = "Absent"
           NodeName = $Node.NodeName
           InstanceName = $Node.SqlInstanceName
           Name = "DefaultMirrorEndpoint"
           Principal = $SqlServiceCredentialNode2.UserName 
           Permission = "CONNECT"
        
           PsDscRunAsCredential = $SqlAdministratorCredential
        
           DependsOn = "[xSQLServerAlwaysOnEndpointPermission]SQLConfigureAlwaysOnEndpointPermissionPrimary"
        }

        xSQLServerAlwaysOnEndpointPermission RemoveSQLConfigureAlwaysOnEndpointPermissionSecondary
        {
           Ensure = "Absent"
           NodeName = $Node.NodeName
           InstanceName = $Node.SqlInstanceName
           Name = "DefaultMirrorEndpoint"
           Principal = $SqlServiceCredentialNode2.UserName 
           Permission = "CONNECT"
        
           PsDscRunAsCredential = $SqlAdministratorCredential
        
           DependsOn = "[xSQLServerAlwaysOnEndpointPermission]SQLConfigureAlwaysOnEndpointPermissionSecondary"
        } 
    }
}

$SqlAdministratorCredential = Get-Credential -Message "Enter credentials for SQL Server administrator account"
$SqlServiceCredentialNode1 = Get-Credential -Message "Enter credentials for SQL Service account for primary replica"
$SqlServiceCredentialNode2 = Get-Credential -Message "Enter credentials for SQL Service account for secondary replica" 

SQLAlwaysOnNodeConfig `
    -SqlAdministratorCredential $SqlAdministratorCredential `
    -SqlServiceCredentialNode1 $SqlServiceCredentialNode1 `
    -SqlServiceCredentialNode2 $SqlServiceCredentialNode2 `
    -ConfigurationData $ConfigData `
    -OutputPath 'C:\Configuration'
