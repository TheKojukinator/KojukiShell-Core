Function Get-LockingProcs {
    <#
    .SYNOPSIS
        Get list of processes locking a file.
    .DESCRIPTION
        This function returns a list of processes discovered to be locking a specified file. It leverages the SysInternals tool "handle.exe".

        If "handle.exe" is not found in "[script path]\tools\sysinternals", the function will attempt to download it. If the download fails, the function will throw an exception.
    .PARAMETER Path
        Path(s) to potentialy locked file(s).
    .INPUTS
        Path(s) can be provided via pipeline.
    .OUTPUTS
        [PSCustomObject]@{
            FullName
            Name
            PID
            ExecutablePath
            CommandLine
            Type
            User
            Path
        }
    .EXAMPLE
        Get-LockingProcs "c:\users\TestUser\Documents\Spreadsheet.xlsx"
        Name  PID   ExecutablePath
        ----  ---   --------------
        EXCEL 16176 C:\Program Files (x86)\Microsoft Office\Root\Office16\EXCEL.EXE
    .LINK
        Inspired by: https://stackoverflow.com/questions/958123/powershell-script-to-check-an-application-thats-locking-a-file
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Position = 0, Mandatory, ValueFromPipeline, HelpMessage = "Full or partial path (no wildcards).")]
        [ValidateNotNullorEmpty()]
        [string[]] $Path
    )
    begin {
        try {
            # check if the tool is present, if not, attempt to download it from the web
            $exe = "$((Get-ScriptFileInfo).DirectoryName)\tools\sysinternals\handle.exe"
            if (!(Test-Path $exe -ErrorAction Ignore)) {
                Write-Information "Get-LockingProcs : [$exe] not found, attempting to download"
                Confirm-Path "$((Get-ScriptFileInfo).DirectoryName)\tools\sysinternals"
                Invoke-WebRequest -Uri "https://live.sysinternals.com/handle.exe" -OutFile $exe
                if (!(Test-Path $exe -ErrorAction Ignore)) {
                    throw "Can't find [$exe]"
                }
            }
            Write-Information "Get-LockingProcs : Using [$exe]"
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
    process {
        try {
            foreach ($item in $Path) {
                # adjust feedback based on single object or array
                if ($Path.Count -gt 1) {
                    Write-Information "Get-LockingProcs : Searching for handles to [$item] ($i of $($Path.Count))"
                } else {
                    Write-Information "Get-LockingProcs : Searching for handles to [$item]"
                }
                # execute handle.exe and get output, pass arguments to accept license and hide banner
                $data = & $exe -u -accepteula -nobanner $item
                # remove empty lines
                $data = $data -notmatch '^[\W\s]*$'
                # define regex including capture groups for each column we are interested in
                # unbroken regex: '^(?<Name>[\s\w\\\._-]+\.\w+)\s+pid:\s+(?<PID>\d+)\s+type:\s+(?<Type>\w+)\s+(?<User>[\w\\\._-]+)\s+\w+:\s+(?<Path>.*)$'
                [string]$pattern = '^' + # start of line
                '(?<Name>[\s\w\\\._-]+\.\w+)' + # name of the process, allow spaces, periods, dashes, and underscores
                '\s+pid:\s+' + # in-between data before pid
                '(?<PID>\d+)' + # pid of the process, allow numbers
                '\s+type:\s+' + # in-between data before type
                '(?<Type>\w+)' + # type of handle, allow alphanumeric
                '\s+' + # in-between data before user
                '(?<User>[\w\\\._-]+)' + # user bound to handle, allows spaces, periods, dashes, underscores, and backslashes if domain is specified
                '\s+\w+:\s+' + # in-between data before path
                '(?<Path>.*)' + # path to the locked file
                '$' # end of line
                # declare array to hold locking procs
                $lockingProcs = @()
                # iterate over the data lines and try to pull data out via pattern
                foreach ($line in $data) {
                    $matchResult = [RegEx]::Match($line, $pattern)
                    # if matchResult has any value, build the custom object to return
                    if ($matchResult.Value) {
                        $wmi = Get-WmiObject Win32_Process -Filter "ProcessId = $($matchResult.groups["PID"].value)"
                        $obj = [PSCustomObject][ordered]@{
                            FullName       = $matchResult.groups["Name"].value
                            Name           = $matchResult.groups["Name"].value.Substring(0, $matchResult.groups["Name"].value.LastIndexOf(".")) # truncating the extension
                            PID            = $matchResult.groups["PID"].value
                            ExecutablePath = $wmi.ExecutablePath # include the ExecutablePath of the process from WMI
                            CommandLine    = $wmi.CommandLine # include the command line of the process from WMI
                            Type           = $matchResult.groups["Type"].value
                            User           = $matchResult.groups["User"].value
                            Path           = $matchResult.groups["Path"].value
                        }
                        # configure DefaultDisplayPropertySet for the custom object we made
                        [string[]]$defaultProperties = "Name", "PID", "ExecutablePath"
                        $defaultPropertySet = New-Object System.Management.Automation.PSPropertySet DefaultDisplayPropertySet, $defaultProperties
                        $defaultMembers = [System.Management.Automation.PSMemberInfo[]]$defaultPropertySet
                        Add-Member -InputObject $obj -MemberType MemberSet -Name PSStandardMembers -Value $defaultMembers
                        # append the cusom object to the lockingProcs array
                        $lockingProcs += $obj
                    }
                }
                # if lockingProcs array size is zero, we didn't find anything
                if ($lockingProcs.Count -eq 0) {
                    Write-Information "Get-LockingProcs : No matching handles found for [$item]"
                } else {
                    # remove duplicate entries
                    $lockingProcs = $lockingProcs | Sort-Object FullName | Get-Unique -AsString
                    # unravel on return to ensure it is kept as an array
                    return [array]$lockingProcs
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
} # Get-LockingProcs
