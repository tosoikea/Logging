<#
    .SYNOPSIS
        Sets a global logging severity level.

    .DESCRIPTION
        This function sets a global logging severity level.
        Log messages written with a lower logging level will be discarded.

    .PARAMETER Level
        The level severity name to set as default for enabled targets

    .EXAMPLE
        PS C:\> Set-LoggingDefaultLevel -Level ERROR

        PS C:\> Write-Log -Level INFO -Message "Test"
        => Discarded.

    .LINK
        https://logging.readthedocs.io/en/latest/functions/Set-LoggingDefaultLevel.md

    .LINK
        https://logging.readthedocs.io/en/latest/functions/Write-Log.md

    .LINK
        https://github.com/EsOsO/Logging/blob/master/Logging/public/Set-LoggingDefaultLevel.ps1
#>
function Set-LoggingDefaultLevel {
    [CmdletBinding(HelpUri = 'https://logging.readthedocs.io/en/latest/functions/Set-LoggingDefaultLevel.md')]
    param()

    DynamicParam {
        New-LoggingDynamicParam -Name "Level" -Level
    }

    End {

        [bool] $hasHandle = $false
        $mutex = $Script:LoggingMutex

        try{
            try{
                # We wait 5s
                $hasHandle = $mutex.WaitOne(5000, $false)

                if (-not $hasHandle){
                    Write-Warning -Message ("{0} :: The default level could not be changed." -f $MyInvocation.MyCommand)
                    return
                }

                $Script:Logging.Level = $PSBoundParameters.Level
                $Script:Logging.LevelNo = Get-LevelNumber -Level $Script:Logging.Level

                # Setting format on already configured targets
                for($targetEnum = $Script:Logging.EnabledTargets.GetEnumerator(); $targetEnum.MoveNext();){
                    for($identifierEnum = $targetEnum.Current.Value.GetEnumerator(); $identifierEnum.MoveNext();){
                        $target = $identifierEnum.Current.Value

                        if ($target.ContainsKey('Level')) {
                            $target['Level'] = $Script:Logging.Level
                        }
                    }
                }

                # Setting format on available targets
                foreach ($target in $Script:Logging.Targets.Values) {
                    if ($target.Defaults.ContainsKey('Level')) {
                        $target.Defaults.Level.Default = $Script:Logging.Level
                    }
                }
            }catch [System.Threading.AbandonedMutexException]{
                Write-Warning -Message ("{0} :: The logging mutex was abandoned." -f $MyInvocation.MyCommand)
                $hasHandle = $true
            }
        }
        finally{
            if($hasHandle){
                $mutex.ReleaseMutex()
            }
        }
    }
}
