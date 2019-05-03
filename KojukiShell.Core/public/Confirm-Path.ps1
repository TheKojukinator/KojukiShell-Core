Function Confirm-Path {
    <#
    .SYNOPSIS
        Enforce path existence.
    .DESCRIPTION
        This function checks if the specified path(s) exist(s), and creates it/them if necessary.
    .PARAMETER Path
        Path(s) to confirm.
    .PARAMETER PassThru
        Puts the path(s) back on the pipeline.
    .INPUTS
        Path(s) can be provided via pipeline.
    .OUTPUTS
        [System.IO.Directory] or [System.IO.DirectoryInfo] if using PassThru switch.
    .EXAMPLE
        Confirm-Path "testPath"
    .EXAMPLE
        Confirm-Path "testPath" -PassThru
        Mode                LastWriteTime         Length Name
        ----                -------------         ------ ----
        d-----        7/16/2018   8:27 AM                test
    .EXAMPLE
        "testPath1", "testPath2" | Confirm-Path
    .EXAMPLE
        "testPath1", "testPath2" | Confirm-Path -PassThru
        Mode                LastWriteTime         Length Name
        ----                -------------         ------ ----
        d-----        7/16/2018   8:29 AM                testPath1
        d-----        7/16/2018   8:29 AM                testPath2
    #>
    [CmdletBinding(DefaultParameterSetName = "Default")]
    [OutputType([System.IO.Directory], [System.IO.DirectoryInfo], ParameterSetName = "PassThru")]
    param(
        [Parameter(Position = 0, Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string[]] $Path,
        [Parameter(ParameterSetName = "PassThru")]
        [switch] $PassThru
    )
    process {
        try {
            foreach ($item in $Path) {
                $item = Get-AbsolutePath $item
                # if there is no extension, we must treat this item as a directory
                if ([String]::IsNullOrEmpty((New-Object IO.FileInfo $item).Extension)) {
                    $dir = New-Object IO.DirectoryInfo $item
                    if ($dir.Exists) {
                        Write-Information "Confirm-Path : Directory [$($dir.FullName)] exists"
                        if ($PassThru) { $dir }
                    } else {
                        Write-Information "Confirm-Path : Directory [$($dir.FullName)] doesn't exist, creating"
                        $newDir = New-Item -Type Directory -Path $dir.FullName
                        if (Test-Path($newDir)) {
                            Write-Information "Confirm-Path : Success!"
                            if ($PassThru) { $newDir }
                        } else {
                            throw "Failed to create directory [$($dir.FullName)]"
                        }
                    }
                } else {
                    # if there is an extension, we must treat this item as a file
                    $file = New-Object IO.FileInfo $item
                    if ($file.Exists) {
                        Write-Information "Confirm-Path : File [$($file.FullName)] exists"
                        if ($PassThru) { $file.Directory }
                    } elseif ($file.Directory.Exists) {
                        Write-Information "Confirm-Path : Directory [$($file.DirectoryName)] exists"
                        if ($PassThru) { $file.Directory }
                    } else {
                        Write-Information "Confirm-Path : Directory [$($file.DirectoryName)] doesn't exist, creating"
                        $newDir = New-Item -Type Directory -Path $file.DirectoryName
                        if (Test-Path($newDir)) {
                            Write-Information "Confirm-Path : Success!"
                            if ($PassThru) { $newDir }
                        } else {
                            throw "Failed to create directory [$($file.DirectoryName)]"
                        }
                    }
                }
            }
        } catch {
            if (!$PSitem.InvocationInfo.MyCommand) {
                $PSCmdlet.ThrowTerminatingError(
                    [System.Management.Automation.ErrorRecord]::new(
                        (New-Object "$($PSItem.Exception.GetType().FullName)" (
                                "$($PSCmdlet.MyInvocation.MyCommand.Name) : $($PSItem.Exception.Message)`n`nStackTrace:`n$($PSItem.ScriptStackTrace)`n"
                            )),
                        $PSItem.FullyQualifiedErrorId,
                        $PSItem.CategoryInfo.Category,
                        $PSItem.TargetObject
                    )
                )
            } else { $PSCmdlet.ThrowTerminatingError($PSitem) }
        }
    }
} # Confirm-Path
