
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
    }

    Node $AllNodes.Where{ $_.Role -eq "SecondaryReplica" }.NodeName
    {         
        xSQLServerAlwaysOnAvailabilityGroupReplica SQLAddSecondaryReplicaToAvailabilityGroupForSynchronousCommitAndAutomaticFailover
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
        }
    }
}

$SqlAdministratorCredential = Get-Credential -Message "Enter credentials for SQL Server administrator account"

SQLAlwaysOnNodeConfig `
    -SqlAdministratorCredential $SqlAdministratorCredential `
    -ConfigurationData $ConfigData `
    -OutputPath 'C:\Configuration'
