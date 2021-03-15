<#
    .SYNOPSIS
        Define a new severity level

    .DESCRIPTION
        This function add a new severity level to the ones already defined

    .PARAMETER Level
        An integer that identify the severity of the level, higher the value higher the severity of the level
        By default the module defines this levels:
        NOTSET   0
        DEBUG   10
        INFO    20
        WARNING 30
        ERROR   40

    .PARAMETER LevelName
        The human redable name to assign to the level

    .EXAMPLE
        PS C:\> Add-LoggingLevel -Level 41 -LevelName CRITICAL

    .EXAMPLE
        PS C:\> Add-LoggingLevel -Level 15 -LevelName VERBOSE

    .LINK
        https://logging.readthedocs.io/en/latest/functions/Add-LoggingLevel.md

    .LINK
        https://logging.readthedocs.io/en/latest/functions/Write-Log.md

    .LINK
        https://github.com/EsOsO/Logging/blob/master/Logging/public/Add-LoggingLevel.ps1
#>
function Add-LoggingLevel {
    [CmdletBinding(HelpUri='https://logging.readthedocs.io/en/latest/functions/Add-LoggingLevel.md')]
    param(
        [Parameter(Mandatory)]
        [int] $Level,
        [Parameter(Mandatory)]
        [string] $LevelName
    )

    if ($Level -notin $Script:LevelNames.Keys -and $LevelName -notin $Script:LevelNames.Keys) {
        $Script:LevelNames[$Level] = $LevelName.ToUpper()
        $Script:LevelNames[$LevelName] = $Level
    } elseif ($Level -in $Script:LevelNames.Keys -and $LevelName -notin $Script:LevelNames.Keys) {
        $Script:LevelNames.Remove($Script:LevelNames[$Level]) | Out-Null
        $Script:LevelNames[$Level] = $LevelName.ToUpper()
        $Script:LevelNames[$Script:LevelNames[$Level]] = $Level
    } elseif ($Level -notin $Script:LevelNames.Keys -and $LevelName -in $Script:LevelNames.Keys) {
        $Script:LevelNames.Remove($Script:LevelNames[$LevelName]) | Out-Null
        $Script:LevelNames[$LevelName] = $Level
    }
}
