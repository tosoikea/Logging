@{
    Name          = 'Seq'
    Description   = 'Sends log data to the designated Seq server web service'
    Configuration = @{
        Url        = @{Required = $true; Type = [string]; Default = $null }
        ApiKey     = @{Required = $false; Type = [string]; Default = $null }
        Properties = @{Required = $false; Type = [hashtable]; Default = $null }
        Level      = @{Required = $false; Type = [string]; Default = $Logging.Level }
    }
    Logger        = {
        param(
            [hashtable] $Log,
            [hashtable] $Configuration
        )

        $Body = @{
            "@t"       = $Log.TimestampUtc
            "@l"       = $Configuration.Level
            "@m"       = $Log.Message
            "@mt"      = $Log.RawMessage
        }

        if ($Log.ExecInfo) {
            $Body["@x"] = $Log.ExecInfo.ScriptStackTrace
        }

        $Body += $Log

        if ($Configuration.ApiKey) {
            $Url = '{0}/api/events/raw?clef&apiKey={1}' -f $Configuration.Url, $Configuration.ApiKey
        }
        else {
            $Url = '{0}/api/events/raw?clef' -f $Configuration.Url
        }

        Invoke-RestMethod -Uri $Url -Body ($Body | ConvertTo-Json -Compress) -Method POST | Out-Null
    }
}