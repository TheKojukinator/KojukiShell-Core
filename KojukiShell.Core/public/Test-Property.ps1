Function Test-Property {
    param(
        $object,
        $property
    )
    process {
        try {
            $element = $object | Select-Object -First 1
            if ($null -ne $element -and (Get-Member -InputObject $element | Where-Object Name -EQ $property)) { return $true } else { return $false }
        } catch {
            return $false
        }
    }
} # Test-Property
