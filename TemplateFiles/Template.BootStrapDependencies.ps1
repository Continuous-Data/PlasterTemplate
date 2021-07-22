function Get-DependentModule {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $modulename,
        [Parameter(Mandatory=$true)]
        [string]
        $downloadpath
    )

    $modulenamepath = "$downloadpath\$modulename"

    if (!(Test-Path $modulenamepath)) {
        If (-not (Get-Module $modulename -ListAvailable)){
            if (!(Test-Path $downloadpath)) {
                New-Item -path $downloadpath -ItemType 'Directory' -Force
            }
            Find-Module -Name $modulename | Save-Module -Path $downloadpath -Force
            Import-Module -name $modulenamepath -ErrorAction Stop
        }else{
            Import-Module -name $modulename -ErrorAction Stop
        }
    }else{
        If (-not (Get-Module $modulename)){
            Import-Module -name $modulenamepath -ErrorAction Stop
        }else{
            Remove-Module -name $modulename
            Import-Module -name $modulenamepath -ErrorAction Stop
        }
    }    
}

function Resolve-Dependencies {
    param (
        # Parameter help description
        [Parameter(Mandatory=$true)]
        $path
    )

    ##### runPSDepend for getting required modules

    Invoke-PSDepend -path $path -Install -Force -Verbose
    
}

function Import-Dependencies {
    param (
        # Parameter help description
        [Parameter(Mandatory=$true)]
        $path
    )
    $Dependencies = Get-Dependency -Path $path
    
    if ($Dependencies) {
        $Dependencies | ForEach-Object{
            if ($_.dependencyName -ne 'PSDepend') {
                if (Get-Module $_.dependencyName) {
                    Remove-Module $_.dependencyName
                }
            }
        }
    
        $Dependencies | Import-Dependency -Verbose
    }else{
        Write-Host "No Dependencies to import"
    }
    

}