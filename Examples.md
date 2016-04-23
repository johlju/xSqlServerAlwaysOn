# Examples
## Complete example prerequisites
In `Examples\Full_Example.ps1` you find a complete example for setting up a three node HA kluster with Always On. 
For this example to work, some prerequisites must be in place

### Active Directory
An Active Directory domain must be available and with a working DNS. In the example the domain are named company.local with a NetBios name of COMPANY.

### Servers
- Three servers installed with Windows Server 2012 R2. 
 - with working network, and (at least) with an IP-address in the same subnet as the Cluster Name Object (CNO) will be configured.
 - and joined to the domain.
 - also with the certificate imported which must be used to decrypt credentials (see Certificates).  
- One file server that can present a network share used for the witness share.
- One file server that can present a network share where all the media are located.
- one server from where configuration are pushed (the deploy server). 

Node (FQDN) | Purpose
--- | ---
sqlnode01.company.local | Primary replica
sqlnode02.company.local | Secondary replica
sqlnode03.company.local | Secondary replica
witness.company.local | Holds the witness share for the cluster. 
files.company.local | Holds the share with all the media.
deploy.company.local | Holds the configuration and used to push the configuration

> *Note: The servers witness, files and deploy can all be the same server. The servers not part of the example are not listed, such as the Active Directory servers.*

### Domain accounts
This can all be the same account, but different account are used to show a more complex example (and more how it could look in production)

Domain account | Prerequisites permissions/rights | These permissions/rights are configured by DSC (listed here for information)
--- | --- | ---
Cluster Administrator | Must have local administrator right on all the nodes. | -
SQL Install |  Must have local administrator right on all the nodes, also needs to have read access to the share where the SQL Server installation media are staged. | - 
SQL Administrator | - | Must have sysadmin rights to the SQL Server instances. | -
SQL Service Primary | Normal domain user account with no special rights. | The account must have login right and connect permission to the endpoint on each SQL instance in the Always On HA. 
SQL Service Secondary | Normal domain user account with no special rights.| 

### Active Directory Organizational Unit
OU | Description | Security
--- | --- | ---
Cluster Computer Objects | Organizational unit where CNO's are prestaged and VCO will be automatically created by CNO's. | The security group **Create Cluster Virtual Computer Objects** must have the permission **Create Computer Objects**. 

### Prestaged computer accounts
The staged account must be left disable for Failover CLustering to be able to use the account (otherwise FC can not determine if account is used or not).

Computer Object | Active Directory Organizational Unit
--- | ---
SQLCLU01 | Cluster Computer Objects   

> *Note: See article https://technet.microsoft.com/en-us/library/dn466519.aspx for more information about prestaging.*

### Domain groups
Domain security group | Members | Permssion
--- | --- | ---
Create Cluster Virtual Computer Objects | SQLCLU01 | The group must have permission to **Create Computer Objects** on the Active Directory organizational unit **Cluster Computer Objects**. 
SQL Administrators | *your personal administrator account* | Used by DSC to give additional administrator sysadmin permission on the SQL instances. 

### Certificates
A certificate is needed to encrypt the credentials in the DSC configuration .mof file. The certificate must be imported to the Local Machine\Personal store on each node.
And the public certificate needs to be exported and placed in a folder on the push server. The path to the public certificate must be set in the configuration, as well as the thumbprint for the certificate.  

>The encryption certificate must contain the `Data Encipherment` or `Key Encipherment` key usage, and include the `Document Encryption Enhanced Key Usage (1.3.6.1.4.1.311.80.1)`.
>For more information on securing credentials in MOF file, please refer to MSDN blog: http://go.microsoft.com/fwlink/?LinkId=393729

### Shares
#### \\\files.company.local\media
**Folder structure under share:** See table below

Folder name | Permission | Contains
--- | --- | ---
SQL2014SP1 | SQL Install must have read permission | SQL Server 2014 installation media
Win2k12R2\Sources\Sxs | Everyone must have read permission. *Note: Realized now, at the time of writing this, that I never check what permssion is actually needed* | sxs folder from the Windows Server 2012 R2 installation media.
Modules | Everyone must have read permission. *Note: I haven't gotten LCM Credential property to work in Push mode yet* | The required modules needed for the configuration. 

#### \\\witness.company.local\clusterwitness$
**Folder structure under share:** None

 **Permission:** Give the domain security group Create Cluster Virtual Computer Objects the permission full control to the file security on the root folder as well as the share permission. 

*Note: Cluster CNO will create a folder under the root folder which will be used for the witness*

### Modules
Beside the obvious module xSqlServerAlwaysOn, the following modules are needed. Download the modules from GitHub. 

Module | Version | URL
--- | --- | ---
xSqlServer | 1.5.0.0 | Find it here https://github.com/PowerShell/xSQLServer
xFailOverCluster | 1.1.1 |  Find it here https://github.com/PowerShell/xFailOverCluster. 

> *Note: at the time of writing this module, there was no support for witness share, but thanks to @claudiospizzi who developed the functionality into his fork I was able to get a cluster with witness share (I did some modifications thou).*
> *Recently he has PR to the xFailoverCluster so soon we might enjoy that functionality in the main repository.*
> *You can find @claudiospizzi's branch here https://github.com/claudiospizzi/xFailOverCluster/tree/xClusterQuorum*

### Firewall
For a secondary replica to join an availability group on the primary replica, the secondary replica must be allowed to connect to the primary replica thru firewalls.
