Function Enter-Script {
    <#
    .SYNOPSIS
    Wraps useful commands to run at the begining of a script.

    .DESCRIPTION
    This function is a wrapper for various housekeeping commands which are useful at the begining of a script.

    To be used in conjunction with Script-End.

    Performs the following:
    - Clears the console
    - Enables StrictMode
    - Starts transcripting
    - Starts a script timer

    .PARAMETER Log
    Path to log file.

    Default: [script path]\_logs\[script name]\[user]@[computer]_[MM-dd-yyyy_hh-mm-ss].log

    .EXAMPLE
    Enter-Script
    #>
    [CmdletBinding()]
    Param(
        [Parameter()]
        [ValidateNotNullorEmpty()]
        [string] $Log
    )
    Process {
        try {
            # clear the console host
            Clear-Host
            # enable strict mode so we write better code
            Set-StrictMode -Version Latest
            # stop any previous transcript, wrap in try/catch because "Stop-Transcript -ErrorAction SilentlyContinue" doesn't work for some reason
            try { Stop-Transcript *> $null } catch {}
            # if Log is not specified, generate the default path
            if (!$Log) {
                $Log = "$((Get-ScriptFileInfo).DirectoryName)\_logs\$((Get-ScriptFileInfo).BaseName)\"
                $Log += "$($env:USERNAME)@$($env:COMPUTERNAME)_"
                $Log += "$(Get-Date -f MM-dd-yyyy_hh-mm-ss).log"
            }
            # start new transcript
            Start-Transcript -Path $Log -Append *> $null
            # create a global timer variable to keep track of script execution time
            if (Get-Variable -Name _ScriptTimer -Scope Global -ErrorAction SilentlyContinue) {
                Remove-Variable _ScriptTimer -Scope Global -ErrorAction SilentlyContinue
            } else {
                New-Variable -Name _ScriptTimer -Value ([System.Diagnostics.Stopwatch]::StartNew()) -Scope Global
            }
            # set custom window and buffer size if running in ConsoleHost
            $psHost = Get-Host
            if ($psHost.Name -eq "ConsoleHost") {
                $psWindow = $psHost.UI.RawUI
                $bufferSize = $psWindow.BufferSize
                $windowSize = $psWindow.WindowSize
                $bufferSize.Width = [System.Math]::Max(256, $psWindow.MaxWindowSize.Width)
                $bufferSize.Height = 3000
                $psWindow.BufferSize = $bufferSize
                $windowSize.Width = $psWindow.MaxWindowSize.Width
                $psWindow.WindowSize = $windowSize
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
} # Enter-Script
