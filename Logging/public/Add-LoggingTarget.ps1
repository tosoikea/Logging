<#
    .SYNOPSIS
        Enable a logging target
    .DESCRIPTION
        This function configure and enable a logging target
    .PARAMETER Name
        The name of the target to enable and configure
    .PARAMETER Configuration
        An hashtable containing the configurations for the target
    .EXAMPLE
        PS C:\> Add-LoggingTarget -Name Console -Configuration @{Level = 'DEBUG'}
    .EXAMPLE
        PS C:\> Add-LoggingTarget -Name File -Configuration @{Level = 'INFO'; Path = 'C:\Temp\script.log'}
    .LINK
        https://logging.readthedocs.io/en/latest/functions/Add-LoggingTarget.md
    .LINK
        https://logging.readthedocs.io/en/latest/functions/Write-Log.md
    .LINK
        https://logging.readthedocs.io/en/latest/AvailableTargets.md
    .LINK
        https://github.com/EsOsO/Logging/blob/master/Logging/public/Add-LoggingTarget.ps1
#>
function Add-LoggingTarget {
    [CmdletBinding(HelpUri='https://logging.readthedocs.io/en/latest/functions/Add-LoggingTarget.md')]
    param(
        [hashtable]
        $Configuration = @{},
        [ValidateNotNullOrEmpty()]
        [String]
        $Identifier = "__DEFAULT__"
    )

    DynamicParam {
        New-LoggingDynamicParam -Name 'Name' -Target
    }

    End {
        [bool] $hasHandle = $false
        $mutex = $Script:LoggingMutex
        $target = $PSBoundParameters.Name

        try{
            try{
                # We wait 5s
                $hasHandle = $mutex.WaitOne(5000, $false)

                if (-not $hasHandle){
                    Write-Warning -Message ("{0} :: The logging target could not be added." -f $MyInvocation.MyCommand)
                    return
                }

                if ($Script:Logging.EnabledTargets.ContainsKey($target) -and $Script:Logging.EnabledTargets[$target].ContainsKey($Identifier)){
                    Write-Warning -Message ("{0} :: The logger {1}:{2} is already registered. You are now going to override an existing configuration. If multiple instances are desired, use the -Identifier parameter." -f $MyInvocation.MyCommand, $target, $Identifier)
                }

                $mergedConfiguration = Merge-DefaultConfig -Target $target -Configuration $Configuration

                # Special case hack - resolve target file path if it's a relative path
                # This can't be done in the Init scriptblock of the logging target because that scriptblock gets created in the
                # log consumer runspace and doesn't inherit the current SessionState. That means that the scriptblock doesn't know the
                # current working directory at the time when `Add-LoggingTarget` is being called and can't accurately resolve the relative path.
                if($target -eq 'File'){
                    $mergedConfiguration.Path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Configuration.Path)
                }

                # Initialize the target before registering it in The loggings to prevent incomplete initialization
                if ($Script:Logging.Targets[$target].Init -is [scriptblock]) {
                    & $Script:Logging.Targets[$target].Init $mergedConfiguration
                }

                # Initialize EnabledTargets[TARGET_NAME]
                if (-not $Script:Logging.EnabledTargets.ContainsKey($target)){
                    $Script:Logging.EnabledTargets.Add($target, [System.Collections.Generic.Dictionary[string, hashtable]]::new([System.StringComparer]::OrdinalIgnoreCase))
                }

                # Add configuration with the identifier
                $Script:Logging.EnabledTargets[$target][$Identifier] = $mergedConfiguration
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
    }
}