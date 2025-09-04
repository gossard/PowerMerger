class ContentBuffer {

    [StringBuilder]$Buffer

    ContentBuffer() {
        $this.Buffer = [StringBuilder]::new()
    }

    [string]ToString() {
        return $this.Buffer.ToString()
    }

    [void]Set([string]$Value) {
        $this.Buffer.Clear().Append($Value)
    }

    [void]NewLine() {
        $this.Buffer.AppendLine([string]::Empty)
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

}

<# abstract #> class MergerContent {

    [ContentBuffer]$Tmp
    [ContentBuffer]$Content
    [string]$Template
    [List[Field]]$Fields

    MergerContent() {
        $this.Tmp = [ContentBuffer]::new()
        $this.Content = [ContentBuffer]::new()
        $this.Template = [string]::Empty
        $this.Fields = [List[Field]]::new()
    }

    <# abstract #> [bool]IsDynamic() {
        throw [NotImplementedException]::new()
    }

}

class MasterContent : MergerContent {

    MasterContent() : base() {}

    [bool]IsDynamic() {
        return $false
    }

}

class DynamicContent : MergerContent {

    [Field]$PlaceholderField

    DynamicContent([Field]$PlaceholderField) : base() {
        $this.PlaceholderField = $PlaceholderField
    }

    [bool]IsDynamic() {
        return $true
    }

}

class MergerBuilder {

    [MergerRequest]$Request
    [MergerProcessor]$Processor

    [MasterContent]$MasterContent
    [List[DynamicContent]]$DynamicContents
    [List[BuildListener]]$Listeners
    [BuildEvent]$BuildEvent
    [FieldSyntax]$FieldSyntax
    [FieldFormatter]$FieldFormatter
    [FieldParser]$FieldParser
    [FieldFactory]$FieldFactory
    [FieldResolver]$FieldResolver

    [List[object]]Build([MergerRequest]$Request, [MergerProcessor]$Processor) {
        $this.Request = $Request
        $this.Processor = $Processor

        $this.MasterContent = [MasterContent]::new()
        $this.DynamicContents = [List[DynamicContent]]::new()
        $this.Listeners = [List[BuildListener]]::new()
        $this.Listeners.Add($this.Processor)
        if($this.Request.ProgressGranularity -gt 0) {
            $this.Listeners.Add([BuildProgress]::new())
        }
        $this.BuildEvent = [BuildEvent]::new()
        $this.FieldSyntax = [FieldSyntax]::new($this.Request.FieldWrapper)
        $this.FieldFormatter = [FieldFormatter]::new($this.FieldSyntax)
        $this.FieldParser = [FieldParser]::new($this.FieldSyntax)
        $this.FieldFactory = [FieldFactory]::new($this.FieldFormatter)
        $this.FieldResolver = [FieldResolver]::new()

        $this._buildInternal()
        return $this.Processor.Output
    }

    hidden [void]_buildInternal() {
        [Field]$DynamicContentField = $this.FieldFactory.CreateFromSelector($this.Request.DynamicContentField)

        $this._notifyAll($this.BuildEvent.BuildBegin($this.Request))
        # ========================
        # Extract Dynamic Sections
        # ========================
        [bool]$NewLine = $false # Content begin (Master)
        [MergerContent]$CurrentContent = $this.MasterContent
        foreach($Line in ($this.Request.TemplateContent -split '\r?\n')) {
            if($Line -match $DynamicContentField.RawText) {
                if($CurrentContent.IsDynamic()) {
                    $CurrentContent = $this.MasterContent
                    $NewLine = $true
                } else {
                    [DynamicContent]$NewContent = $this._newDynamicContent()
                    $this.MasterContent.Tmp.NewLine()
                    $this.MasterContent.Tmp.Append($NewContent.PlaceholderField.RawText)
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
            throw "The dynamic section is not closed (a '{0}' field is missing)." -f $DynamicContentField.RawText
        }
        # ===========
        # Find Fields
        # ===========
        foreach($Dynamic in $this.DynamicContents) {
            $Dynamic.Fields = $this.FieldParser.ParseAll($Dynamic.Tmp)
        }
        $this.MasterContent.Fields = $this.FieldParser.ParseAll($this.MasterContent.Tmp)
        [string[]]$DynamicPlaceholders = $this.DynamicContents.PlaceholderField.RawText
        $this.MasterContent.Fields.RemoveAll({
            param($Element)
            $DynamicPlaceholders -contains $Element.RawText
        })
        # ======================================
        # Resolve static fields in MasterContent
        # ======================================
        foreach($Field in $this.MasterContent.Fields) {
            $this.MasterContent.Tmp.ReplaceField($Field.RawText, $this.FieldResolver.Resolve($Field, $this.Request.StaticData))
        }
        # ==============
        # Init Templates
        # ==============
        $this.MasterContent.Template = $this.MasterContent.Tmp.ToString()
        foreach($Dynamic in $this.DynamicContents) {
            $Dynamic.Template = $Dynamic.Tmp.ToString()
        }
        # =============
        # Merge Objects
        # =============
        [bool]$FirstObject = $true
        foreach($Object in $this.Request.Objects) {

            $this._notifyAll($this.BuildEvent.MergingObject($Object))

            foreach($Dynamic in $this.DynamicContents) {

                $Dynamic.Tmp.Set($Dynamic.Template)

                foreach($Field in $Dynamic.Fields) {
                    $Dynamic.Tmp.ReplaceField($Field.RawText, $this.FieldResolver.Resolve($Field, $Object, $this.Request.StaticData))
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
                $this._generateContentAndNotify($Object)
            }
        }
        if ($this.Processor.GetRequiredBuildType() -eq [BuildType]::Combined) {
            $this._generateContentAndNotify($null)
        }
        #===========================================
        $this._notifyAll($this.BuildEvent.BuildEnd())
    }

    hidden [DynamicContent]_newDynamicContent() {
        [string]$Selector = "Dynamic$($this.DynamicContents.Count)"
        [DynamicContent]$Content = [DynamicContent]::new($this.FieldFactory.CreateFromSelector($Selector))
        $this.DynamicContents.Add($Content)
        return $Content
    }

    hidden [void]_generateContentAndNotify($Object) {
        $this.MasterContent.Content.Set($this.MasterContent.Template)
        foreach($Dynamic in $this.DynamicContents) {
            $this.MasterContent.Content.ReplaceField($Dynamic.PlaceholderField.RawText, $Dynamic.Content.ToString())
        }
        $this._notifyAll($this.BuildEvent.ContentGenerated($Object, $this.MasterContent.Content.ToString()))
    }

    hidden [void]_notifyAll([BuildEvent]$BuildEvent) {
        foreach($Listener in $this.Listeners) {
            $Listener.BuildStateChanged($BuildEvent)
        }
    }

}