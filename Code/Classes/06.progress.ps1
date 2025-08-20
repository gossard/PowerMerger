class BuildProgress : BuildListener {

    BuildProgress() : base() {}

    [void]BuildStateChanged([BuildEvent]$BuildEvent) {
        if($BuildEvent.EventType -eq [BuildEventType]::BuildEnd) {
            Write-Progress -Activity $BuildEvent.EventType -Completed
            return
        }
        [int]$Total = $BuildEvent.Request.Objects.Count
        if($Total -ne 0) {
            [int]$Count = $BuildEvent.ObjectCount
            [int]$PercentComplete = ($Count / $Total) * 100
            if(($PercentComplete % $BuildEvent.Request.ProgressGranularity) -eq 0) {
                [string]$Status = "{0}/{1}" -f $Count, $Total
                Write-Progress -Activity $BuildEvent.EventType -Status $Status -PercentComplete $PercentComplete
            }
        }
    }

}