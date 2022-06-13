﻿function Compare-Testimo {
    [cmdletbinding(DefaultParameterSetName = 'JSON')]
    param(
        [parameter(Mandatory, ParameterSetName = 'Object')]
        [parameter(Mandatory, ParameterSetName = 'JSON')]
        [string] $Name,

        [parameter(ParameterSetName = 'Object')]
        [parameter(ParameterSetName = 'JSON')]
        [parameter()][string] $DisplayName,

        [parameter(Mandatory, ParameterSetName = 'Object')]
        [parameter(Mandatory, ParameterSetName = 'JSON')]
        [string] $Scope,

        [parameter(ParameterSetName = 'Object')]
        [parameter(ParameterSetName = 'JSON')]
        [string] $Category = 'Baseline',

        [parameter(Mandatory, ParameterSetName = 'Object')][Object] $BaseLineSource,
        [parameter(Mandatory, ParameterSetName = 'Object')][Object] $BaseLineTarget,
        [parameter(Mandatory, ParameterSetName = 'JSON')][Object] $BaseLineSourcePath,
        [parameter(Mandatory, ParameterSetName = 'JSON')][Object] $BaseLineTargetPath,

        [parameter(ParameterSetName = 'Object')]
        [parameter(ParameterSetName = 'JSON')]
        [string[]] $ExcludeProperty
    )

    $IsDsc = $false
    if ($PSBoundParameters.ContainsKey("BaseLineSourcePath")) {
        $SourcePath = Get-Item -LiteralPath $BaseLineSourcePath -ErrorAction SilentlyContinue
        $TargetPath = Get-Item -LiteralPath $BaseLineTargetPath -ErrorAction SilentlyContinue
        if (-not $SourcePath -or -not $TargetPath) {
            Out-Informative -Text "Could not find baseline source or target. Invalid path. Skipping source $Name" -Level 0 -Status $null -ExtendedValue $null
            return
        }
        if ($SourcePath.Extension -eq '.json' -and $TargetPath.Extension -eq '.json') {
            $BaseLineSource = Get-Content -LiteralPath $BaseLineSourcePath -Raw | ConvertFrom-Json
            $BaseLineTarget = Get-Content -LiteralPath $BaseLineTargetPath -Raw | ConvertFrom-Json
            @{
                Name            = $Name
                DisplayName     = if ($DisplayName) { $DisplayName } else { $Name }
                Scope           = $Scope
                Category        = $Category
                BaseLineSource  = $BaseLineSource
                BaseLineTarget  = $BaseLineTarget
                ExcludeProperty = $ExcludeProperty
            }
        } elseif ($SourcePath.Extension -eq '.ps1' -and $TargetPath.Extension -eq '.ps1') {
            $IsDsc = $true
            $CommandExists = Get-Command -Name 'ConvertTo-DSCObject' -ErrorAction SilentlyContinue
            if ($CommandExists) {
                $DSCGroups = [ordered] @{}
                $DSCGroupsTarget = [ordered] @{}

                $BaseLineSource = ConvertTo-DSCObject -Path $BaseLineSourcePath
                $BaseLineTarget = ConvertTo-DSCObject -Path $BaseLineTargetPath

                foreach ($DSC in $BaseLineSource) {
                    if (-not $DSCGroups[$DSC.ResourceName]) {
                        $DSCGroups[$DSC.ResourceName] = [System.Collections.Generic.List[PSCustomObject]]::new()
                    }
                    $DSCGroups[$DSC.ResourceName].Add([PSCustomObject] $DSC)
                }
                foreach ($DSC in $BaseLineTarget) {
                    if (-not $DSCGroupsTarget[$DSC.ResourceName]) {
                        $DSCGroupsTarget[$DSC.ResourceName] = [System.Collections.Generic.List[PSCustomObject]]::new()
                    }
                    $DSCGroupsTarget[$DSC.ResourceName].Add([PSCustomObject] $DSC)
                }

                foreach ($Source in $DSCGroups.Keys) {
                    if ($DSCGroupsTarget[$Source]) {
                        @{
                            Name            = $Source
                            DisplayName     = $Source
                            Scope           = $Scope
                            Category        = $Category
                            BaseLineSource  = if ($DSCGroups[$Source].Count -eq 1) { $DSCGroups[$Source][0] } else { $DSCGroups[$Source] }
                            BaseLineTarget  = if ($DSCGroupsTarget[$Source].Count -eq 1) { $DSCGroupsTarget[$Source][0] } else { $DSCGroupsTarget[$Source] }
                            ExcludeProperty = $ExcludeProperty
                        }
                    } else {
                        @{
                            Name            = $Source
                            DisplayName     = $Source
                            Scope           = $Scope
                            Category        = $Category
                            BaseLineSource  = if ($DSCGroups[$Source].Count -eq 1) { $DSCGroups[$Source][0] } else { $DSCGroups[$Source] }
                            BaseLineTarget  = $null
                            ExcludeProperty = $ExcludeProperty
                        }
                    }
                }
            } else {
                Out-Informative -Text "DSCParser is not available. Skipping source $Name" -Level 0 -Status $null -ExtendedValue $null
            }
        } else {
            Out-Informative -Text "Only PS1 (DSC) and JSON files are supported. Skipping source $Name" -Level 0 -Status $null -ExtendedValue $null
            return
        }
        if (-not $BaseLineSource -or -not $BaseLineTarget) {
            Out-Informative -Text "Loading BaseLineSource or BaseLineTarget didn't work. Skipping source $Name" -Level 0 -Status $null -ExtendedValue $null
            return
        }
    }
}