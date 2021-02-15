<#
.SYNOPSIS
This method simplifies the loading of multiple logging targets and further configuration values by allowing the configuration to result from one (or multiple) .psd1 files.

.DESCRIPTION
Every .psd1 file has to define a hastable that may include information about the targets, the default level and the default format.

.PARAMETER Path
Path to the .psd1 files. Capabilities as described for Import-PowerShellDataFile

.EXAMPLE
Add-LoggingTargets -Path "C:/log/configuration/production.psd1"

# production.psd1
@{
    "Targets" = @{
        "Console" = @{

        }
        "File" = @{
            Path  = 'C:\log\myservice\%{+%Y%m%d}.log'
            RotateAfterAmount = 20
            CompressionPath = 'C:\log\myservice\backup\%{+%Y%m%d}.zip'
        }
    }
    "DefaultLevel" = 'ERROR'
    "DefaultFormat" = '[%{level:-7}] %{message}'
}
#>
function Add-LoggingTargets {
    [CmdletBinding(HelpUri='https://logging.readthedocs.io/en/latest/functions/Add-LoggingTargets.md')]
    param(
        [Parameter(Mandatory)]
        [String[]]
        $Path
    )

    $setTargets = [System.Collections.Generic.HashSet[string]]::new()
    [bool] $isFormatSet = $false
    [bool] $isLevelSet = $false

    $configs = Import-PowerShellDataFile -Path $Path

    foreach ($config in $configs){
        if (-not $config -is [hashtable]){
            Write-Warning -Message ("Incorrect data type for configuration given.")
            continue
        }

        # Load all targets
        if ($config.ContainsKey("Targets")){
            if (-not $config["Targets"] -is [hashtable]){
                Write-Warning -Message ("Incorrect data type for targets given.")
            }else{
                for ($confEnum = $config["Targets"].GetEnumerator(); $confEnum.MoveNext();){
                    $target = $confEnum.Current.Key
                    $targetConfig = $confEnum.Current.Value

                    if (-not $targetConfig -is [hashtable]){
                        Write-Warning -Message ("Incorrect data type for target {0} given." -f $target)
                    }else{
                        if(-not $setTargets.Add($target)){
                            Write-Warning -Message ("Skipping configuration for {0} as multiple configuration values are present." -f $target)
                        }else{
                            Add-LoggingTarget -Name $target -Configuration $targetConfig
                        }
                    }
                }
            }
        }

        # Set default level
        if ($config.ContainsKey("DefaultLevel")){
            if (-not $config["DefaultLevel"] -is [string]){
                Write-Warning -Message ("Incorrect data type for default level given.")
            }else{
                if($isLevelSet){
                    Write-Warning -Message ("Skipping configuration for default level as multiple configuration values are present." -f $target)
                }else{
                    Set-LoggingDefaultLevel -Level $config["DefaultLevel"]
                    $isLevelSet = $true
                }
            }
        }

        # Set default format
        if ($config.ContainsKey("DefaultFormat")){
            if (-not $config["DefaultFormat"] -is [string]){
                Write-Warning -Message ("Incorrect data type for default level given.")
            }else{
                if($isFormatSet){
                    Write-Warning -Message ("Skipping configuration for default format as multiple configuration values are present." -f $target)
                }else{
                    Set-LoggingDefaultFormat -Format $config["DefaultFormat"]
                    $isFormatSet = $true
                }
            }
        }
    }
}