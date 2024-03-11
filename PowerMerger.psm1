# Built on 03/11/2024 10:04:59
class FieldFormat {

    [string]$FieldWrapper
    [string]$Pattern

    FieldFormat([string]$FieldWrapper) {
        $this.FieldWrapper = $FieldWrapper
        $this.Pattern = $this.FormatUnsafe('(.*?)')
    }

    hidden [string]FormatUnsafe([string]$Field) {
        return "{0}{1}{0}" -f $this.FieldWrapper, $Field
    }

    [string]Format([string]$Field) {
        if($Field -match $this.Pattern) {
            return $Field
        }
        return $this.FormatUnsafe($Field)
    }

    [string]Unformat([string]$Field) {
        return $Field.Replace($this.FieldWrapper, [string]::Empty)
    }

}
class MergerRequest {

    [string]$TemplatePath
    [string]$TemplateContent
    [FieldFormat]$FieldFormat
    [string]$DynamicContentField
    [hashtable]$StaticFields
    [int]$ProgressGranularity
    [System.Collections.Generic.List[object]]$Objects

    MergerRequest(
        [string]$TemplatePath,
        [string]$TemplateContent,
        [string]$FieldWrapper,
        [string]$DynamicContentField,
        [hashtable]$StaticFields,
        [int]$ProgressGranularity) {

        $this.TemplatePath = $TemplatePath
        $this.TemplateContent = $TemplateContent
        $this.FieldFormat = New-Object FieldFormat -ArgumentList $FieldWrapper
        $this.DynamicContentField = $this.FieldFormat.Format($DynamicContentField)
        $this.StaticFields = @{}
        foreach($Key in $StaticFields.Keys) {
            $this.StaticFields[$this.FieldFormat.Format($Key)] = $StaticFields[$Key]
        }
        $this.ProgressGranularity = $ProgressGranularity
        $this.Objects = New-Object System.Collections.Generic.List[object]
    }

    [void]AddObject($Object) {
        if($null -ne $Object) {
            $this.Objects.Add($Object)
        }
    }

}
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
enum BuildType {
    Combined
    Separated
}
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
class ContentBuffer {

    [System.Text.StringBuilder]$Buffer

    ContentBuffer() {
        $this.Buffer = New-Object System.Text.StringBuilder
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
        $this.Tmp = New-Object ContentBuffer
        $this.Content = New-Object ContentBuffer
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
        $this.Fields = New-Object System.Collections.Generic.HashSet[string]
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

    [System.Collections.Generic.List[object]]Build([MergerRequest]$Request, [MergerProcessor]$Processor) {
        $this.MasterContent = New-Object MasterContent
        $this.DynamicContents = New-Object System.Collections.Generic.List[DynamicContent]
        $this.Request = $Request
        $this.Processor = $Processor
        $this.Listeners = New-Object System.Collections.Generic.List[BuildListener]
        $this.Listeners.Add($Processor)
        if($Request.ProgressGranularity -gt 0) {
            $this.Listeners.Add((New-Object BuildProgress))
        }
        $this.BuildEvent = New-Object BuildEvent

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
            throw ("The dynamic section is not closed (a '{0}' field is missing)" -f $this.Request.DynamicContentField)
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
                    $Dynamic.Tmp.ReplaceField($Field, $Object.$($this.Request.FieldFormat.Unformat($Field)))
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
        [DynamicContent]$Content = New-Object DynamicContent -ArgumentList $PlaceholderField
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
function New-MergerBuild {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [MergerProcessor]$Processor,
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [ValidateNotNull()]
        [MergerRequest]$Request
    )
    process {
        (New-Object MergerBuilder).Build($Request, $Processor)
    }
}
function New-MergerEmptyProcessor {
    [CmdletBinding()]
    [OutputType([EmptyProcessor])]
    param(
        [Parameter(Mandatory=$false)]
        [ValidateNotNull()]
        [BuildType]$BuildType = [BuildType]::Combined
    )
    New-Object EmptyProcessor -ArgumentList $BuildType
}
function New-MergerOutFileProcessor {
    [CmdletBinding(DefaultParameterSetName='Combined')]
    [OutputType([OutFileProcessor])]
    param(
        [Parameter(Mandatory=$true, ParameterSetName='Combined')]
        [ValidateScript({ -not [string]::IsNullOrWhiteSpace($_) })]
        [string]$FileName,

        [Parameter(Mandatory=$true, ParameterSetName='Separated')]
        [ValidateScript({ -not [string]::IsNullOrWhiteSpace($_) })]
        [string]$PropertyName,

        [Parameter(Mandatory=$true)]
        [ValidateScript({ Test-Path $_ -PathType Container })]
        [string]$DestDir,

        [Parameter(Mandatory=$false)]
        [string]$Extension
    )
    if($PSCmdlet.ParameterSetName -eq 'Combined') {
        New-Object OutFileProcessor -ArgumentList ([BuildType]::Combined), $FileName, $DestDir, $Extension
    } else {
        New-Object OutFileProcessor -ArgumentList ([BuildType]::Separated), $PropertyName, $DestDir, $Extension
    }
}
function New-MergerOutStringProcessor {
    [CmdletBinding()]
    [OutputType([OutStringProcessor])]
    param(
        [Parameter(Mandatory=$false)]
        [ValidateNotNull()]
        [BuildType]$BuildType = [BuildType]::Combined
    )
    New-Object OutStringProcessor -ArgumentList $BuildType
}
function New-MergerRequest {
    [CmdletBinding(DefaultParameterSetName='Path')]
    [OutputType([MergerRequest])]
    param(
        [Parameter(Mandatory=$true, ParameterSetName='Path')]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$TemplatePath,

        [Parameter(Mandatory=$true, ParameterSetName='Content')]
        [ValidateScript({ -not [string]::IsNullOrWhiteSpace($_) })]
        [string]$TemplateContent,

        [Parameter(Mandatory=$false)]
        [ValidateScript({ -not [string]::IsNullOrWhiteSpace($_) })]
        [string]$FieldWrapper = '%',

        [Parameter(Mandatory=$false)]
        [ValidateScript({ -not [string]::IsNullOrWhiteSpace($_) })]
        [string]$DynamicContentField = 'Dynamic',

        [Parameter(Mandatory=$false)]
        [hashtable]$StaticFields,

        [Parameter(Mandatory=$false)]
        [ValidateRange(0, 100)]
        [int]$ProgressGranularity = 0,

        [Parameter(Mandatory=$false, ValueFromPipeline=$true)]
        [object[]]$Object
    )
    begin{
        if($PSCmdlet.ParameterSetName -eq 'Path') {
            # Strange behavior with this:
            # $TemplateContent = Get-Content -Path $TemplatePath -Raw -Force

            [System.Text.StringBuilder]$Sb = New-Object System.Text.StringBuilder
            [boolean]$FirstLine = $true
            Get-Content -Path $TemplatePath -Force | ForEach-Object {
                if(-not $FirstLine) {
                    $Sb.AppendLine([string]::Empty) > $null
                }
                $FirstLine = $false
                $Sb.Append($_) > $null
            }
            $TemplateContent = $Sb.ToString()
        }
        [MergerRequest]$Request = New-Object MergerRequest -ArgumentList $TemplatePath, $TemplateContent, $FieldWrapper, $DynamicContentField, $StaticFields, $ProgressGranularity
    }
    process{
        foreach($Obj in $Object) {
            $Request.AddObject($Obj)
        }
    }
    end{
        $Request
    }
}
