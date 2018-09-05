Function Use-7zip {
    <#
    .SYNOPSIS
        Wraps 7-zip.
    .DESCRIPTION
        This function, in its current state, leverages 7-zip to extract archives. It's a useful alternative to Expand-Archive because it supports more than just the Zip format.

        7-zip must be installed on the machine executing this function. If "7z.exe" is not found in "HKLM:\SOFTWARE\7-Zip\Path" the function will fail.
    .PARAMETER Archive
        Path(s) to the archive(s) to process.
    .PARAMETER Path
        Output path for the Extract operation. Archives will extract in to their own subfolders.
    .INPUTS
        Archive(s) can be provided via pipeline.
    .EXAMPLE
        Use-7zip "DriverPackCatalog.cab" "c:\extracted"
    .EXAMPLE
        "DriverPackCatalog.cab", "c:\users\testUser\Downloads\archive.zip" | Use-7zip -Path "c:\extracted"
    #>
    [CmdletBinding(DefaultParameterSetName = "Extract")]
    param(
        [Parameter(Position = 0, Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string[]] $Archive,
        [Parameter(Position = 1, Mandatory, ParameterSetName = "Extract")]
        [ValidateNotNullOrEmpty()]
        [string] $Path
    )
    begin {
        try {
            # check if the tool is present via registry
            $exe = "$(Get-ItemPropertyValue "HKLM:\SOFTWARE\7-Zip" "Path" -ErrorAction SilentlyContinue)7z.exe"
            if ($exe -eq $null) {
                throw "[HKLM:\SOFTWARE\7-Zip] could not be read, is 7-Zip installed on this machine?"
            }
            if (!(Test-Path $exe -ErrorAction SilentlyContinue)) {
                throw "Can't find [$exe]"
            } else {
                Write-Information "Use-7zip : Using [$exe]"
            }
            # make sure output path exists
            Confirm-Path $Path
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
            foreach ($item in $Archive) {
                $item = Get-AbsolutePath $item
                Write-Information "Use-7zip : Extracting [$item]"
                # call 7zip to extract and save output
                $stdout = & $exe "x" "$item" "-o$Path" "-y" "-bse2"
                # split output in to lines and trim spaces
                $stdout = $stdout.Split("`r`n").Trim()
                # if we have an "Everything is Ok" line that means extraction went well
                if ($stdout -contains "Everything is Ok") {
                    # create an ordered hash to store output details
                    $obj = [ordered]@{}
                    # parse the output for all lines with equal signs
                    $stdout | Where-Object { $_ -like "*=*" } | ForEach-Object {
                        # split lines in to item/value pairs
                        $item = ($_.Split("=") | Select-Object -First 1).Trim()
                        $value = ($_.Split("=") | Select-Object -Last 1).Trim()
                        # add item/value to the hash
                        $obj.add($item, $value)
                    }
                    # add output path as one last item to the hash
                    $obj.add("Status", "Everything is Ok")
                    # add output path as one last item to the hash
                    $obj.add("Output", $Path)
                    # convert the hash to an object
                    $obj = [pscustomobject]$obj
                    Write-Information "Use-7zip : Extraction successful$($obj | Out-String)"
                } else {
                    Write-Warning "Use-7zip : Warning extracting [$item]`n$($obj | Out-String)"
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
} # Use-7zip
