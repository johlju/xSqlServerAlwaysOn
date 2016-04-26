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
        xSQLServerAlwaysOnAvailabilityGroup AvailabilityGroupForSynchronousCommitAndAutomaticFailover
        {
            Ensure = "Present"
            NodeName = $Node.NodeName
            InstanceName = $Node.SqlInstanceName
            Name = "AG-01"
            AvailabilityMode = 'SynchronousCommit'
            FailoverMode = 'Automatic'

            PsDscRunAsCredential = $SqlAdministratorCredential
        }

        xSQLServerAlwaysOnAvailabilityGroupListner AvailabilityGroupForSynchronousCommitAndAutomaticFailoverListner
        {
            Ensure = "Present"
            NodeName = $Node.NodeName
            InstanceName = $Node.SqlInstanceName
            AvailabilityGroup = "AG-01"
            Name = "AG-01"
            IpAddress = "192.168.0.73/255.255.255.0"
            Port = 5304

            PsDscRunAsCredential = $SqlAdministratorCredential
            
            DependsOn = "[xSQLServerAlwaysOnAvailabilityGroup]AvailabilityGroupForSynchronousCommitAndAutomaticFailover"
        }

        xSQLServerAlwaysOnAvailabilityGroup AvailabilityGroupForAsynchronousCommitAndManualFailover
        {
            Ensure = "Present"
            NodeName = $Node.NodeName
            InstanceName = $Node.SqlInstanceName
            Name = "AvailabilityGroup-02"
            AvailabilityMode = 'AsynchronousCommit'
            FailoverMode = 'Manual'

            PsDscRunAsCredential = $SqlAdministratorCredential
        }
        
        xSQLServerAlwaysOnAvailabilityGroupListner AvailabilityGroupForAsynchronousCommitAndManualFailoverListner
        {
            Ensure = "Present"
            NodeName = $Node.NodeName
            InstanceName = $Node.SqlInstanceName
            AvailabilityGroup = "AvailabilityGroup-02"
            Name = "AG-02"
            IpAddress = "192.168.0.74/255.255.255.0"
            Port = 5301

            PsDscRunAsCredential = $SqlAdministratorCredential
            
            DependsOn = "[xSQLServerAlwaysOnAvailabilityGroup]AvailabilityGroupForAsynchronousCommitAndManualFailover"
        }

        # Remove listners which was added above
        
        xSQLServerAlwaysOnAvailabilityGroupListner RemoveAvailabilityGroupForSynchronousCommitAndAutomaticFailoverListner
        {
            Ensure = "Absent"
            NodeName = $Node.NodeName
            InstanceName = $Node.SqlInstanceName
            AvailabilityGroup = "AG-01"
            Name = "AG-01"

            PsDscRunAsCredential = $SqlAdministratorCredential
            
            DependsOn = "[xSQLServerAlwaysOnAvailabilityGroupListner]AvailabilityGroupForSynchronousCommitAndAutomaticFailoverListner"
        }

        xSQLServerAlwaysOnAvailabilityGroupListner RemoveAvailabilityGroupForAsynchronousCommitAndManualFailoverListner
        {
            Ensure = "Absent"
            NodeName = $Node.NodeName
            InstanceName = $Node.SqlInstanceName
            AvailabilityGroup = "AvailabilityGroup-02"
            Name = "AG-02"

            PsDscRunAsCredential = $SqlAdministratorCredential
            
            DependsOn = "[xSQLServerAlwaysOnAvailabilityGroupListner]AvailabilityGroupForAsynchronousCommitAndManualFailoverListner"
        }
        
    }

    Node $AllNodes.Where{ $_.Role -eq "SecondaryReplica" }.NodeName
    {         
    }
}

$SqlAdministratorCredential = Get-Credential -Message "Enter credentials for SQL Server administrator account"

SQLAlwaysOnNodeConfig `
    -SqlAdministratorCredential $SqlAdministratorCredential `
    -ConfigurationData $ConfigData `
    -OutputPath 'C:\Configuration'
