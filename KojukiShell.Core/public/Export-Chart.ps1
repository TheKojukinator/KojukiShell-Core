# load the necessary assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Windows.Forms.DataVisualization
# define a custom validation class for the data series hashtables
Add-Type -TypeDefinition @'
using System;               // for the ArgumentException namespace
using System.Collections;   // for Hashtable support
using Microsoft.CSharp;     // for (dynamic) support
public class ValidateChartDataAttribute : System.Management.Automation.ValidateArgumentsAttribute {
    protected override void Validate(object arguments, System.Management.Automation.EngineIntrinsics engineIntrinsics) {
        foreach(Hashtable item in (dynamic)arguments) {
            // these are mandatory keys, make sure they exist and contain data
            if (!item.ContainsKey("table") || null == item["table"]) { throw new ArgumentException("Hashtable is missing the \"table\" field, or it is Null!"); }
            if (!item.ContainsKey("name") || String.IsNullOrEmpty(item["name"].ToString())) { throw new ArgumentException("Hashtable is missing the \"name\" field, or it is Null or empty!"); }
            if (!item.ContainsKey("x") || String.IsNullOrEmpty(item["x"].ToString())) { throw new ArgumentException("Hashtable is missing the \"x\" field, or it is Null or empty!"); }
            if (!item.ContainsKey("y") || String.IsNullOrEmpty(item["y"].ToString())) { throw new ArgumentException("Hashtable is missing the \"y\" field, or it is Null or empty!"); }
            // these are optional keys, if they exist, make sure they have data
            if (item.ContainsKey("labelx") && String.IsNullOrEmpty(item["labelx"].ToString())) { throw new ArgumentException("Hashtable field \"labelx\" is Null or empty!"); }
            if (item.ContainsKey("labely") && String.IsNullOrEmpty(item["labely"].ToString())) { throw new ArgumentException("Hashtable field \"labely\" is Null or empty!"); }
            if (item.ContainsKey("quota") && !(item["quota"] is int) && !(item["quota"] is double)) { throw new ArgumentException("Hashtable field \"quota\" must be Int or Double!"); }
        }
    }
}
'@ -ReferencedAssemblies ('Microsoft.CSharp') -ErrorAction Stop -WarningAction Ignore
<# once classes are fully supported in PowerShell modules, below re-implementation of the above C# TypeDefinition can be utilized
class ValidateChartDataAttribute : System.Management.Automation.ValidateArgumentsAttribute {
    [void] Validate([object]$object, [System.Management.Automation.EngineIntrinsics]$engineIntrinsics) {
        foreach ($item in $object) {
            # these are mandatory keys, make sure they exist and contain data
            if ($item.Keys -notcontains "table" -or $null -eq $item.table) { throw "Hashtable is missing the `"table`" field, or it is Null!" }
            if ($item.Keys -notcontains "name" -or [string]::IsNullOrEmpty($item.name)) { throw "Hashtable is missing the `"name`" field, or it is Null or empty!" }
            if ($item.Keys -notcontains "x" -or [string]::IsNullOrEmpty($item.x)) { throw "Hashtable is missing the `"x`" field, or it is Null or empty!" }
            if ($item.Keys -notcontains "y" -or [string]::IsNullOrEmpty($item.y)) { throw "Hashtable is missing the `"y`" field, or it is Null or empty!" }
            # these are optional keys, if they exist, make sure they have data
            if ($item.Keys -contains "labelx" -and [string]::IsNullOrEmpty($item.labelx)) { throw "Hashtable field `"labelx`" is Null or empty!" }
            if ($item.Keys -contains "labely" -and [string]::IsNullOrEmpty($item.labely)) { throw "Hashtable field `"labely`" is Null or empty!" }
            if ($item.Keys -contains "quota" -and $item.quota -isnot [int] -and $item.quota -isnot [double]) { throw "Hashtable field `"quota`" must be Int or Double!" }
        }
    }
}
#>
Function Export-Chart {
    <#
    .SYNOPSIS
        Generate a chart and output it to an image file.
    .DESCRIPTION
        This function leverages [System.Windows.Forms.DataVisualization.Charting] to generate a chart based on the provided data set(s) which it then exports to an image file.

        NOTE: Because series have several important properties, they are required to be provided as hashtables. Refer to the first parameter, Data, for more details.
    .PARAMETER Data
        Single, or multiple, hashtables representing data series and related properties.

        Valid hashtable fields are as follows:
            @{
                table   : Required  : Must include a dataset, can be a collection of objects, or an array of values.
                name    : Required  : String - the name of this series, it will be used on the chart key.
                x       : Required  : String - the property name (of data in table) to use for the X axis.
                y       : Required  : String - the property name (of data in table) to use for the Y axis.
                labelx  : Optional  : String - the label for the X axis, if ommited the property name is used by default.
                labely  : Optional  : String - the label for the Y axis, if ommited the property name is used by default.
                quota   : Optional  : Int/Double - the value threshold for the Y axis, over whitch an alternate coloring will be used.
            }
    .PARAMETER OutFile
        Output path and filename for the generated image file.

        Supported formats:
            bmp, emf, gif, jpg, png, tif
    .PARAMETER Title
        Optional chart Title.
    .PARAMETER SubTitle
        Optional chart SubTitle.
    .PARAMETER Width
        Overwrites default chart width.
    .PARAMETER Height
        Overwrites default chart height.
    .PARAMETER Inputs
        Data hashtable(s) can be provided via pipeline.
    .EXAMPLE
        Export-Chart @{table = (Get-ChildItem C:\users\exa\Downloads -File | Select-Object Name, Length); name = "Sizes"; x = "Name"; y = "Length"; labelx = "File Name"; labely = "File Size"; quota = 60000000 } "charts\Testing-Export-Chart1.png" "Downloads" "Sizes of files in my Downloads folder" 1920 1080
    .EXAMPLE
        @{table = (0..10 | ForEach-Object {[pscustomobject]@{date = (get-date).AddDays($PSItem); value = $PSItem * (get-random -Minimum 0 -Maximum 1000)}}); name = "Generated1"; x = "date"; y = "value"; quota = 4000 }, @{table = (0..10 | ForEach-Object {[pscustomobject]@{date = (get-date).AddDays($PSItem); value = $PSItem * (get-random -Minimum 0 -Maximum 1000)}}); name = "Generated2"; x = "date"; y = "value"; quota = 4000 } | Export-Chart -OutFile "charts\Testing-Export-Chart2.png" -Title "Sample Chart" -SubTitle "Randomly generated values over time"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)][ValidateChartData()]
        [hashtable[]] $Data,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()]
        [string] $OutFile,
        [Parameter()][ValidateNotNullOrEmpty()]
        [string] $Title,
        [Parameter()][ValidateNotNullOrEmpty()]
        [string] $SubTitle,
        [Parameter()][ValidateNotNullOrEmpty()]
        [int] $Width = 1200,
        [Parameter()][ValidateNotNullOrEmpty()]
        [int] $Height = 400
    )
    begin {
        try {
            Write-Information "Export-Chart : Generating chart$(if($Title){" [$Title]"})"
            # determine the file extension and check against valid image formats
            if ($OutFile.LastIndexOf(".")) {
                $imageFormat = $OutFile.Substring($OutFile.LastIndexOf(".") + 1)
                # ref: https://msdn.microsoft.com/en-us/library/system.windows.forms.datavisualization.charting.chartimageformat(v=vs.110).aspx
                switch ($imageFormat) {
                    "bmp" {; break}
                    "emf" {; break}
                    "gif" {; break}
                    "jpg" {$imageFormat = "jpeg"; break}
                    "jpeg" {; break}
                    "png" {; break}
                    "tif" {$imageFormat = "tiff"; break}
                    "tiff" {; break}
                    default {
                        Write-Warning "Export-Chart : OutFile image format [$imageFormat] is not supported"
                        Write-Warning "Export-Chart : Supported formats are [BMP, EMF, GIF, JPG, PNG, TIF]"
                        Write-Warning "Export-Chart : Defaulting to PNG"
                        $imageFormat = "png"
                        $OutFile = $OutFile.Substring(0, $OutFile.LastIndexOf(".") + 1) + $imageFormat
                        break
                    }
                }
            } else {
                throw "Could not determine file extension from [$OutFile]"
            }
            # define the color themes here
            $themes = @{
                default = @{
                    Background       = "#404040"
                    ChartBackground  = "#404040"
                    Title            = [System.Drawing.Color]::White
                    SubTitle         = [System.Drawing.Color]::White
                    Legend           = [System.Drawing.Color]::White
                    LegendBackground = "#404040"
                    XTitle           = [System.Drawing.Color]::White
                    XLabel           = [System.Drawing.Color]::White
                    XLine            = "#808080"
                    XGrid            = "#808080"
                    XTick            = "#808080"
                    YTitle           = [System.Drawing.Color]::White
                    YLabel           = [System.Drawing.Color]::White
                    YLine            = "#808080"
                    YGrid            = "#808080"
                    YTick            = "#808080"
                    YInterlace       = "#4d4d4d"
                    Series1          = "#5B9BD5"
                    Series1Marker    = "#3482CB"
                    Series1Alt       = "#E63946"
                    Series1AltMarker = "#E63946"
                    Series2          = "#02C39A"
                    Series2Marker    = "#00A896"
                    Series2Alt       = "#EB6A14"
                    Series2AltMarker = "#EB6A14"
                }
            }
            # create a chart object and define its properties
            $chart = New-object System.Windows.Forms.DataVisualization.Charting.Chart
            $chart.Width = $Width
            $chart.Height = $Height
            $chart.BackColor = $themes.default.Background
            # Title, if provided, will be in the top left
            if ($Title) {
                Write-Information "Export-Chart : Detected Title [$Title]"
                $chart.Titles.Add($Title) > $null
                $chart.Titles[0].Font = [System.Drawing.Font]::new("Calibri", 13, [System.Drawing.FontStyle]::Bold)
                $chart.Titles[0].ForeColor = $themes.default.Title
                $chart.Titles[0].Alignment = [System.Drawing.ContentAlignment]::TopLeft
                # SubTitle, if provided, will be in the top left also
                if ($SubTitle) {
                    Write-Information "Export-Chart : Detected SubTitle [$SubTitle]"
                    $chart.Titles.Add($SubTitle) > $null
                    $chart.Titles[1].Font = [System.Drawing.Font]::new("Calibri", 11, [System.Drawing.FontStyle]::Italic)
                    $chart.Titles[1].ForeColor = $themes.default.SubTitle
                    $chart.Titles[1].Alignment = [System.Drawing.ContentAlignment]::TopLeft
                }
            }
            # create a chart area and define its properties
            $chartArea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
            $chartArea.Name = "ChartArea1"
            $chartArea.BackColor = $themes.default.ChartBackground
            # ref: https://msdn.microsoft.com/en-us/library/system.windows.forms.datavisualization.charting.axis(v=vs.110).aspx
            # define the X axis properties
            $chartArea.AxisX.Title = if ($Data.labelx) { $Data.labelx } else { $Data.x }
            $chartArea.AxisX.TitleFont = [System.Drawing.Font]::new("Calibri", 11, [System.Drawing.FontStyle]::Regular)
            $chartArea.AxisX.TitleForeColor = $themes.default.XTitle
            $chartarea.AxisX.LabelStyle.Font = [System.Drawing.Font]::new("Calibri", 10, [System.Drawing.FontStyle]::Regular)
            $chartarea.AxisX.LabelStyle.ForeColor = $themes.default.XLabel
            $chartArea.AxisX.LineColor = $themes.default.XLine
            $chartArea.AxisX.MajorGrid.LineColor = $themes.default.XGrid
            $chartArea.AxisX.MajorTickMark.LineColor = $themes.default.XTick
            $chartArea.AxisX.IntervalAutoMode = [System.Windows.Forms.DataVisualization.Charting.IntervalAutoMode]::VariableCount
            $chartarea.AxisX.IntervalType = [System.Windows.Forms.DataVisualization.Charting.DateTimeIntervalType]::Auto
            # define the Y axis properties
            $chartArea.AxisY.Title = if ($Data.labely) { $Data.labely } else { $Data.y }
            $chartArea.AxisY.TitleFont = [System.Drawing.Font]::new("Calibri", 11, [System.Drawing.FontStyle]::Regular)
            $chartArea.AxisY.TitleForeColor = $themes.default.YTitle
            $chartarea.AxisY.LabelStyle.Font = [System.Drawing.Font]::new("Calibri", 10, [System.Drawing.FontStyle]::Regular)
            $chartarea.AxisY.LabelStyle.ForeColor = $themes.default.YLabel
            $chartArea.AxisY.LineColor = $themes.default.YLine
            $chartArea.AxisY.MajorGrid.LineColor = $themes.default.YGrid
            $chartArea.AxisY.MajorTickMark.LineColor = $themes.default.YTick
            $chartArea.AxisY.IsInterlaced = $true
            $chartArea.AxisY.InterlacedColor = $themes.default.YInterlace
            $chartArea.AxisY.IntervalAutoMode = [System.Windows.Forms.DataVisualization.Charting.IntervalAutoMode]::VariableCount
            $chartarea.AxisY.IntervalType = [System.Windows.Forms.DataVisualization.Charting.DateTimeIntervalType]::Auto
            # create a legend and define its properties
            $legend = New-Object system.Windows.Forms.DataVisualization.Charting.Legend
            $legend.name = "Legend1"
            $legend.BackColor = $themes.default.LegendBackground
            $legend.Font = [System.Drawing.Font]::new("Calibri", 10, [System.Drawing.FontStyle]::Regular)
            $legend.ForeColor = $themes.default.Legend
            # add the chart area and legend to the chart
            $chart.ChartAreas.Add($chartArea)
            $chart.Legends.Add($legend)
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
            # define a variable to keep track of which series we're on, for theming purposes
            $seriesNum = 1
            # process all the series provided in Data
            foreach ($series in $Data) {
                Write-Information "Export-Chart : Adding series [$($series.Name)]"
                # if, while processing the first series, we determine that the X field will have non-numeric data,
                # set the Interval to 1 so all items show in the chart
                if ($seriesNum -eq 1 -and ($series.table."$($series.x)" | Select-Object -First 1).GetType().Name -eq "String") { $chartArea.AxisX.Interval = 1 }
                # ref: https://msdn.microsoft.com/en-us/library/system.windows.forms.datavisualization.charting.series_properties(v=vs.110).aspx
                # add a series to the chart and define its parameters
                [void]$chart.Series.Add($series.Name)
                $chart.Series[$series.Name].ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Line
                $chart.Series[$series.Name].BorderWidth = 3
                $chart.Series[$series.Name].IsVisibleInLegend = $true
                $chart.Series[$series.Name].ChartArea = "ChartArea1"
                $chart.Series[$series.Name].Legend = "Legend1"
                $chart.Series[$series.Name].XValueType = [System.Windows.Forms.DataVisualization.Charting.ChartValueType]::Auto
                $chart.Series[$series.Name].YValueType = [System.Windows.Forms.DataVisualization.Charting.ChartValueType]::Auto
                $chart.Series[$series.Name].Color = $themes.default."Series$seriesNum"
                $chart.Series[$series.Name].MarkerColor = $themes.default."Series$seriesNum`Marker"
                $chart.Series[$series.Name].MarkerStyle = [System.Windows.Forms.DataVisualization.Charting.MarkerStyle]::Circle
                $chart.Series[$series.Name].MarkerSize = 8
                # add the plot points by processing this series row by row
                foreach ($row in $series.table) {
                    $chart.Series[$series.Name].Points.AddXY($row."$($series.x)", $row."$($series.y)") *> $null
                    # if this series was provided with a quota, use the Alt colors for points above the quota
                    if ($series.quota -and $row."$($series.y)" -gt $series.quota) {
                        $chart.Series[$series.Name].Points[-1].Color = $themes.default."Series$seriesNum`Alt"
                        $chart.Series[$series.Name].Points[-1].MarkerColor = $themes.default."Series$seriesNum`AltMarker"
                    }
                }
                # we currently only have 2 series color variants, so cap the iteration at 2
                if ($seriesNum -lt 2) { $seriesNum++ }
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
    end {
        try {
            Write-Information "Export-Chart : Saving [$imageFormat] image as [$OutFile]"
            Confirm-Path $OutFile
            $chart.SaveImage($OutFile, $imageFormat)
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
} # Export-Chart
