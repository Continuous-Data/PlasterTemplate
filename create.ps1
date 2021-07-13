

$dependantModules=@('PSDepends', 'Plaster')

$ModuleName = 'lollercopter'
$TargetDirectory = 'C:\testoutput\test'


Foreach ($Module in $DependentModules){
    If (-not (Get-Module $module -ListAvailable)){
        Install-Module -name $Module -Scope CurrentUser -Force
    }
    Import-Module $module -ErrorAction Stop
}

$Helpermodulesfolder = "$psscriptroot\TemplateFolders\Helpermodules\"

if ((Get-ChildItem $Helpermodulesfolder -Recurse)) {
    Remove-Item "$Helpermodulesfolder\*" -Recurse -Force
}

Invoke-PSDepend -path "$psscriptroot\Plaster.depend.psd1" -Install -Force -Verbose

Invoke-Plaster -TemplatePath . -DestinationPath $TargetDirectory -Verbose -Name $ModuleName

if ((Get-ChildItem $Helpermodulesfolder -Recurse)) {
    Remove-Item "$Helpermodulesfolder\*" -Recurse -Force
}