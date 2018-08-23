@{
    ModuleVersion     = '0.1'
    Author            = 'Stephen Kojoukhine'
    Copyright         = '(c) 2018 Stephen Kojoukhine. All rights reserved.'
    GUID              = 'c0a4f724-24dc-43e5-84e4-ed37720ce34d'
    PowerShellVersion = '5.1'
    NestedModules     = @(
        '.\functions\Clear-Cache.ps1',
        '.\functions\Confirm-Path.ps1',
        '.\functions\Enter-Script.ps1',
        '.\functions\Exit-Script.ps1',
        '.\functions\Export-Chart.ps1',
        '.\functions\Get-LockingProcs.ps1',
        '.\functions\Get-ScriptFileInfo.ps1',
        '.\functions\Get-WebFile.ps1',
        '.\functions\Install-Cortana.ps1',
        '.\functions\Resolve-RelativePath.ps1',
        '.\functions\Uninstall-Cortana.ps1',
        '.\functions\Use-7zip.ps1',
        '.\functions\Use-SetACL.ps1'
    )
    FunctionsToExport = @('*')
}
