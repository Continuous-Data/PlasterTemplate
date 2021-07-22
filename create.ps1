$TargetDirectory = 'C:\testoutput\test'

$templatefolder = "$psscriptroot\TemplateFolders"

$Helpermodulesfolder = "$PSScriptRoot\TemplateFolders\Helpermodules\"

. "$PSScriptRoot\TemplateFiles\Template.BootStrapDependencies.ps1"

Get-DependentModule -modulename 'Plaster' -downloadpath "$PSScriptRoot\TempModuleDownloadFolder"

#### Bootstrap required modules for creating the scaffold
Foreach ($Module in $DependentModules){
    If (-not (Get-Module $module -ListAvailable)){
        Install-Module -name $Module -Scope CurrentUser -Force
    }
    Import-Module $module -ErrorAction Stop
}

#removing the .keep files used to store the folder structure in git
$keepfiles = Get-ChildItem $templatefolder -File -Filter '.keep' -Recurse

if ($keepfiles) {
    $keepfiles | ForEach-Object{
        Remove-Item $_.FullName -Force | Out-Null
    }
}

######## Clean the helpermodules folder (will become obsolete once PSDepend is part of build)
if ((Get-ChildItem $Helpermodulesfolder -Recurse)) {
    Remove-Item "$Helpermodulesfolder\*" -Recurse -Force | Out-Null
}



#####create scaffold
Invoke-Plaster -TemplatePath . -DestinationPath $TargetDirectory -Verbose

######## Clean the helpermodules folder (will become obsolete once PSDepend is part of build)
if ((Get-ChildItem $Helpermodulesfolder -Recurse)) {
    Remove-Item "$Helpermodulesfolder\*" -Recurse -Force | Out-Null
}

# add .keep files again to templatefolderstructure
$templatefolders = Get-ChildItem $templatefolder -Directory -Recurse

if ($templatefolders) {
    $templatefolders | ForEach-Object{
        # $_.FullName
        New-Item -Path $_.FullName -Name '.keep' -ItemType 'file' -Force | Out-Null
    }
}