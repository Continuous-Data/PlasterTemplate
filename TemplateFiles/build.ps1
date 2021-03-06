[cmdletbinding()]
param(
    [string[]]$Task = 'default',
    [string[]]$ModuleName = 'TemplateName'
)

$DependentModules = @('InvokeBuild', 'Buildhelpers', 'PSScriptAnalyzer', 'Pester', 'PSDeploy', 'PlatyPS') # add pester when pester tests are added
Foreach ($Module in $DependentModules){
    If (-not (Get-Module $module -ListAvailable)){
        Install-Module -name $Module -Scope CurrentUser -Force
    }
    Import-Module $module -ErrorAction Stop
}
# Builds the module by invoking psake on the build.psake.ps1 script.
Invoke-Build "$PSScriptRoot\$modulename.build.ps1" -Task $Task