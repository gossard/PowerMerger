<# abstract #> class MergerProcessor : BuildListener {

    [List[object]]$Output

    MergerProcessor() : base() {
        $this.Output = [List[object]]::new()
    }

    <# abstract #> [BuildType]GetRequiredBuildType() {
        throw [NotImplementedException]::new()
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

    hidden static [ValueExtractor]$_fileNameExtractor = [PropertyValueExtractor]::new()

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
            ([BuildEventType]::BuildBegin) { $this._initExtension($BuildEvent) }
            ([BuildEventType]::ContentGenerated) { $this._outFile($BuildEvent) }
        }
    }

    hidden [void]_initExtension([BuildEvent]$BuildEvent) {
        # Priority:
        # 1: Given Extension
        # 2: Given FileName (if Combined)
        # 3: TemplatePath
        [string[]]$Paths = @()
        if($this._isCombined()) {
            $Paths += $this.FileOrProperty
        }
        $Paths += $BuildEvent.Request.TemplatePath
        foreach($Path in $Paths) {
            if([string]::IsNullOrWhiteSpace($this.Extension)) {
                $this.Extension = [Path]::GetExtension($Path)
            }
        }
    }

    hidden [void]_outFile([BuildEvent]$BuildEvent) {
        [string]$FileName = $null
        if($this._isCombined()) {
            $FileName = $this.FileOrProperty
        } else {
            $FileName = [OutFileProcessor]::_fileNameExtractor.ExtractValue($this.FileOrProperty, $BuildEvent.Object).ExtractedValue
            if([string]::IsNullOrWhiteSpace($FileName)) {
                $FileName = $this._generateFileName($BuildEvent)
            }
        }
        $FileName = [Path]::ChangeExtension($FileName, $this.Extension)
        [string]$FilePath = Join-Path $this.DestDir -ChildPath $FileName

        New-Item -Path $this.DestDir -ItemType Directory -Force
        Out-File -FilePath $FilePath -InputObject $BuildEvent.Content -Force
    }

    hidden [string]_generateFileName([BuildEvent]$BuildEvent) {
        [string]$Total = $BuildEvent.Request.Objects.Count.ToString()
        [string]$Index = $BuildEvent.ObjectCount
        while($Index.Length -lt $Total.Length) {
            $Index = '0' + $Index
        }
        return "noname(index-{0})" -f $Index
    }

    hidden [bool]_isCombined() {
        return $this.BuildType -eq [BuildType]::Combined
    }

    [BuildType]GetRequiredBuildType() {
        return $this.BuildType
    }

}