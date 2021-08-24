#requires -Modules InvokeBuild, Buildhelpers, PSScriptAnalyzer, Pester, PSDeploy, PlatyPS

$script:ModuleName = 'TemplateName'
$Script:Author = 'TemplateAuthor'
$Script:CompanyName = 'TemplateCompany'
$script:Source = Join-Path $BuildRoot Source

$script:FunctionSource = Join-Path $Source functions
[array]$script:publicfunctionfiles = Get-ChildItem "$FunctionSource\public" -Filter *.ps1 -File
[array]$script:privatefunctionfiles = Get-ChildItem "$FunctionSource\private" -Filter *.ps1 -File
[array]$script:allfunctionfiles += $script:publicfunctionfiles + $script:privatefunctionfiles

$script:ClassSource = Join-Path $Source classes

$script:TestRoot = Join-Path $BuildRoot 'Tests'
$script:UnitTestPath = Join-Path $script:TestRoot "Unit" 
$script:FunctionTestsPath = Join-Path $script:UnitTestPath 'functions'
$script:FunctionTestFiles = Get-ChildItem $script:FunctionTestsPath -Filter *.Tests.ps1 -file -Recurse

$script:DocPath =  Join-Path $BuildRoot "docs\functions"

$script:Output = Join-Path $BuildRoot BuildOutput
$script:Destination = Join-Path $Output $ModuleName
$script:ModulePath = "$Destination\$ModuleName.psm1"
$script:ManifestPath = "$Destination\$ModuleName.psd1"
#$script:Imports = ( 'Private','Public' ) #not used. check if we can use

# importing Dependency bootstrapper

. "$BuildRoot\Helpermodules\$script:ModuleName.BootStrapDependencies.ps1"

task Default Clean, BuildModule, AnalyzeErrors, ResolveDependencies, CreateUpdatePesterTests, Pester, CreateUpdateExportDocs
task CreateUpdateExportDocs CreateUpdateDocs, ExportDocs
task Pester {ImportModule}, Test, {uninstall}
Task CreateUpdateDocs {ImportModule}, CreateUpdateDocsMarkdown, {uninstall}
Task ResolveDependencies DownloadDependencies, ImportDependencies

task CICD Clean, BuildModule, AnalyzeErrors, ResolveDependencies, Pester, UpdateVersion, ExportDocs, {Uninstall}
task CICDSctrict Clean, BuildModule, Analyze, ResolveDependencies, Pester, UpdateVersion, ExportDocs, {Uninstall}

Task Clean {
    If(Get-Module $moduleName){
        Remove-Module $moduleName
    }
    If(Test-Path $Output){
        $null = Remove-Item $Output -Recurse -ErrorAction Ignore
    }
}

task AnalyzeErrors {
    $scriptAnalyzerParams = @{
        Path = $Destination
        Severity = @('Error')
        Recurse = $true
        Verbose = $false
        #ExcludeRule = 'PSUseDeclaredVarsMoreThanAssignments'
    }

    $saResults = Invoke-ScriptAnalyzer @scriptAnalyzerParams

    if ($saResults) {
        $saResults | Format-Table
        throw "One or more PSScriptAnalyzer errors/warnings where found."
    }
}

task Analyze {
    $scriptAnalyzerParams = @{
        Path = $Destination
        Severity = @('Warning','Error')
        Recurse = $true
        Verbose = $false
        #ExcludeRule = 'PSUseDeclaredVarsMoreThanAssignments'
    }

    $saResults = Invoke-ScriptAnalyzer @scriptAnalyzerParams

    if ($saResults) {
        $saResults | Format-Table
        throw "One or more PSScriptAnalyzer errors/warnings where found."
    }
}

# CodeCoverage is a WIP and not used.
task CodeCoverage {

    $testfiles = Get-ChildItem $script:TestRoot -Filter *.Tests.ps1 -file
    
    if (!($testfiles -eq $null)) {
        $invokePesterParams = @{
            Passthru = $true
            Verbose = $false
            EnableExit = $true
            OutputFile = 'Test-results.xml'
            OutputFormat = 'NunitXML'
            Path = $script:TestRoot  
        }
    
        $testResults = Invoke-Pester @invokePesterParams
    
        $numberFails = $testResults.FailedCount
        assert($numberFails -eq 0) ('Failed "{0}" unit tests.' -f $numberFails)
        
    }else{
        Write-Warning "No *.Tests.ps1 files found in [$script:TestRoot]. Pester cannot run without it. Please create unit tests (or disable pester if you must)"
    }

    
}

task Test {

    $testfiles = Get-ChildItem $script:TestRoot -Filter *.Tests.ps1 -file -recurse
    
    if (!($testfiles -eq $null)) {
        $invokePesterParams = @{
            Passthru = $true
            Verbose = $false
            EnableExit = $true
            OutputFile = 'Test-results.xml'
            OutputFormat = 'NunitXML'
            Path = $script:TestRoot  
        }
    
        $testResults = Invoke-Pester @invokePesterParams
    
        $numberFails = $testResults.FailedCount
        assert($numberFails -eq 0) ('Failed "{0}" unit tests.' -f $numberFails)
        
    }else{
        Write-Warning "No *.Tests.ps1 files found in [$script:TestRoot]. Pester cannot run without it. Please create unit tests (or disable pester if you must)"
    }
}

task UpdateVersion {
    try 
    {
        #$moduleManifestFile = ((($ManifestPath -split '\\')[-1] -split '\.')[0]+'.psd1')
        $manifestContent = Get-Content $ManifestPath -Raw
        [version]$version = [regex]::matches($manifestContent,"ModuleVersion\s=\s\'(?<version>(\d+\.)?(\d+\.)?(\*|\d+))") | ForEach-Object {$_.groups['version'].value}
        $newVersion = "{0}.{1}.{2}" -f $version.Major, $version.Minor, $ENV:Build_BuildID

        $replacements = @{
            "ModuleVersion = '.*'" = "ModuleVersion = '$newVersion'"            
        }

        $replacements.GetEnumerator() | ForEach-Object {
            $manifestContent = $manifestContent -replace $_.Key,$_.Value
        }
        
        $manifestContent | Set-Content -Path "$ManifestPath"
    }
    catch
    {
        Write-Error -Message $_.Exception.Message
        $host.SetShouldExit($LastExitCode)
    }
}

Function ImportModule {
    if ( -Not ( Test-Path $ManifestPath ) )
    {
        "  Modue [$ModuleName] is not built, cannot find [$ManifestPath]"
        Write-Error "Could not find module manifest [$ManifestPath]. You may need to build the module first"
    }
    else
    {
        if (Get-Module $ModuleName)
        {
            "  Unloading Module [$ModuleName] from previous import"
            Remove-Module $ModuleName
        }
        "  Importing Module [$ModuleName] from [$ManifestPath]"
        Import-Module $ManifestPath -Force
    }
}

function Uninstall {
    'Unloading Modules...'
    Get-Module -Name $ModuleName -ErrorAction 'Ignore' | Remove-Module

    'Uninstalling Module packages...'
    $modules = Get-Module $ModuleName -ErrorAction 'Ignore' -ListAvailable
    foreach ($module in $modules)
    {
        Uninstall-Module -Name $module.Name -RequiredVersion $module.Version -ErrorAction 'Ignore'
    }

    'Cleaning up manually installed Modules...'
    $path = $env:PSModulePath.Split(';').Where( {
            $_ -like 'C:\Users\*'
        }, 'First', 1)

    $path = Join-Path -Path $path -ChildPath $ModuleName
    if ($path -and (Test-Path -Path $path))
    {
        'Removing files... (This may fail if any DLLs are in use.)'
        Get-ChildItem -Path $path -File -Recurse |
            Remove-Item -Force | ForEach-Object 'FullName'

        'Removing folders... (This may fail if any DLLs are in use.)'
        Remove-Item $path -Recurse -Force
    }
}

task Publish {
    Invoke-PSDeploy -Path $PSScriptRoot -Force
}

Task ExportDocs {
    New-ExternalHelp $DocPath -OutputPath "$destination\en-US"
}

Task CreateUpdateDocsMarkdown {
    
    If(-not (Test-Path $DocPath)){
        "Creating Documents path: $DocPath"
        $null = New-Item -Type Directory -Path $DocPath -ErrorAction Ignore
    }

    "Creating new markdown files if any"
    New-MarkdownHelp -Module $modulename -OutputFolder $docpath -ErrorAction SilentlyContinue
    "Updating existing markdown files"
    Update-MarkdownHelp $docpath

}

function New-Psmfile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string][ValidateSet('function','class')]
        $sourcecodetype,
        # Parameter help description
        [Parameter(Mandatory=$true)]
        [array]
        $Inputfiles,
        # Parameter help description
        [Parameter(Mandatory=$true)]
        [string]
        $destinationfile
    )

    begin{
        $regex = "(^$sourcecodetype\s*)(\S*)(\s*{?)"
        [array]$functionnames = @()
    }
    
    process{
        ForEach($file in $Inputfiles) {
            [array]$MatchedRegex = @()
            $file = Get-Content $file.FullName 
            $file | Out-File "$destinationfile" -Append -Encoding utf8
            $file | ForEach-Object{
                $MatchedRegex += [regex]::Matches($_,$regex)   
            }
            $MatchedRegex | ForEach-Object{
                [array]$Entitynames += $_.groups[2].value
            }
        }

        if ($Entitynames.count -gt 0) {
            $dif = Compare-Object -ReferenceObject $Inputfiles.BaseName -DifferenceObject $Entitynames -PassThru
            if($dif){
                Remove-Item $destinationfile -Force
                
                Write-Host "There is a discrepancy between filenames of functions and actual function names. These must be equal"
                Write-Host "DIFF:"
                $dif | Format-Table
                Write-Host "FunctionNames:"
                $Entitynames | Format-Table
                Write-Host "Filenames:"
                $Inputfiles.Name | Format-Table
                Write-Error "BUILD FAILED. Cannot Continue if files and functions do not match"
            }else{
                Write-Host "function / Naming Convention integrity successfull. PSM1 has been built"
            }
        }
    }

    end{

    }
}

task BuildModule {
    If(-not(Test-Path $Destination)){
        New-Item $destination -ItemType Directory
    }

    Write-Host "Starting Module Build"
    Write-Host "Checking function / Naming Convention integrity"
    
    if (!($allfunctionfiles -eq $null)) {
    
        Write-Host "adding functions to powershell module"

        New-Psmfile -sourcecodetype 'function' -Inputfiles $allfunctionfiles -destinationfile "$destination\$moduleName.psm1"
        
        Write-Host "Copying and updating PSD1 file"
        if($publicfunctionfiles){
            $functionstoexport = $publicfunctionfiles.BaseName
        }else{
            $functionstoexport =  ' '
        }
        
        Copy-Item "$Buildroot\$moduleName.psd1" -Destination $destination
    
        $moduleManifestData = @{
            Author = $author
            Copyright = "(c) $((get-date).Year) $companyname. All rights reserved."
            Path = "$destination\$moduleName.psd1"
            FunctionsToExport = $functionstoexport
            RootModule = "$moduleName.psm1"
        }
        
        Update-ModuleManifest @moduleManifestData

        Write-Host "Copying non-empty folders in Source to buildoutput"
        $AdditionalSourceFolders = Get-ChildItem $Source -Directory -Exclude @('functions','classes')
        $AdditionalSourceFolders | ForEach-Object{
            $foldertocheck = "$_"
            if ((Get-ChildItem $foldertocheck)) {
                Copy-Item -Path $foldertocheck -Destination $Destination -Recurse -Force
            }
        }
        
    }else{
        Write-Error "No Function Files! Nothing to build!"
    }
}


function CreatePesterTestFile {
    param (
        # Parameter help description
        [Parameter(Mandatory=$true)]
        [string]
        $Filename,
        # Parameter help description
        [Parameter(Mandatory=$true)]
        [string]
        $rootfolder
    )

    If(-not(Test-Path $rootfolder)){
        New-Item $rootfolder -ItemType Directory -force
    }

    $filetocreate = Join-Path $rootfolder $filename

    if (!(Test-Path $filetocreate)) {
        new-item $filetocreate -Force -ItemType File
    }
    
}

task CreateUpdatePesterTests {

    if (!($allfunctionfiles -eq $null)) {
        foreach ($file in $allfunctionfiles) {
            $parentfolder = Join-Path $FunctionTestsPath $file.Directory.Name
            $filename = "$($file.BaseName).Tests.ps1"
            if (!(Test-path $filename)) {
                CreatePesterTestFile -Filename $filename -rootfolder $parentfolder
            }  
        }
    }

    if (!($FunctionTestFiles -eq $null)) {
        foreach ($file in $FunctionTestFiles) {
            $cleanfunctionfilename = $file.BaseName -replace '\.Tests',''
            if ($cleanfunctionfilename -notin $allfunctionfiles.basename) {
                $newfilename = $file.FullName -replace '\.ps1','.FileOrFunctionRemoved.ps1'
                if (!(Test-Path $newfilename)) {
                    Rename-Item $file.FullName $newfilename -Force
                }
                
            }
        }
    }

}

task DownloadDependencies{

    Resolve-Dependencies -path "$BuildRoot\$script:ModuleName.depend.psd1"

}

task ImportDependencies{
    Import-Dependencies -path "$BuildRoot\$script:ModuleName.depend.psd1"
}
