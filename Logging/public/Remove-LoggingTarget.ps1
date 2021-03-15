<#
    .SYNOPSIS
        Remove a logging target
    .DESCRIPTION
        This function removes a single or multiple enabled targets.
        If only the name is specified, all instances of it are removed.
        If both the identifier and the name are specified, only this specific instance is removed.
    .PARAMETER Name
        The name of the target to remove
    .PARAMETER Identifier
        Optionally the identifier to be used for removal
    .EXAMPLE
        PS C:\> Add-LoggingTarget -Name Console -Configuration @{Level = 'DEBUG'}
        PS C:\> Add-LoggingTarget -Name Console -Identifier "LoggingIsAwesome" -Configuration @{Level = 'Warning'}
        PS C:\> Remove-LoggingTarget -Name Console
        PS C:\> Get-LoggingTarget
        {}
    .EXAMPLE
        PS C:\> Add-LoggingTarget -Name Console -Configuration @{Level = 'DEBUG'}
        PS C:\> Add-LoggingTarget -Name Console -Identifier "LoggingIsAwesome" -Configuration @{Level = 'Warning'}
        PS C:\> Remove-LoggingTarget -Name Console -Identifier "LoggingIsAwesome"
        PS C:\> Get-LoggingTarget
        Name                           Value
        ----                           -----
        Console                        {[__DEFAULT__, System.Collections.Hashtable]}
    .LINK
        https://logging.readthedocs.io/en/latest/functions/Remove-LoggingTarget.md
    .LINK
        https://github.com/EsOsO/Logging/blob/master/Logging/public/Remove-LoggingTarget.ps1
#>
function Remove-LoggingTarget {
    [OutputType([bool])]
    [CmdletBinding(HelpUri='https://logging.readthedocs.io/en/latest/functions/Remove-LoggingTarget.md')]
    param(
        [ValidateNotNullOrEmpty()]
        [Parameter(Position = 2)]
        [String]
        $Identifier
    )

    DynamicParam {
        New-LoggingDynamicParam -Name 'Name' -Target
    }

    End {
        [bool] $hasHandle = $false
        $mutex = $Script:LoggingMutex
        $target = $PSBoundParameters.Name

        $wasRemoved = $false

        try{
            try{
                # We wait 5s
                $hasHandle = $mutex.WaitOne(5000, $false)

                if (-not $hasHandle){
                    Write-Warning -Message ("{0} :: The logging target could not be removed." -f $MyInvocation.MyCommand)
                    return $wasRemoved
                }

                if (-not $Script:Logging.EnabledTargets.ContainsKey($target)){
                    return $wasRemoved
                }

                if ([String]::IsNullOrWhiteSpace($Identifier)){
                    $wasRemoved = $Script:Logging.EnabledTargets.Remove($target)
                }else{
                    if (-not $Script:Logging.EnabledTargets[$target].ContainsKey($Identifier)){
                        return $wasRemoved
                    }else{
                        $wasRemoved = $Script:Logging.EnabledTargets[$target].Remove($Identifier)

                        if ($Script:Logging.EnabledTargets[$target].Count -eq 0){
                            $Script:Logging.EnabledTargets.Remove($target) | Out-Null
                        }
                    }
                }
            }catch [System.Threading.AbandonedMutexException]{
                Write-Warning -Message ("{0} :: The loggings mutex was abandoned." -f $MyInvocation.MyCommand)
                $hasHandle = $true
            }
        }
        finally{
            if($hasHandle){
                $mutex.ReleaseMutex()
            }
        }

        return $wasRemoved
    }
}