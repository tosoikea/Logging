<#
    .SYNOPSIS
        Returns enabled logging targets
    .DESCRIPTION
        This function returns enabled logging targtes
    .PARAMETER Name
        The Name of the target to retrieve, if not passed all configured targets will be returned
    .PARAMETER Identifier
        The identifier of the target to retrieve, if not passed the target added without a specific identifier is going to be returned (requires name)
    .EXAMPLE
        PS C:\> Get-LoggingTarget
    .EXAMPLE
        PS C:\> Get-LoggingTarget -Name Console
    .LINK
        https://logging.readthedocs.io/en/latest/functions/Get-LoggingTarget.md
    .LINK
        https://logging.readthedocs.io/en/latest/functions/Write-Log.md
    .LINK
        https://github.com/EsOsO/Logging/blob/master/Logging/public/Get-LoggingTarget.ps1
#>
function Get-LoggingTarget {
    [OutputType([hashtable])]
    [CmdletBinding(HelpUri = 'https://logging.readthedocs.io/en/latest/functions/Get-LoggingTarget.md')]
    param(
        [string] $Name,
        [string] $Identifier
    )

    $result = @{}

    [bool] $hasHandle = $false
    $mutex = $Script:LoggingMutex

    try{
        try{
            # We wait 5s
            $hasHandle = $mutex.WaitOne(5000, $false)

            if (-not $hasHandle){
                Write-Warning -Message ("{0} :: The targets could not be retrieved." -f $MyInvocation.MyCommand)
                return
            }

            if ([String]::IsNullOrWhiteSpace($Name)){
                return $Script:Logging.EnabledTargets
                for($targetEnum = $Script:Logging.EnabledTargets.GetEnumerator(); $targetEnum.MoveNext();){
                    $result[$targetEnum.Current.Key] = @{}

                    for($identifierEnum = $targetEnum.Current.Value.GetEnumerator(); $identifierEnum.MoveNext();){
                        # do not allow editing, this could destroy the functionality of the logger
                        $result[$targetEnum.Current.Key][$identifierEnum.Current.Key] = $identifierEnum.Current.Value.PSObject.Copy()
                    }
                }
            }
            elseif([String]::IsNullOrWhiteSpace($Identifier)){
                if ($Script:Logging.EnabledTargets.ContainsKey($Name)){
                    $result[$Name] = @{}

                    Write-Host "Test"
                    for($identifierEnum = $Script:Logging.EnabledTargets[$Name].GetEnumerator(); $identifierEnum.MoveNext();){
                        # do not allow editing, this could destroy the functionality of the logger
                        $result[$Name][$identifierEnum.Current.Key] = $identifierEnum.Current.Value.PSObject.Copy()
                    }
                }
            }
            else{
                if ($Script:Logging.EnabledTargets.ContainsKey($Name) -and $Script:Logging.EnabledTargets[$Name].ContainsKey($Identifier)){
                    $result[$Name] = @{}
                    $result[$Name][$Identifier] = $Script:Logging.EnabledTargets[$Name][$Identifier].PSObject.Copy()
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

    return $result
}
