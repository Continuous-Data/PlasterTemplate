#requires -Modules InvokeBuild, Buildhelpers, PSScriptAnalyzer, Pester, PSDeploy, PlatyPS

$script:ModuleName = 'TemplateName'
$Script:Author = 'TemplateAuthor'
$Script:CompanyName = 'TemplateCompany'
$script:Source = Join-Path $BuildRoot Source

$script:Output = Join-Path $BuildRoot BuildOutput
$script:DocPath =  Join-Path $BuildRoot "docs\functions"
$script:TestRoot = Join-Path $BuildRoot 'Tests\Unit'
$script:Destination = Join-Path $Output $ModuleName
$script:ModulePath = "$Destination\$ModuleName.psm1"
$script:ManifestPath = "$Destination\$ModuleName.psd1"
$script:Imports = ( 'Private','Public' ) #not used. check if we can use

task Default Clean, BuildModule, AnalyzeErrors, CreateUpdatePesterTests, Pester, CreateUpdateExportDocs
task CreateUpdateExportDocs CreateUpdateDocs, ExportDocs
task Pester {ImportModule}, Test, {uninstall}
Task CreateUpdateDocs {ImportModule}, CreateUpdateDocsMarkdown, {uninstall}

task CICD Clean, BuildModule, AnalyzeErrors, Pester, UpdateVersion, ExportDocs, {Uninstall}
task CICDSctrict Clean, BuildModule, Analyze, Pester, UpdateVersion, ExportDocs, {Uninstall}

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
        Write-Error "No *.Tests.ps1 files found in [$script:TestRoot]. Pester cannot run without it. Please create unit tests (or disable pester if you must)"
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
        Write-Error "No *.Tests.ps1 files found in [$script:TestRoot]. Pester cannot run without it. Please create unit tests (or disable pester if you must)"
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

task BuildModule {
    $pubFiles = Get-ChildItem "$Source\public" -Filter *.ps1 -File
    $privFiles = Get-ChildItem "$Source\private" -Filter *.ps1 -File
    [array]$allfiles = $pubFiles
    [array]$allfiles += $privFiles

    If(-not(Test-Path $Destination)){
        New-Item $destination -ItemType Directory
    }

    if (!($allfiles -eq $null)) {
        ForEach($file in $allfiles) {
            Get-Content $file.FullName | Out-File "$destination\$moduleName.psm1" -Append -Encoding utf8
        }

        if ((Get-ChildItem "$destination\$moduleName.psm1")) {
            $psmfile = Get-Content "$destination\$moduleName.psm1"
            $regex = '(^function\s*)(\S*)(\s*{?)'
            $MatchedRegex = [regex]::Matches($psmfile,$regex)
            $MatchedRegex | ForEach-Object{
                [array]$functionnames += $_.groups[2].value
            }
        }
    
        if ($Functionnames -and $allfiles) {
            $dif = Compare-Object -ReferenceObject $allfiles.BaseName -DifferenceObject $functionnames -PassThru
            if($dif){
                
                Write-Host "There is a discrepancy between filenames of functions and actual function names. These must be equal"
                Write-Host "DIFF:"
                $dif | Format-Table
                Write-Host "FunctionNames:"
                $functionnames | Format-Table
                Write-Host "Filenames:"
                $allfiles.Name | Format-Table
                Write-Error "BUILD FAILED. Cannot Continue if files and functions do not match"
            }
        }
    
        if($pubfiles){
            $functionstoexport = $pubFiles.BaseName
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

    $pubFiles = Get-ChildItem "$Source\public" -Filter *.ps1 -File
    $privFiles = Get-ChildItem "$Source\private" -Filter *.ps1 -File
    $testfiles = Get-ChildItem $script:TestRoot -Filter *.Tests.ps1 -file -Recurse

    [array]$allfiles = $pubFiles
    [array]$allfiles += $privFiles

    if (!($allfiles -eq $null)) {
        foreach ($file in $allfiles) {
            $parentfolder = Join-Path $script:TestRoot ($file.DirectoryName | Split-Path -Leaf)
            $filename = "$($file.BaseName).Tests.ps1"
            CreatePesterTestFile -Filename $filename -rootfolder $parentfolder
        }
    }

    if (!($testfiles -eq $null)) {
        foreach ($file in $testfiles) {
            if ($file.basename -notin $allfiles.basename) {
                Rename-Item $file.FullName "$($file.basename).FileOrFunctionRemoved.ps1" -Force
            }
        }
    }

}