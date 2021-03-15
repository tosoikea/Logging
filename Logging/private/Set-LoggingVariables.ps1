<#
.SYNOPSIS
This helper function initializes all internal data structures.

.DESCRIPTION
This private function must only be called once, when the module is initially loaded to initialize the necessary logging variables.
#>
function Set-LoggingVariables {
    [CmdletBinding()]
    param()

    Write-Verbose -Message ('{0} :: Initializing logging variables' -f $MyInvocation.MyCommand)

    $Script:NOTSET = 0
    $Script:DEBUG = 10
    $Script:INFO = 20
    $Script:WARNING = 30
    $Script:ERROR_ = 40

    New-Variable -Name LevelNames           -Scope Script -Option ReadOnly -Value ([hashtable]::Synchronized(@{
        $NOTSET   = 'NOTSET'
        $ERROR_   = 'ERROR'
        $WARNING  = 'WARNING'
        $INFO     = 'INFO'
        $DEBUG    = 'DEBUG'
        'NOTSET'  = $NOTSET
        'ERROR'   = $ERROR_
        'WARNING' = $WARNING
        'INFO'    = $INFO
        'DEBUG'   = $DEBUG
    }))

    New-Variable -Name ScriptRoot           -Scope Script -Option ReadOnly -Value ([System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Module.Path))
    New-Variable -Name Defaults             -Scope Script -Option ReadOnly -Value @{
        Level       = $LevelNames[$LevelNames['NOTSET']]
        LevelNo     = $LevelNames['NOTSET']
        Format      = '[%{timestamp:+%Y-%m-%d %T%Z}] [%{level:-7}] %{message}'
        Timestamp   = '%Y-%m-%d %T%Z'
        CallerScope = 1
    }

    New-Variable -Name Logging              -Scope Script -Option ReadOnly -Value ([hashtable]::Synchronized(@{
        Level          = $Defaults.Level
        LevelNo        = $Defaults.LevelNo
        Format         = $Defaults.Format
        CallerScope    = $Defaults.CallerScope
        CustomTargets  = [String]::Empty
        Targets        = ([System.Collections.Concurrent.ConcurrentDictionary[string, hashtable]]::new([System.StringComparer]::OrdinalIgnoreCase))
        EnabledTargets = ([System.Collections.Concurrent.ConcurrentDictionary[string, hashtable]]::new([System.StringComparer]::OrdinalIgnoreCase))
    }))
}