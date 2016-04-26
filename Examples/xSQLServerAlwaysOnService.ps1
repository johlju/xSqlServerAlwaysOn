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
        [PsCredential]$SqlInstallCredential
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xSqlServerAlwaysOn -ModuleVersion 1.0.0.0

    Node $AllNodes.Where{$_.Role -eq "PrimaryReplica" }.NodeName
    {
        # Enable AlwaysOn
        xSQLServerAlwaysOnService SQLConfigureAlwaysOnService
        {
            Ensure = "Present"
            NodeName = $Node.NodeName
            InstanceName = $Node.SqlInstanceName

            PsDscRunAsCredential = $SqlInstallCredential
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

        # Disable AlwaysOn 
        xSQLServerAlwaysOnService RemoveSQLConfigureAlwaysOnService
        {
            Ensure = "Absent"
            NodeName = $Node.NodeName
            InstanceName = $Node.SqlInstanceName
            
            PsDscRunAsCredential = $SqlInstallCredential

            DependsOn = "[Service]SQLServerAgentServiceStarted"
        }
    }

    Node $AllNodes.Where{ $_.Role -eq "SecondaryReplica" }.NodeName
    {         
        # Enable AlwaysOn
        xSQLServerAlwaysOnService SQLConfigureAlwaysOnService
        {
            Ensure = "Present"
            NodeName = $Node.NodeName
            InstanceName = $Node.SqlInstanceName
            
            PsDscRunAsCredential = $SqlInstallCredential
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

        # Disable AlwaysOn 
        xSQLServerAlwaysOnService RemoveSQLConfigureAlwaysOnService
        {
            Ensure = "Absent"
            NodeName = $Node.NodeName
            InstanceName = $Node.SqlInstanceName
            
            PsDscRunAsCredential = $SqlInstallCredential

            DependsOn = "[Service]SQLServerAgentServiceStarted"
        }
    }
}

$SqlInstallCredential = Get-Credential -Message "Enter credentials for SQL Server administrator account"

SQLAlwaysOnNodeConfig `
    -SqlAdministratorCredential $SqlInstallCredential `
    -ConfigurationData $ConfigData `
    -OutputPath 'C:\Configuration'
