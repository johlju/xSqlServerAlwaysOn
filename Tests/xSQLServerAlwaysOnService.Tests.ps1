$moduleName = "xSQLServerAlwaysOnService"
$moduleHelperName = "xSqlServerAlwaysOnUtil"
$modulePath = (Join-Path $PSScriptRoot -ChildPath "..\DSCResources\$moduleName\$moduleName.psm1")
Import-Module $modulePath -Force

$ErrorActionPreference = 'Stop' 
Set-StrictMode -Version latest 

Describe $moduleName {
    Context "Testing if SQLPS module exist" {
        Mock Import-SQLPSModule -ModuleName $moduleHelperName -Verifiable -MockWith {
            throw "Module SQLPS not found"
        }

        It "Get throws an exception if module SQLPS does not exist" {
            { Get-TargetResource -NodeName "localhost" -InstanceName "MSSQLSERVER" } | Should Throw
        }

        It "Set throws an exception if module SQLPS does not exist" {
            { Set-TargetResource -NodeName "localhost" -InstanceName "MSSQLSERVER" } | Should Throw
        }

        It "Test throws an exception if module SQLPS does not exist" {
            { Test-TargetResource -NodeName "localhost" -InstanceName "MSSQLSERVER" } | Should Throw
        }

        Assert-MockCalled Import-SQLPSModule -ModuleName $moduleHelperName
        Assert-VerifiableMocks
    }

    Context "The SQL Server instance does not exist" {
        Mock Get-SQLAlwaysOnState -ModuleName $moduleName -Verifiable -MockWith { 
            throw "SQL Service instance not found"
        }

        It "Get throws an exception if NodeName is wrong" {
            { Get-TargetResource -NodeName "localhost2" -InstanceName "MSSQLSERVER" } | Should Throw
        }

        It "Set throws an exception if NodeName is wrong" {
            { Set-TargetResource -NodeName "localhost2" -InstanceName "MSSQLSERVER" } | Should Throw
        }

        It "Test throws an exception if NodeName is wrong" {
            { Test-TargetResource -NodeName "localhost2" -InstanceName "MSSQLSERVER" } | Should Throw
        }
        
        It "Get throws an exception if InstanceName is wrong" {
            { Get-TargetResource -NodeName "localhost" -InstanceName "Dummy" } | Should Throw
        }

        It "Set throws an exception if InstanceName is wrong" {
            { Set-TargetResource -NodeName "localhost" -InstanceName "Dummy" } | Should Throw
        }

        It "Test throws an exception if InstanceName is wrong" {
            { Test-TargetResource -NodeName "localhost" -InstanceName "Dummy" } | Should Throw
        }

        Assert-MockCalled Get-SQLAlwaysOnState -ModuleName $moduleName -Exactly 6
        Assert-VerifiableMocks 
    } 

    Context "AlwaysOn state cannot be determined" {
        Mock Get-SQLAlwaysOnState -ModuleName $moduleName -Verifiable -MockWith { 
            return $Null
        }

        It "Get throws an exception if missing IsHadrEnable column" {
            { Get-TargetResource -NodeName "localhost" -InstanceName "MSSQLSERVER" } | Should Throw
        }

        It "Set throws an exception if missing IsHadrEnable column" {
            { Set-TargetResource -NodeName "localhost" -InstanceName "MSSQLSERVER" } | Should Throw
        }

        It "Test throws an exception if missing IsHadrEnable column" {
            { Test-TargetResource -NodeName "localhost" -InstanceName "MSSQLSERVER" } | Should Throw
        }

        Assert-MockCalled Get-SQLAlwaysOnState -ModuleName $moduleName
        Assert-VerifiableMocks 
    }

    # TODO: This shouldn't be neccessary to test the Set-TargetResource
    # START Was not able to Mock these functions without faking the entire module.
    # Should use a stub module instead
    Get-Module -Name SQLPS | Remove-Module
    New-Module -Name SQLPS  -ScriptBlock {
        function Disable-SqlAlwaysOn { return }
        function Enable-SqlAlwaysOn { return }
    
        Export-ModuleMember -Function Disable-SqlAlwaysOn,Enable-SqlAlwaysOn
    } | Import-Module -Force
    # END

    Context "AlwaysOn are enabled" {
        Mock Get-SQLAlwaysOnState -ModuleName $moduleName -Verifiable -MockWith { 
            return $True
        }

        It "Get returns Present if enabled" {
            $hashTable = Get-TargetResource -NodeName "localhost" -InstanceName "MSSQLSERVER" 
            $state = $hashTable.Ensure 
            $state | Should BeExactly "Present"
            Assert-MockCalled Get-SQLAlwaysOnState -ModuleName $moduleName
        }

        InModuleScope -ModuleName $moduleName {
            Mock Disable-SqlAlwaysOn 
            Mock Enable-SqlAlwaysOn 
        
            It "Set changes state to Absent only if Ensure is set to Absent and current state is Present" {
                { Set-TargetResource -Ensure Absent -NodeName "localhost" -InstanceName "MSSQLSERVER" } | Should Not Throw
                Assert-MockCalled Disable-SqlAlwaysOn -Exactly 1
                Assert-MockCalled Enable-SqlAlwaysOn -Exactly 0
            }
        }

        It "Test returns true if current state is Present" {
            $result = Test-TargetResource -Ensure Present -NodeName "localhost" -InstanceName "MSSQLSERVER"
            $result | Should Be $True
        }

        Assert-VerifiableMocks 
    } 
    
    Context "AlwaysOn are disabled" {
        Mock Get-SQLAlwaysOnState -ModuleName $moduleName -Verifiable -MockWith { 
            return $False
        }

        It "Get returns Absent if enabled" {
            $hashTable = Get-TargetResource -NodeName "localhost" -InstanceName "MSSQLSERVER" 
            $state = $hashTable.Ensure 
            $state | Should BeExactly "Absent"
            Assert-MockCalled Get-SQLAlwaysOnState -ModuleName $moduleName
        }

        InModuleScope -ModuleName $moduleName {
            Mock Disable-SqlAlwaysOn 
            Mock Enable-SqlAlwaysOn
        
            It "Set changes state to Present only if Ensure is set to Present and current state is Absent" {
                { Set-TargetResource -Ensure Present -NodeName "localhost" -InstanceName "MSSQLSERVER" } | Should Not Throw
                Assert-MockCalled Enable-SqlAlwaysOn -Exactly 1
                Assert-MockCalled Disable-SqlAlwaysOn -Exactly 0
            }
        }

        It "Test returns true if current state is Absent" {
            $result = Test-TargetResource -Ensure Absent -NodeName "localhost" -InstanceName "MSSQLSERVER"
            $result | Should Be $True
        }

        Assert-VerifiableMocks 
    }
}

