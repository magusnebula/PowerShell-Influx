﻿Function Write-Influx {
    <#
        .SYNOPSIS
            Writes data to Influx via the REST API.

        .DESCRIPTION
            Use to send data in to an Influx database by providing a hashtable of tags and values.

        .PARAMETER Measure
            The name of the measure to be updated or created.

        .PARAMETER Tags
            A hashtable of tag names and values.

        .PARAMETER Metrics
            A hashtable of metric names and values.

        .PARAMETER Server
            The URL and port for the Influx REST API. Default: 'http://localhost:8086'

        .PARAMETER Database
            The name of the Influx database to write to.

        .EXAMPLE
            Write-Influx -Measure WebServer -Tags @{Server='Host01'} -Metrics @{CPU=100; Memory=50} -Database Web -Server http://myinflux.local:8086
            
            Description
            -----------
            This command will submit the provided tag and metric data for a measure called 'WebServer' to a database called 'Web' via the API endpoint 'http://myinflux.local:8086'
    #>  
    [cmdletbinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        [Parameter(ParameterSetName = 'MetricObject', ValueFromPipeline = $True, Position = 0)]
        [PSTypeName('Metric')]$InputObject,

        [Parameter(ParameterSetName = 'Measure', Mandatory = $true, Position = 0)]
        [string]
        $Measure,

        [Parameter(ParameterSetName = 'Measure')]
        [hashtable]
        $Tags,
        
        [Parameter(ParameterSetName = 'Measure', Mandatory = $true)]
        [hashtable]
        $Metrics,

        [Parameter(ParameterSetName = 'Measure')]
        [datetime]
        $TimeStamp,
        
        [Parameter(Mandatory = $true)]
        [string]
        $Database,
        
        [string]
        $Server = 'http://localhost:8086'
    )
    Process {
        if ($InputObject) {
            $Measure = $InputObject.Measure
            $Metrics = $InputObject.Metrics
            if ($InputObject.Tags) { $Tags = $InputObject.Tags }
            if ($InputObject.TimeStamp) { $TimeStamp = $InputObject.TimeStamp }
        }
    
        if ($TimeStamp) {
            $timeStampNanoSecs = $Timestamp | ConvertTo-UnixTimeNanosecond
        }
        else {
            $null = $timeStampNanoSecs
        }
    
        if ($Tags) {
            $TagData = foreach ($Tag in $Tags.Keys) {
                "$($Tag | Out-InfluxEscapeString)=$($Tags[$Tag] | Out-InfluxEscapeString)"
            }
            $TagData = $TagData -Join ','
            $TagData = ",$TagData"
        }
        
        $Body = foreach ($Metric in $Metrics.Keys) {
            
            if ($Metrics[$Metric]) {
                if ($Metrics[$Metric] -isnot [ValueType]) { 
                    $MetricValue = '"' + $Metrics[$Metric] + '"'
                }
                else {
                    $MetricValue = $Metrics[$Metric] | Out-InfluxEscapeString
                }
            
                "$($Measure | Out-InfluxEscapeString)$TagData $($Metric | Out-InfluxEscapeString)=$MetricValue $timeStampNanoSecs"
            }
        }
    
        if ($Body) {
            $Body = $Body -Join "`n"
            $URI = "$Server/write?&db=$Database"
    
            if ($PSCmdlet.ShouldProcess($URI, $Body)) {
                Invoke-RestMethod -Uri $URI -Method Post -Body $Body | Out-Null
            }
        }
    }
}
