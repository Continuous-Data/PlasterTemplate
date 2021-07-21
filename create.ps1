

$DependentModules=@('PSDepend', 'Plaster')

$TargetDirectory = 'C:\testoutput\test'

$templatefolder = "$psscriptroot\TemplateFolders"

$Helpermodulesfolder = "$psscriptroot\TemplateFolders\Helpermodules\"

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

##### runPSDepend for getting required modules

Invoke-PSDepend -path "$psscriptroot\Plaster.depend.psd1" -Install -Force -Verbose

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