$Modulename = 'Templatename'

$HelperModulesFolder = "$PSScriptRoot\HelperModules"

. "$HelperModulesFolder\$Modulename.BootstrapDependencies.ps1"

Get-DependentModule -modulename 'PSDepend' -downloadpath "$HelperModulesFolder"

if (Get-Module 'PSDepend') {
    Resolve-Dependencies -path $HelperModulesFolder
    Import-Dependencies -path "$HelperModulesFolder\HelperModules.depend.psd1"
}