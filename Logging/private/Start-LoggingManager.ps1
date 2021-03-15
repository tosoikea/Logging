function Start-LoggingManager {
    [CmdletBinding()]
    param(
        [TimeSpan]$ConsumerStartupTimeout = "00:00:10"
    )

    New-Variable -Name LoggingEventQueue    -Scope Script -Value ([System.Collections.Concurrent.BlockingCollection[hashtable]]::new(100))
    New-Variable -Name LoggingRunspace      -Scope Script -Option ReadOnly -Value ([hashtable]::Synchronized(@{ }))
    New-Variable -Name TargetsInitSync      -Scope Script -Option ReadOnly -Value ([System.Threading.ManualResetEventSlim]::new($false))

    $Script:InitialSessionState = [initialsessionstate]::CreateDefault()

    if ($Script:InitialSessionState.psobject.Properties['ApartmentState']) {
        $Script:InitialSessionState.ApartmentState = [System.Threading.ApartmentState]::MTA
    }

    # Importing variables into runspace
    foreach ($sessionVariable in 'ScriptRoot', 'LevelNames', 'Logging', 'LoggingEventQueue', 'TargetsInitSync', 'LoggingMutex') {
        $Value = Get-Variable -Name $sessionVariable -ErrorAction Continue -ValueOnly
        Write-Verbose "Importing variable $sessionVariable`: $Value into runspace"
        $v = New-Object System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList $sessionVariable, $Value, '', ([System.Management.Automation.ScopedItemOptions]::AllScope)
        $Script:InitialSessionState.Variables.Add($v)
    }

    # Importing functions into runspace
    foreach ($Function in 'Replace-Token', 'Initialize-LoggingTarget', 'Get-LevelNumber') {
        Write-Verbose "Importing function $($Function) into runspace"
        $Body = Get-Content Function:\$Function
        $f = New-Object System.Management.Automation.Runspaces.SessionStateFunctionEntry -ArgumentList $Function, $Body
        $Script:InitialSessionState.Commands.Add($f)
    }

    #Setup runspace
    $Script:LoggingRunspace.Runspace = [runspacefactory]::CreateRunspace($Script:InitialSessionState)
    $Script:LoggingRunspace.Runspace.Name = 'LoggingQueueConsumer'
    $Script:LoggingRunspace.Runspace.Open()
    $Script:LoggingRunspace.Runspace.SessionStateProxy.SetVariable('ParentHost', $Host)
    $Script:LoggingRunspace.Runspace.SessionStateProxy.SetVariable('VerbosePreference', $VerbosePreference)

    # Spawn Logging Consumer
    $Consumer = {
        Initialize-LoggingTarget

        $TargetsInitSync.Set(); # Signal to the parent runspace that logging targets have been loaded

        foreach ($Log in $Script:LoggingEventQueue.GetConsumingEnumerable()) {
            [bool] $hasHandle = $false
            $mutex = $Script:LoggingMutex

            try{
                try{
                    # We wait 5s
                    $hasHandle = $mutex.WaitOne(5000, $false)

                    if (-not $hasHandle){
                        $ParentHost.UI.WriteErrorLine("ERROR: Discarding log entry as mutex could not be obtained.")
                        continue
                    }

                    if ($Script:Logging.EnabledTargets.Count -eq 0){
                        continue
                    }

                    $ParentHost.NotifyBeginApplication()
                    try {
                        for ($targetEnum = $Script:Logging.EnabledTargets.GetEnumerator(); $targetEnum.MoveNext(); ) {
                            [string] $target = $targetEnum.Current.key
                            $logger = [scriptblock] $Script:Logging.Targets[$target].Logger

                            for ($confEnum = $targetEnum.Current.Value.GetEnumerator(); $confEnum.MoveNext();){
                                [hashtable] $configuration = $confEnum.Current.Value

                                $levelNr = Get-LevelNumber -Level $configuration.Level
                                if ($Log.LevelNo -ge $levelNr) {
                                    Invoke-Command -ScriptBlock $Logger -ArgumentList @($Log.PSObject.Copy(), $configuration)
                                }
                            }
                        }
                    }
                    catch {
                        $ParentHost.UI.WriteErrorLine($_)
                    }
                    finally {
                        $ParentHost.NotifyEndApplication()
                    }
                }catch [System.Threading.AbandonedMutexException]{
                    $ParentHost.UI.WriteErrorLine(("{0} :: The loggings mutex was abandoned." -f $MyInvocation.MyCommand))
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

    $Script:LoggingRunspace.Powershell = [Powershell]::Create().AddScript($Consumer, $true)
    $Script:LoggingRunspace.Powershell.Runspace = $Script:LoggingRunspace.Runspace
    $Script:LoggingRunspace.Handle = $Script:LoggingRunspace.Powershell.BeginInvoke()

    #region Handle Module Removal
    $OnRemoval = {
        $Module = Get-Module Logging

        if ($Module) {
            $Module.Invoke({
                Wait-Logging
                Stop-LoggingManager
            })
        }

        [System.GC]::Collect()
    }

    # This scriptblock would be called within the module scope
    $ExecutionContext.SessionState.Module.OnRemove += $OnRemoval

    # This scriptblock would be called within the global scope and wouldn't have access to internal module variables and functions that we need
    $Script:LoggingRunspace.EngineEventJob = Register-EngineEvent -SourceIdentifier ([System.Management.Automation.PsEngineEvent]::Exiting) -Action $OnRemoval
    #endregion Handle Module Removal

    if(-not $TargetsInitSync.Wait($ConsumerStartupTimeout)){
        throw 'Timed out while waiting for logging consumer to start up'
    }
}