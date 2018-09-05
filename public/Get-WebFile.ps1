Function Get-WebFile {
    <#
    .SYNOPSIS
        Download file(s) from the internet.
    .DESCRIPTION
        This function is an alternative to Invoke-WebRequest in that it handles large downloads better, and provides better feedback.

        NOTE: When downloaded files are saved, their local name is determined from the URL. This means URLs that don't expose the filename will cause this function to fail.
    .PARAMETER URL
        Desired URL(s) to download.
    .PARAMETER Path
        Destination path for the downloaded file(s).
    .PARAMETER Overwrite
        Overwrite the destination file(s).
    .INPUTS
        URL(s) can be provided via pipeline.
    .EXAMPLE
        Get-WebFile "http://www.dell.com/drivers/xps9360.cab" "c:\downloads"
    .EXAMPLE
        "http://www.dell.com/drivers/xps9360.cab", "http://www.dell.com/drivers/lat3330.cab" | Get-WebFile -Path "c:\downloads" -Overwrite
    .LINK
        Inspired by: https://blogs.msdn.microsoft.com/jasonn/2008/06/13/downloading-files-from-the-internet-in-powershell-with-progress
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string[]] $URL,
        [Parameter(Position = 1, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,
        [Parameter()]
        [switch] $Overwrite
    )
    process {
        try {
            # setup progress counter
            $i = 1
            foreach ($item in $URL) {
                # adjust feedback based on single object or array
                if ($URL.Count -gt 1) {
                    Write-Information "Get-WebFile : Attempting to download file ($i of $($URL.Count))...`n`tRemote:`t$item`n`tLocal:`t$Path"
                } else {
                    Write-Information "Get-WebFile : Attempting to download file...`n`tRemote:`t$item`n`tLocal:`t$Path"
                }
                # determine filename by splitting slashes
                $fileName = $item.Split("/\") | Select-Object -Last 1
                # generate local destination
                $destination = "$((Confirm-Path $Path -PassThru).FullName)\$fileName"
                # if the destination file doesn't exist, or overwrite is enabled, proceed with the download
                if (!(Test-Path $destination) -or $Overwrite) {
                    if ($Overwrite) {
                        Write-Information "Get-WebFile : Overwrite switch is set"
                    }
                    # if we are processing more than one object then setup the parent progress bar here
                    if ($URL.Count -gt 1) {
                        Write-Progress -Activity "Get-WebFile" -Id 0529 -Status "$i of $($URL.Count) files" -CurrentOperation $item -PercentComplete ($i / $URL.Count * 100)
                    }
                    # gonna use these to get transfer speeds
                    $dlTimer = [System.Diagnostics.Stopwatch]::StartNew()
                    $dlLastBytes = 0
                    try {
                        # setup cleanup flag
                        $cleanup = $false
                        # create the HttpWebRequest object, feeding it a Uri object with our URL
                        $request = [System.Net.HttpWebRequest]::Create($(New-Object System.Uri $item))
                        # set the timeout to 15 seconds
                        $request.set_Timeout(1000 * 15)
                        # set the user agent so we don't get rejected as a bot
                        $request.UserAgent = "Mozilla/5.0 (Windows NT 10.0; WOW64; Trident/7.0; rv:11.0) like Gecko"
                        # request a response from the remote server, this is where things could fail
                        $response = $request.GetResponse()
                        # get the size of the response in bytes
                        $fileSize = $response.get_ContentLength()
                        # get a stream for the response
                        $responseStream = $response.GetResponseStream()
                        # create a stream for the file, using the "Create" FileMode, documented here: https://msdn.microsoft.com/en-us/library/system.io.filemode(v=vs.110).aspx
                        $fileStream = New-Object -TypeName System.IO.FileStream -ArgumentList $destination, Create
                        # setup a buffer and byte counters for the response stream
                        $buffer = New-Object byte[] 8KB
                        $count = $responseStream.Read($buffer, 0, $buffer.length)
                        $downloadedBytes = $count
                        # this will hold the calculated download speed
                        $dlSpeed = 0
                        Write-Information "Get-WebFile : Download started"
                        # keep downloading and updating the progress while there are still bytes left to read
                        while ($count -gt 0) {
                            # calculate the transfer speed every second
                            if ($dlTimer.Elapsed.TotalSeconds -gt 1) {
                                $dlSpeed = ($downloadedBytes - $dlLastBytes) / $($dlTimer.Elapsed.TotalSeconds)
                                $dlTimeRemaining = New-TimeSpan -Seconds $([System.Math]::Floor(($fileSize - $downloadedBytes) / $dlSpeed))
                                $dlTimer = [System.Diagnostics.Stopwatch]::StartNew()
                                $dlLastBytes = $downloadedBytes
                                # define status string for re-use in progress bar
                                $status = "$([System.Math]::Floor($downloadedBytes/1kb))K of $([System.Math]::Floor($fileSize/1kb))K | $("{0:N2}" -f ($dlSpeed/1KB)) KB/s | $dlTimeRemaining"
                                # adjust feedback based on single object or array
                                if ($URL.Count -gt 1) {
                                    Write-Progress -Activity "Downloading" -Status "$status" -PercentComplete ($downloadedBytes / $fileSize * 100) -ParentId 0529
                                } else {
                                    Write-Progress -Activity "Downloading" -CurrentOperation "$status" -Status "$item" -PercentComplete ($downloadedBytes / $fileSize * 100)
                                }
                                Write-Information "Get-WebFile : $status"
                            }
                            $fileStream.Write($buffer, 0, $count)
                            $count = $responseStream.Read($buffer, 0, $buffer.length)
                            $downloadedBytes += $count
                        }
                        Write-Progress -Activity "Downloading" -Completed
                        Write-Information "Get-WebFile : Download completed [$destination]"
                    } catch {
                        # on exception during download, flag cleanup and rethrow the exception
                        $cleanup = $true
                        throw
                    } finally {
                        # only cleanup fileStream if it exists
                        if ($fileStream) {
                            # only flush and close if it's usable
                            if ($fileStream.CanRead -or $fileStream.CanWrite -or $fileStream.CanSeek) {
                                $fileStream.Flush()
                                $fileStream.Close()
                            }
                            $fileStream.Dispose()
                        }
                        # only cleanup responseStream if it exists
                        if ($responseStream) {
                            $responseStream.Dispose()
                        }
                        # if flagged for cleanup, remove the destination file, and unflag cleanup
                        if ($cleanup) {
                            Remove-Item $destination -Force
                            $cleanup = $false
                        }
                    }
                } else {
                    Write-Information "Get-WebFile : File already exists [$destination]"
                }
                # increment progress counter
                $i++
            }
            # close this progress bar just in case we used it earlier
            Write-Progress -Activity "Get-WebFile" -Completed
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
} # Get-WebFile
