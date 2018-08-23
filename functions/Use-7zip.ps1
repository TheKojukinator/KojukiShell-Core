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
    Param(
        [Parameter(Position = 0, Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string[]] $Archive,
        [Parameter(Position = 1, Mandatory, ParameterSetName = "Extract")]
        [ValidateNotNullOrEmpty()]
        [string] $Path
    )
    Begin {
        try {
            # construct path from 7-Zip reg key and expected executable name 7z.exe
            $exe = "$(Get-ItemPropertyValue "HKLM:\SOFTWARE\7-Zip" "Path" -ErrorAction SilentlyContinue)7z.exe"
            # check if registry value was retrieved
            if ($exe -eq $null) {
                throw "7-Zip could not be read, is it installed on this machine?"
            }
            # if the tool is not located, provide feedback and throw error
            if (!(Test-Path $exe -ErrorAction SilentlyContinue)) {
                throw "Can't find: $exe"
            } else {
                Write-Verbose "Use-7zip | Using: $exe"
            }
            # resolve the path if it is relative
            $Path = Resolve-RelativePath $Path
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
    Process {
        try {
            # handle single items or arrays
            foreach ($item in $Archive) {
                # resolve the path if it is relative
                $item = Resolve-RelativePath $item
                Write-Verbose "Extract-Archive | Extracting: $item"
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
                    # output the object verbose
                    Write-Verbose "Extract-Archive | Extraction successful...$($obj | Out-String)"
                } else {
                    Write-Warning "Extract-Archive | Warning extracting: $item`n$($obj | Out-String)"
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
