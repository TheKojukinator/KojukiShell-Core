Function Start-Script {
    <#
    .SYNOPSIS
        Wraps useful commands to run at the begining of a script.
    .DESCRIPTION
        This function is a wrapper for various housekeeping commands which are useful at the begining of a script. It is to be used in conjunction with Stop-Script.

        Performs the following:
        - Starts transcripting
        - Starts a script timer
        - Sets Global:ErrorActionPreference to Stop, and saves old value
        - Modifies window and buffer size if running in a console window
    .PARAMETER Log
        Path to log file.

        Default: [script path]\_logs\[script name]\[user]@[computer]_[MM-dd-yyyy_hh-mm-ss].log
    .EXAMPLE
        Start-Script
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullorEmpty()]
        [string] $Log
    )
    process {
        try {
            # stop any previous transcript, generate default log path if not provided, and start a new transcript to it
            try { Stop-Transcript *> $null } catch {}
            if (!$Log) { $Log = "$((Get-ScriptFileInfo).DirectoryName)\_logs\$((Get-ScriptFileInfo).BaseName)\$($env:USERNAME)@$($env:COMPUTERNAME)_$(Get-Date -f MM-dd-yyyy_hh-mm-ss).log" }
            Start-Transcript -Path $Log -Append *> $null

            # init module-scoped script timer
            Write-Information "Start-Script : Initializing script timer"
            $Script:KojukiShell_ScriptTimer = [System.Diagnostics.Stopwatch]::StartNew()

            # save $Global:ErrorActionPreference in a module-scoped variable, then change it to Stop
            Write-Information "Start-Script : Changing Global:ErrorActionPreference from $($Global:ErrorActionPreference) to Stop"
            $Script:KojukiShell_OldErrorActionPreference = $Global:ErrorActionPreference
            $Global:ErrorActionPreference = "Stop"

            # if the host is ConsoleHost, update window and buffer size
            if ((Get-Host).Name -eq "ConsoleHost") {
                Write-Information "Start-Script : Running in [$((Get-Host).Name)], updating window and buffer size"
                $psWindow = (Get-Host).UI.RawUI
                $bufferSize = $psWindow.BufferSize
                $windowSize = $psWindow.WindowSize
                $bufferSize.Width = $psWindow.MaxPhysicalWindowSize.Width
                $bufferSize.Height = 3000
                $psWindow.BufferSize = $bufferSize
                $windowSize.Width = $psWindow.MaxPhysicalWindowSize.Width
                $psWindow.WindowSize = $windowSize
            } else {
                Write-Information "Start-Script : Running in [$((Get-Host).Name)]"
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
} # Start-Script
