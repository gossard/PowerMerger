<# abstract #> class MergerProcessor : BuildListener {

    [System.Collections.Generic.List[object]]$Output

    MergerProcessor() : base() {
        $this.Output = New-Object System.Collections.Generic.List[object]
    }

    <# abstract #> [BuildType]GetRequiredBuildType() {
        throw [NotImplementedException]
    }

}

class EmptyProcessor : MergerProcessor {

    [BuildType]$BuildType

    EmptyProcessor([BuildType]$BuildType) : base() {
        $this.BuildType = $BuildType
    }

    [void]BuildStateChanged([BuildEvent]$BuildEvent) {}

    [BuildType]GetRequiredBuildType() {
        return $this.BuildType
    }

}

class OutStringProcessor : MergerProcessor {

    [BuildType]$BuildType

    OutStringProcessor([BuildType]$BuildType) : base() {
        $this.BuildType = $BuildType
    }

    [void]BuildStateChanged([BuildEvent]$BuildEvent) {
        if($BuildEvent.EventType -eq [BuildEventType]::ContentGenerated) {
            $this.Output.Add($BuildEvent.Content)
        }
    }

    [BuildType]GetRequiredBuildType() {
        return $this.BuildType
    }

}

class OutFileProcessor : MergerProcessor {

    [BuildType]$BuildType
    [string]$FileOrProperty
    [string]$DestDir
    [string]$Extension

    OutFileProcessor([BuildType]$BuildType, [string]$FileOrProperty, [string]$DestDir, [string]$Extension) : base() {
        $this.BuildType = $BuildType
        $this.FileOrProperty = $FileOrProperty
        $this.DestDir = $DestDir
        $this.Extension = $Extension
    }

    [void]BuildStateChanged([BuildEvent]$BuildEvent) {
        switch ($BuildEvent.EventType) {
            ([BuildEventType]::BuildBegin) { $this.InitExtension($BuildEvent) }
            ([BuildEventType]::ContentGenerated) { $this.OutFile($BuildEvent) }
        }
    }

    hidden [void]InitExtension([BuildEvent]$BuildEvent) {
        # Priority:
        # 1: Given Extension
        # 2: Given FileName (if Combined)
        # 3: TemplatePath
        [string[]]$Paths = @()
        if($this.IsCombined()) {
            $Paths += $this.FileOrProperty
        }
        $Paths += $BuildEvent.Request.TemplatePath
        foreach($Path in $Paths) {
            if([string]::IsNullOrWhiteSpace($this.Extension)) {
                $this.Extension = [System.IO.Path]::GetExtension($Path)
            }
        }
    }

    hidden [void]OutFile([BuildEvent]$BuildEvent) {
        [string]$FileName = [string]::Empty
        if($this.IsCombined()) {
            $FileName = $this.FileOrProperty
        } else {
            $FileName = $BuildEvent.Object.$($this.FileOrProperty)
            if([string]::IsNullOrWhiteSpace($FileName)) {
                $FileName = $this.GenerateFileName($BuildEvent)
            }
        }
        $FileName = [System.IO.Path]::ChangeExtension($FileName, $this.Extension)
        [string]$FilePath = Join-Path $this.DestDir -ChildPath $FileName
        $BuildEvent.Content | Out-File -FilePath $FilePath -Force
    }

    hidden [string]GenerateFileName([BuildEvent]$BuildEvent) {
        [string]$Total = $BuildEvent.Request.Objects.Count.ToString()
        [string]$Index = $BuildEvent.ObjectCount
        while($Index.Length -lt $Total.Length) {
            $Index = '0' + $Index
        }
        return ("noname(index-{0})" -f $Index)
    }

    hidden [bool]IsCombined() {
        return $this.BuildType -eq ([BuildType]::Combined)
    }

    [BuildType]GetRequiredBuildType() {
        return $this.BuildType
    }

}