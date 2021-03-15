<#
    .SYNOPSIS
        Sets a global logging message format

    .DESCRIPTION
        This function sets a global logging message format

    .PARAMETER Format
        The string used to format the message to log

    .EXAMPLE
        PS C:\> Set-LoggingDefaultFormat -Format '[%{level:-7}] %{message}'

    .EXAMPLE
        PS C:\> Set-LoggingDefaultFormat

        It sets the default format as [%{timestamp:+%Y-%m-%d %T%Z}] [%{level:-7}] %{message}

    .LINK
        https://logging.readthedocs.io/en/latest/functions/Set-LoggingDefaultFormat.md

    .LINK
        https://logging.readthedocs.io/en/latest/functions/LoggingFormat.md

    .LINK
        https://logging.readthedocs.io/en/latest/functions/Write-Log.md

    .LINK
        https://github.com/EsOsO/Logging/blob/master/Logging/public/Set-LoggingDefaultFormat.ps1
#>
function Set-LoggingDefaultFormat {
    [CmdletBinding(HelpUri='https://logging.readthedocs.io/en/latest/functions/Set-LoggingDefaultFormat.md')]
    param(
        [string] $Format = $Defaults.Format
    )

    Wait-Logging

    [bool] $hasHandle = $false
    $mutex = $Script:LoggingMutex

    try{
        try{
            # We wait 5s
            $hasHandle = $mutex.WaitOne(5000, $false)

            if (-not $hasHandle){
                Write-Warning -Message ("{0} :: The default format could not be changed." -f $MyInvocation.MyCommand)
                return
            }

            $Script:Logging.Format = $Format

            # Setting format on already configured targets
            for($targetEnum = $Script:Logging.EnabledTargets.GetEnumerator(); $targetEnum.MoveNext();){
                for($identifierEnum = $targetEnum.Current.Value.GetEnumerator(); $identifierEnum.MoveNext();){
                    $target = $identifierEnum.Current.Value

                    if ($target.ContainsKey('Format')) {
                        $target['Format'] = $Script:Logging.Format
                    }
                }
            }

            # Setting format on available targets
            foreach ($target in $Script:Logging.Targets.Values) {
                if ($target.Defaults.ContainsKey('Format')) {
                    $target.Defaults.Format.Default = $Script:Logging.Format
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
