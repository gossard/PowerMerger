# Built on 08/28/2025 11:37:27

# --- Content from PreContent.ps1 ---

using namespace System
using namespace System.Text
using namespace System.IO
using namespace System.Collections.Generic
using namespace System.Text.RegularExpressions

# --- Content from 00.util.ps1 ---

class PowerMergerUtils {

    hidden PowerMergerUtils() {
        throw [InvalidOperationException]::new("Cannot instantiate 'PowerMergerUtils'.")
    }

    static [object]GetNestedPropertyValue([object]$BaseObject, [string]$PropertyPath) {
        if(($null -eq $BaseObject) -or [string]::IsNullOrWhiteSpace($PropertyPath)) {
            return $null
        }
        [string[]]$Properties = $PropertyPath.Split('.')
        [object]$CurrentObject = $BaseObject

        foreach($Property in $Properties) {
            if($null -eq $CurrentObject) {
                return $null
            }
            $PropertyInfo = $CurrentObject.psobject.Properties[$Property]
            if($null -eq $PropertyInfo) {
                return $null
            }
            $CurrentObject = $PropertyInfo.Value
        }
        return $CurrentObject
    }

}

# --- Content from 01.field.ps1 ---

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
        [Match]$Match = [regex]::Match($Field, $this.Pattern)
        if($Match.Success) {
            return $Match.Groups[1].Value
        }
        return $Field
    }

}

class FieldResolver {

    [FieldFormat]$FieldFormat

    FieldResolver([FieldFormat]$FieldFormat) {
        $this.FieldFormat = $FieldFormat
    }

    [object]Resolve([object]$Object, [string]$Field) {
        if($null -eq $Object) {
            return $null
        }
        [string]$PropertyPath = $this.FieldFormat.Unformat($Field)

        return [PowerMergerUtils]::GetNestedPropertyValue($Object, $PropertyPath)
    }

}

# --- Content from 02.request.ps1 ---

class MergerRequest {

    [string]$TemplatePath
    [string]$TemplateContent
    [FieldFormat]$FieldFormat
    [string]$DynamicContentField
    [hashtable]$StaticFields
    [int]$ProgressGranularity
    [List[object]]$Objects

    MergerRequest(
        [string]$TemplatePath,
        [string]$TemplateContent,
        [string]$FieldWrapper,
        [string]$DynamicContentField,
        [hashtable]$StaticFields,
        [int]$ProgressGranularity) {

        $this.TemplatePath = $TemplatePath
        $this.TemplateContent = $TemplateContent
        $this.FieldFormat = [FieldFormat]::new($FieldWrapper)
        $this.DynamicContentField = $this.FieldFormat.Format($DynamicContentField)
        $this.StaticFields = @{}
        foreach($Key in $StaticFields.Keys) {
            $this.StaticFields[$this.FieldFormat.Format($Key)] = $StaticFields[$Key]
        }
        $this.ProgressGranularity = $ProgressGranularity
        $this.Objects = [List[object]]::new()
    }

    [void]AddObject([object]$Object) {
        if($null -ne $Object) {
            $this.Objects.Add($Object)
        }
    }

}

# --- Content from 03.event.ps1 ---

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

# --- Content from 04.buildtype.ps1 ---

enum BuildType {
    Combined
    Separated
}

# --- Content from 05.processor.ps1 ---

<# abstract #> class MergerProcessor : BuildListener {

    [List[object]]$Output

    MergerProcessor() : base() {
        $this.Output = [List[object]]::new()
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
                $this.Extension = [Path]::GetExtension($Path)
            }
        }
    }

    hidden [void]OutFile([BuildEvent]$BuildEvent) {
        [string]$FileName = [string]::Empty
        if($this.IsCombined()) {
            $FileName = $this.FileOrProperty
        } else {
            $FileName = [PowerMergerUtils]::GetNestedPropertyValue($BuildEvent.Object, $this.FileOrProperty)
            if([string]::IsNullOrWhiteSpace($FileName)) {
                $FileName = $this.GenerateFileName($BuildEvent)
            }
        }
        $FileName = [Path]::ChangeExtension($FileName, $this.Extension)
        New-Item -Path $this.DestDir -ItemType Directory -Force
        [string]$FilePath = Join-Path $this.DestDir -ChildPath $FileName
        Out-File -FilePath $FilePath -InputObject $BuildEvent.Content -Force
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
        return $this.BuildType -eq [BuildType]::Combined
    }

    [BuildType]GetRequiredBuildType() {
        return $this.BuildType
    }

}

# --- Content from 06.progress.ps1 ---

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

# --- Content from 07.builder.ps1 ---

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
    [HashSet[string]]$Fields

    DynamicContent([string]$PlaceholderField) : base() {
        $this.PlaceholderField = $PlaceholderField
        $this.Fields = [HashSet[string]]::new()
    }

    [bool]IsDynamic() {
        return $true
    }

}

class MergerBuilder {

    [MasterContent]$MasterContent
    [List[DynamicContent]]$DynamicContents
    [MergerRequest]$Request
    [MergerProcessor]$Processor
    [List[BuildListener]]$Listeners
    [BuildEvent]$BuildEvent
    [FieldResolver]$FieldResolver

    [System.Collections.Generic.List[object]]Build([MergerRequest]$Request, [MergerProcessor]$Processor) {
        $this.MasterContent = [MasterContent]::new()
        $this.DynamicContents = [List[DynamicContent]]::new()
        $this.Request = $Request
        $this.Processor = $Processor
        $this.Listeners = [List[BuildListener]]::new()
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
        foreach($Dynamic in $this.DynamicContents) {
            $Dynamic.Tmp.ReplaceFields($this.Request.StaticFields)
        }
        # ==============
        # Init Templates
        # ==============
        $this.MasterContent.Template = $this.MasterContent.Tmp.ToString()
        foreach($Dynamic in $this.DynamicContents) {
            $Dynamic.Template = $Dynamic.Tmp.ToString()
        }
        # ===================
        # Find Dynamic Fields
        # ===================
        foreach($Dynamic in $this.DynamicContents) {
            $MatchInfos = Select-String -InputObject $Dynamic.Template -Pattern $this.Request.FieldFormat.Pattern -AllMatches
            foreach($Match in $MatchInfos.Matches) {
                $Dynamic.Fields.Add($Match.Value)
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
        foreach($Listener in $this.Listeners) {
            $Listener.BuildStateChanged($BuildEvent)
        }
    }

}

# --- Content from New-MergerBuild.ps1 ---

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
        ([MergerBuilder]::new()).Build($Request, $Processor)
    }
}

# --- Content from New-MergerEmptyProcessor.ps1 ---

function New-MergerEmptyProcessor {
    [CmdletBinding()]
    [OutputType([EmptyProcessor])]
    param(
        [Parameter(Mandatory=$false)]
        [ValidateNotNull()]
        [BuildType]$BuildType = [BuildType]::Combined
    )
    [EmptyProcessor]::new($BuildType)
}

# --- Content from New-MergerOutFileProcessor.ps1 ---

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

        [Parameter(Mandatory=$false)]
        [ValidateScript({ -not [string]::IsNullOrWhiteSpace($_) })]
        [string]$DestDir = '.',

        [Parameter(Mandatory=$false)]
        [string]$Extension
    )
    if($PSCmdlet.ParameterSetName -eq 'Combined') {
        [OutFileProcessor]::new([BuildType]::Combined, $FileName, $DestDir, $Extension)
    } else {
        [OutFileProcessor]::new([BuildType]::Separated, $PropertyName, $DestDir, $Extension)
    }
}

# --- Content from New-MergerOutStringProcessor.ps1 ---

function New-MergerOutStringProcessor {
    [CmdletBinding()]
    [OutputType([OutStringProcessor])]
    param(
        [Parameter(Mandatory=$false)]
        [ValidateNotNull()]
        [BuildType]$BuildType = [BuildType]::Combined
    )
    [OutStringProcessor]::new($BuildType)
}

# --- Content from New-MergerRequest.ps1 ---

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

            [StringBuilder]$Sb = [StringBuilder]::new()
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
        [MergerRequest]$Request = [MergerRequest]::new(
            $TemplatePath, $TemplateContent, $FieldWrapper, $DynamicContentField, $StaticFields, $ProgressGranularity)
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

# --- Content from PostContent.ps1 ---


