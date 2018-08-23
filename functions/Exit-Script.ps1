Function Exit-Script {
    <#
    .SYNOPSIS
    Wraps useful commands to run at the end of a script.

    .DESCRIPTION
    This function is a wrapper for various housekeeping commands which are useful at the end of a script.

    To be used in conjunction with Script-Start.

    Performs the following:
    - Records script execution time
    - Stops transcripting
    - Disables StrictMode

    .EXAMPLE
    Exit-Script
    #>
    [CmdletBinding()]
    Param()
    Process {
        try {
            # use the global script timer here and clean it up
            if (Get-Variable -Name _KojukiShell_ScriptTimer -Scope Global -ErrorAction SilentlyContinue) {
                Write-Host "Script finished in $($_KojukiShell_ScriptTimer.Elapsed.TotalSeconds) seconds."
                Remove-Variable _KojukiShell_ScriptTimer -Scope Global -ErrorAction SilentlyContinue
            }
            # set Global ErrorActionPreference back and cleanup the global variable
            if (Get-Variable -Name _KojukiShell_ErrorActionPreference -Scope Global -ErrorAction SilentlyContinue) {
                $Global:ErrorActionPreference = $_KojukiShell_ErrorActionPreference
                Remove-Variable _KojukiShell_ErrorActionPreference -Scope Global -ErrorAction SilentlyContinue
            }
            # stop transcribing, wrapped in try/catch because "Stop-Transcript -ErrorAction SilentlyContinue" doesn't work for some reason
            try { Stop-Transcript *> $null } catch {}
            # disable strict mode so it doesn't affect other scripts
            Set-StrictMode -Off
            # exit here, so Exit-Script can be used to actually exit scripts
            exit
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
} # Exit-Script
