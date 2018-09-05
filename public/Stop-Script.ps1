Function Stop-Script {
    <#
    .SYNOPSIS
        Wraps useful commands to run at the end of a script.
    .DESCRIPTION
        This function is a wrapper for various housekeeping commands which are useful at the end of a script. It is to be used in conjunction with Script-Start.

        Performs the following:
        - Records script execution time
        - Reverts Global:ErrorActionPreference to saved old value (if present)
        - Stops transcripting
        - Terminates script via Exit
    .EXAMPLE
        Stop-Script
    #>
    [CmdletBinding()]
    param()
    process {
        try {
            # log script execution time and cleanup the module-scoped variable
            if ($Script:KojukiShell_ScriptTimer) {
                Write-Information "Stop-Script : Script finished in $($Script:KojukiShell_ScriptTimer.Elapsed.TotalSeconds) seconds."
                Remove-Variable KojukiShell_ScriptTimer -Scope Script -ErrorAction SilentlyContinue
            }

            # revert Global ErrorActionPreference and cleanup the module-scoped variable
            if ($Script:KojukiShell_OldErrorActionPreference) {
                Write-Information "Stop-Script : Reverting Global ErrorActionPreference from $($Global:ErrorActionPreference) to $($Script:KojukiShell_OldErrorActionPreference)"
                $Global:ErrorActionPreference = $Script:KojukiShell_OldErrorActionPreference
                Remove-Variable KojukiShell_OldErrorActionPreference -Scope Script -ErrorAction SilentlyContinue
            }

            # stop the transcript, ignore errors
            try { Stop-Transcript *> $null } catch {}

            # exit here, so Stop-Script can be used to exit scripts
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
} # Stop-Script
