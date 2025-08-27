class ContentBuffer {

    [System.Text.StringBuilder]$Buffer

    ContentBuffer() {
        $this.Buffer = [System.Text.StringBuilder]::new()
    }

    [string]ToString() {
        return $this.Buffer.ToString()
    }

    [void]Set([string]$Value) {
        $this.Buffer.Clear().Append($Value)
    }

    [void]NewLine() {
        $this.Buffer.AppendLine([String]::Empty)
    }

    [void]Append([string]$Value) {
        $this.Buffer.Append($Value)
    }

    [void]Clear() {
        $this.Buffer.Clear()
    }

    [void]ReplaceField([string]$Field, $Value) {
        if($null -eq $Value) {
            $Value = [string]::Empty
        }
        $this.Buffer.Replace($Field, $Value)
    }

    [void]ReplaceFields([hashtable]$Fields) {
        foreach($Key in $Fields.Keys) {
            $this.ReplaceField($Key, $Fields[$Key])
        }
    }

}

<# abstract #> class MergerContent {

    [ContentBuffer]$Tmp
    [ContentBuffer]$Content
    [string]$Template

    MergerContent() {
        $this.Tmp = [ContentBuffer]::new()
        $this.Content = [ContentBuffer]::new()
        $this.Template = [string]::Empty
    }

    <# abstract #> [bool]IsDynamic() {
        throw [NotImplementedException]
    }

}

class MasterContent : MergerContent {

    MasterContent() : base() {}

    [bool]IsDynamic() {
        return $false
    }

}

class DynamicContent : MergerContent {

    [string]$PlaceholderField
    [System.Collections.Generic.HashSet[string]]$Fields

    DynamicContent([string]$PlaceholderField) : base() {
        $this.PlaceholderField = $PlaceholderField
        $this.Fields = [System.Collections.Generic.HashSet[string]]::new()
    }

    [bool]IsDynamic() {
        return $true
    }

}

class MergerBuilder {

    [MasterContent]$MasterContent
    [System.Collections.Generic.List[DynamicContent]]$DynamicContents
    [MergerRequest]$Request
    [MergerProcessor]$Processor
    [System.Collections.Generic.List[BuildListener]]$Listeners
    [BuildEvent]$BuildEvent
    [FieldResolver]$FieldResolver

    [System.Collections.Generic.List[object]]Build([MergerRequest]$Request, [MergerProcessor]$Processor) {
        $this.MasterContent = [MasterContent]::new()
        $this.DynamicContents = [System.Collections.Generic.List[DynamicContent]]::new()
        $this.Request = $Request
        $this.Processor = $Processor
        $this.Listeners = [System.Collections.Generic.List[BuildListener]]::new()
        $this.Listeners.Add($Processor)
        if($Request.ProgressGranularity -gt 0) {
            $this.Listeners.Add([BuildProgress]::new())
        }
        $this.BuildEvent = [BuildEvent]::new()
        $this.FieldResolver = [FieldResolver]::new($Request.FieldFormat)

        $this.BuildInternal()
        return $this.Processor.Output
    }

    hidden [void]BuildInternal() {
        $this.NotifyAll($this.BuildEvent.BuildBegin($this.Request))
        # ========================
        # Extract Dynamic Sections
        # ========================
        [bool]$NewLine = $false # Content begin (Master)
        [MergerContent]$CurrentContent = $this.MasterContent
        foreach($Line in ($this.Request.TemplateContent -split '\r?\n')) {
            if($Line -match $this.Request.DynamicContentField) {
                if($CurrentContent.IsDynamic()) {
                    $CurrentContent = $this.MasterContent
                    $NewLine = $true
                } else {
                    [DynamicContent]$NewContent = $this.NewDynamicContent()
                    $this.MasterContent.Tmp.NewLine()
                    $this.MasterContent.Tmp.Append($NewContent.PlaceholderField)
                    $CurrentContent = $NewContent
                    $NewLine = $false # Content begin (Dynamic)
                }
            } else {
                if($NewLine) {
                    $CurrentContent.Tmp.NewLine()
                }
                $NewLine = $true
                $CurrentContent.Tmp.Append($Line)
            }
        }
        if($CurrentContent.IsDynamic()) {
            throw ("The dynamic section is not closed (a '{0}' field is missing)." -f $this.Request.DynamicContentField)
        }
        # =====================
        # Replace Static Fields
        # =====================
        $this.MasterContent.Tmp.ReplaceFields($this.Request.StaticFields)
        $this.DynamicContents | ForEach-Object { $_.Tmp.ReplaceFields($this.Request.StaticFields) }
        # ==============
        # Init Templates
        # ==============
        $this.MasterContent.Template = $this.MasterContent.Tmp.ToString()
        $this.DynamicContents | ForEach-Object { $_.Template = $_.Tmp.ToString() }
        # ===================
        # Find Dynamic Fields
        # ===================
        foreach($Dynamic in $this.DynamicContents) {
            Select-String -InputObject $Dynamic.Template -Pattern $this.Request.FieldFormat.Pattern -AllMatches | ForEach-Object {
                foreach($Field in $_.Matches) {
                    $Dynamic.Fields.Add($Field)
                }
            }
        }
        # =============
        # Merge Objects
        # =============
        [bool]$FirstObject = $true
        foreach($Object in $this.Request.Objects) {

            $this.NotifyAll($this.BuildEvent.MergingObject($Object))

            foreach($Dynamic in $this.DynamicContents) {

                $Dynamic.Tmp.Set($Dynamic.Template)

                foreach($Field in $Dynamic.Fields) {
                    $Dynamic.Tmp.ReplaceField($Field, $this.FieldResolver.Resolve($Object, $Field))
                }
                switch ($this.Processor.GetRequiredBuildType()) {
                    ([BuildType]::Separated) {
                        $Dynamic.Content.Set($Dynamic.Tmp.ToString())
                    }
                    ([BuildType]::Combined) {
                        if(-not $FirstObject) {
                            $Dynamic.Content.NewLine()
                        }
                        $Dynamic.Content.Append($Dynamic.Tmp.ToString())
                    }
                }
            }
            $FirstObject = $false

            if ($this.Processor.GetRequiredBuildType() -eq [BuildType]::Separated) {
                $this.GenerateContentAndNotify($Object)
            }
        }
        if ($this.Processor.GetRequiredBuildType() -eq [BuildType]::Combined) {
            $this.GenerateContentAndNotify($null)
        }
        #===========================================
        $this.NotifyAll($this.BuildEvent.BuildEnd())
    }

    hidden [DynamicContent]NewDynamicContent() {
        [string]$PlaceholderField = $this.Request.FieldFormat.Format("Dynamic$($this.DynamicContents.Count)")
        [DynamicContent]$Content = [DynamicContent]::new($PlaceholderField)
        $this.DynamicContents.Add($Content)
        return $Content
    }

    hidden [void]GenerateContentAndNotify($Object) {
        $this.MasterContent.Content.Set($this.MasterContent.Template)
        foreach($Dynamic in $this.DynamicContents) {
            $this.MasterContent.Content.ReplaceField($Dynamic.PlaceholderField, $Dynamic.Content.ToString())
        }
        $this.NotifyAll($this.BuildEvent.ContentGenerated($Object, $this.MasterContent.Content.ToString()))
    }

    hidden [void]NotifyAll([BuildEvent]$BuildEvent) {
        $this.Listeners | ForEach-Object { $_.BuildStateChanged($BuildEvent) }
    }

}