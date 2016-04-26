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
        [PsCredential]$SqlAdministratorCredential
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

        # Start the endpoint
        xSQLServerAlwaysOnEndpointState StartSQLConfigureAlwaysOnEndpoint
        {
            NodeName = $Node.NodeName
            InstanceName = $Node.SqlInstanceName
            Name = "DefaultMirrorEndpoint"
            State = "Started"

            PsDscRunAsCredential = $SqlAdministratorCredential

            DependsOn = "[xSQLServerAlwaysOnEndpoint]SQLConfigureAlwaysOnEndpoint"
        }

        # Stop the endpoint
        xSQLServerAlwaysOnEndpointState StopSQLConfigureAlwaysOnEndpoint
        {
            NodeName = $Node.NodeName
            InstanceName = $Node.SqlInstanceName
            Name = "DefaultMirrorEndpoint"
            State = "Stopped"

            PsDscRunAsCredential = $SqlAdministratorCredential

            DependsOn = "[xSQLServerAlwaysOnEndpoint]SQLConfigureAlwaysOnEndpoint"
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

        # Start the endpoint
        xSQLServerAlwaysOnEndpointState StartSQLConfigureAlwaysOnEndpoint
        {
            NodeName = $Node.NodeName
            InstanceName = $Node.SqlInstanceName
            Name = "DefaultMirrorEndpoint"
            State = "Started"

            PsDscRunAsCredential = $SqlAdministratorCredential

            DependsOn = "[xSQLServerAlwaysOnEndpoint]SQLConfigureAlwaysOnEndpoint"
        }

        # Stop the endpoint
        xSQLServerAlwaysOnEndpointState StopSQLConfigureAlwaysOnEndpoint
        {
            NodeName = $Node.NodeName
            InstanceName = $Node.SqlInstanceName
            Name = "DefaultMirrorEndpoint"
            State = "Stopped"

            PsDscRunAsCredential = $SqlAdministratorCredential

            DependsOn = "[xSQLServerAlwaysOnEndpoint]SQLConfigureAlwaysOnEndpoint"
        }
    }
}

$SqlAdministratorCredential = Get-Credential -Message "Enter credentials for SQL Server administrator account"

SQLAlwaysOnNodeConfig `
    -SqlAdministratorCredential $SqlAdministratorCredential `
    -ConfigurationData $ConfigData `
    -OutputPath 'C:\Configuration'
