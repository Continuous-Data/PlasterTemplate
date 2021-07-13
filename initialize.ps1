$manifestProperties = @{
    Path         = 'C:\Code\GitHub\PlasterTemplate\PlasterManifest.xml'
    TemplateName = 'ScriptModuleTemplate'
    TemplateType = 'Project'
    Author       = 'Tobi Steenbakkers'
    Description  = 'Scaffolds the files required for a PowerShell script module'
    Tags         = 'PowerShell, Module, ModuleManifest'
}
 
$Folder = Split-Path -Path $manifestProperties.Path -Parent
if (-not(Test-Path -Path $Folder -PathType Container)) {
    New-Item -Path $Folder -ItemType Directory | Out-Null
}
 
New-PlasterManifest @manifestProperties