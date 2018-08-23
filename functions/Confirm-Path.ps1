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
    Param(
        [Parameter(Position = 0, Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string[]] $Path,
        [Parameter(ParameterSetName = "PassThru")]
        [switch] $PassThru
    )
    Process {
        try {
            # handle single items or arrays
            foreach ($item in $Path) {
                # resolve the path if it is relative
                $item = Resolve-RelativePath $item
                # if there is no extension, we must treat this item as a directory
                if ([String]::IsNullOrEmpty((New-Object IO.FileInfo $item).Extension)) {
                    # create a directory object
                    $dir = New-Object IO.DirectoryInfo $item
                    # if the directory exists
                    if ($dir.Exists) {
                        Write-Verbose "Confirm-Path | Directory exists: $($dir.FullName)"
                        # pipeline it for PassThru
                        if ($PassThru) { $dir }
                        # if the directory doesn't exist
                    } else {
                        Write-Verbose "Confirm-Path | Creating directory: $($dir.FullName)"
                        # attempt to create it
                        $newDir = New-Item -Type Directory -Path $dir.FullName
                        # pipeline it for PassThru if test succeeds
                        if (Test-Path($newDir)) {
                            Write-Verbose "Confirm-Path | Success!"
                            if ($PassThru) { $newDir }
                        } else {
                            throw "Failed to create path: $($dir.FullName)"
                        }
                    }
                    # if there is an extension, we must treat this item as a file
                } else {
                    # create a file object
                    $file = New-Object IO.FileInfo $item
                    # if the file exists
                    if ($file.Exists) {
                        Write-Verbose "Confirm-Path | File exists: $($file.FullName)"
                        # pipeline the directory for PassThru
                        if ($PassThru) { $file.Directory }
                        # if the file doesn't exist, but the directory exists
                    } elseif ($file.Directory.Exists) {
                        Write-Verbose "Confirm-Path | Directory exists: $($file.DirectoryName)"
                        # pipeline the directory for PassThru
                        if ($PassThru) { $file.Directory }
                        # if neither exists
                    } else {
                        Write-Verbose "Confirm-Path | Creating directory: $($file.DirectoryName)"
                        # attempt to create the directory
                        $newDir = New-Item -Type Directory -Path $file.DirectoryName
                        # pipeline it for PassThru if test succeeds
                        if (Test-Path($newDir)) {
                            Write-Verbose "Confirm-Path | Success!"
                            if ($PassThru) { $newDir }
                        } else {
                            throw "Failed to create path: $($file.DirectoryName)"
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
