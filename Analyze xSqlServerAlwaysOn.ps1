Import-Module PSScriptAnalyzer

Invoke-ScriptAnalyzer -Path ( Split-Path -Parent $MyInvocation.MyCommand.Path ) -Recurse | Sort-Object ScriptName | Select-Object ScriptName, Line, Message
