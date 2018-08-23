Function Resolve-RelativePath {
    <#
    .SYNOPSIS
    Resolve relative path(s).

    .DESCRIPTION
    This function resolves relative path strings in to absolute path strings, using Get-ScriptPath output as root.

    .OUTPUTS
    [String] containing the path.

    .EXAMPLE
    Resolve-RelativePath ".\folder\subfolder"
    #>
    [CmdletBinding()]
    [OutputType([String])]
    Param(
        [Parameter(Position = 0, Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string[]] $Path
    )
    Process {
        try {
            # if the path is relative
            if ($Path.StartsWith(".\") -or $Path.StartsWith("./")) {
                # prefix the ScriptPath at the beginning of the path, after shaving off anything that may precede the slashes, like a period
                return "$((Get-ScriptFileInfo).DirectoryName)$($Path.Substring($Path.IndexOfAny('/\')))"
            } else {
                # otherwise, just return the provided path
                return $Path
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
} # Resolve-RelativePath
