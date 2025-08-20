enum BuildEventType {
    BuildBegin
    MergingObject
    ContentGenerated
    BuildEnd
}

class BuildEvent {

    [MergerRequest]$Request
    [BuildEventType]$EventType
    [object]$Object
    [int]$ObjectCount
    [string]$Content

    hidden [BuildEvent]Set([MergerRequest]$Request, [BuildEventType]$EventType, [object]$Object, [int]$ObjectCount, [string]$Content) {
        $this.Request = $Request
        $this.EventType = $EventType
        $this.Object = $Object
        $this.ObjectCount = $ObjectCount
        $this.Content = $Content
        return $this
    }

    [BuildEvent]BuildBegin([MergerRequest]$Request) {
        return $this.Set($Request, [BuildEventType]::BuildBegin, $null, 0, [string]::Empty)
    }

    [BuildEvent]MergingObject([object]$Object) {
        return $this.Set($this.Request, [BuildEventType]::MergingObject, $Object, $this.ObjectCount + 1, [string]::Empty)
    }

    [BuildEvent]ContentGenerated([object]$Object, [string]$Content) {
        return $this.Set($this.Request, [BuildEventType]::ContentGenerated, $Object, $this.ObjectCount, $Content)
    }

    [BuildEvent]BuildEnd() {
        return $this.Set($this.Request, [BuildEventType]::BuildEnd, $null, $this.ObjectCount, [string]::Empty)
    }

}

<# abstract #> class BuildListener {

    <# abstract #> [void]BuildStateChanged([BuildEvent]$BuildEvent) {
        throw [NotImplementedException]
    }

}