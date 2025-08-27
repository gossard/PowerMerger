# PowerMerger

PowerMerger is a PowerShell tool for generating text from templates and data. It was born from a personal need for a straightforward automation tool and is shared in the hope that it might be useful to others.

Instead of a complex templating language, PowerMerger uses a simple, line-by-line "find and replace" approach, enhanced with the ability to repeat dynamic sections for your data.

Because of this, PowerMerger is not a replacement for full-featured engines like Mustache or Scriban. If your templates require conditional logic (if/else), loops, or other advanced features, those tools are a better choice. Its value lies in its minimal learning curve and its ability to solve the most common automation tasks quickly and without complexity.

- [Key Features](#key-features)
- [Common Use Cases](#common-use-cases)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Quick Start: Generate a single document](#quick-start-generate-a-single-document)
- [Core Concepts: How Templating Works](#core-concepts-how-templating-works)
- [Working with Real-World Data](#working-with-real-world-data)
- [Advanced Features](#advanced-features)
- [Encoding](#encoding)
- [API Reference](#api-reference)
- [Extensibility](#extensibility)
- [Known Limitations](#known-limitations)
- [License](#license)
  
## Key Features

- **Simple Templating:** Use plain text templates with placeholders like `%FieldName%`.
- **Dynamic Sections:** Define blocks in your template that repeat for each object in a collection.
- **Static Placeholders:** Set placeholders that are the same for the entire document.
- **Extensible Output Processors:** Control where the output goes (string, files, or your own custom logic).
- **Customizable Markers:** Change the default placeholder wrapper (`%`) and dynamic section name to fit your needs.
- **Progress Bar:** An optional progress bar shows the status when processing large datasets.

## Common Use Cases

PowerMerger is a versatile tool that can be used in a wide range of automation scenarios. Here are just a few ideas:

- **IT Reporting:**
  - Generate daily HTML reports on the status of Active Directory users or computers.
  - Create CSV summaries from complex PowerShell objects.
  - Build Markdown documentation for your infrastructure.

- **Configuration Management:**
  - Create JSON or XML configuration files for a fleet of servers based on a CSV input file.
  - Generate PowerShell DSC (Desired State Configuration) files from a central data source.
  - Automate the creation of SQL scripts for database setup or migrations.

- **Communications:**
  - Generate personalized letters or documents.

- **Development & DevOps:**
  - Scaffold new code modules or classes from templates.
  - Generate deployment scripts tailored to different environments (Dev, Test, Prod).

## Prerequisites
- PowerShell:
  - Windows PowerShell 5.1 (WMF 5.1) or PowerShell 7+ (recommended, cross‑platform).
  - Uses PowerShell classes (available since 5.1).
- Supported OS: Windows, Linux, macOS.

## Installation

The recommended way to install PowerMerger is to place it in your PowerShell module path. This is the standard practice for PowerShell modules and allows PowerShell to find and load it automatically by name.

This method ensures that all features, including creating custom processors with `using module PowerMerger`, work correctly and that your scripts remain portable.

**1. Clone the repository into your module directory.**

The following command automatically finds the correct path for the current user and clones the module into a `PowerMerger` subfolder, which is the required structure.

```powershell
# This command clones the repo into the first path listed in your PSModulePath
# (usually C:\Users\<YourName>\Documents\PowerShell\Modules)
$modulePath = ($env:PSModulePath -split ';')[0]
git clone https://github.com/gossard/PowerMerger.git (Join-Path $modulePath "PowerMerger")
```

**2. Import the module.**

```powershell
# Import by name (required for PS 5.1, automatic in PS 7+)
Import-Module PowerMerger
```

## Quick Start: Generate a single document

This example generates one plain text report from a list of users.

**1. Create the template file (`template.txt`):**

```
User Report - %ReportDate%
=========================

%Dynamic%
- User: %Name% (ID: %Id%)
%Dynamic%
```

**2. Write the PowerShell script:**

```powershell
$users = @(
    [pscustomobject]@{ Id = 101; Name = 'Alice' }
    [pscustomobject]@{ Id = 102; Name = 'Bob' }
)

$request = New-MergerRequest -TemplatePath ".\template.txt" `
    -StaticFields @{ ReportDate = (Get-Date).ToString('yyyy-MM-dd') } `
    -Object $users

$processor = New-MergerOutStringProcessor

$result = $request | New-MergerBuild -Processor $processor
$result | Write-Output
```

**3. Check the expected output:**

```
User Report - 2024-11-03
=========================

- User: Alice (ID: 101)
- User: Bob (ID: 102)
```

## Working with Real-World Data

The examples so far use manually created data for clarity. However, the real power of PowerMerger comes from using it with data from any PowerShell command.

The core principle is simple: if a command returns a collection of objects, you can use it as a data source for PowerMerger. This includes `Get-ADUser`, `Get-Process`, `Get-Service`, `Import-Csv`, and countless others.

Here are a few practical examples.

### Example: Generating a Single Report from System Processes

Let's create a simple HTML report listing the top 10 running processes, sorted by memory usage, and save it directly to a single file.

**1. The Template (`process-report.html`):**

```html
<!DOCTYPE html>
<html>
<head>
    <title>Process Report</title>
</head>
<body>
    <h1>Running Processes Report</h1>
    <p>Generated on: %ReportDate%</p>
    <hr>
    <table border="1" cellpadding="5" cellspacing="0">
        <thead>
            <tr>
                <th>Process Name</th>
                <th>ID</th>
                <th>Memory (Working Set)</th>
            </tr>
        </thead>
        <tbody>
            %Dynamic%
            <tr>
                <td>%Name%</td>
                <td>%Id%</td>
                <td>%WorkingSet%</td>
            </tr>
            %Dynamic%
        </tbody>
    </table>
</body>
</html>
```

**2. The PowerShell script:**

To save the merged output as a single file, we use the `New-MergerOutFileProcessor` in its **Combined** mode by providing the `-FileName` parameter.

```powershell
# 1. Get the top 10 processes by memory usage. 
#    This command works on any system.
$processes = Get-Process | Sort-Object -Property WorkingSet -Descending | Select-Object -First 10

# 2. Create the request, using the template and providing a static field for the date.
#    The process list is passed to the -Object parameter.
$request = New-MergerRequest -TemplatePath ".\process-report.html" `
    -StaticFields @{ ReportDate = (Get-Date).ToString('yyyy-MM-dd HH:mm') } `
    -Object $processes

# 3. Create the processor to output to a single file.
$processor = New-MergerOutFileProcessor -FileName "Process_Report.html" -DestDir "."

# 4. Execute the build and generate the report.
$request | New-MergerBuild -Processor $processor

Write-Host "Report generated successfully at .\Process_Report.html"
```

### Example: Generating Multiple Files from a CSV

This is a common pattern for creating multiple configuration files or individual reports. Let's generate individual HTML profile pages for users listed in a CSV file.
Notice there is no special "FileName" column. We'll use the `Name` column directly.

**1. The CSV file (`users.csv`):**

```csv
UserID,Name
u-001,Alice
u-002,Bob
```

**2. The Template (`user-profiles.html`):**

```html
%Dynamic%
<!DOCTYPE html>
<html>
<head><title>User Profile: %Name%</title></head>
<body>
    <h1>%Name%</h1>
    <p>User ID: %UserID%</p>
    <footer>Generated by %SystemName%</footer>
</body>
</html>
%Dynamic%
```

**3. The PowerShell Script:**

```powershell
# We use Import-Csv to get our data objects.
$users = Import-Csv -Path ".\users.csv"

# Create the request, adding a static field.
$request = New-MergerRequest -TemplatePath ".\user-profiles.html" `
    -StaticFields @{ SystemName = 'PowerMerger Automation' } `
    -Object $users

# Use the OutFileProcessor in "Separated" mode.
# We tell it to use the 'Name' property from each object as the base for the filename.
# The destination directory will be created if it doesn't exist.
$processor = New-MergerOutFileProcessor -PropertyName 'Name' -DestDir ".\output"

$request | New-MergerBuild -Processor $processor
```

This will create `Alice.html` and `Bob.html` in the `.\output` directory.

## Core Concepts: How Templating Works

PowerMerger templates are simple text files with two main components: **Placeholders** and **Dynamic Sections**.

### 1. Placeholders

Placeholders are markers in your template, like `%FieldName%`, that will be replaced with data. There are two types:

- **Static Placeholders:** These are replaced once for the entire document. You define them using the `-StaticFields` parameter. They work anywhere in your template, both inside and outside of dynamic sections.
- **Object Placeholders:** These correspond to the properties of your data objects (passed via the `-Object` parameter). They are **only replaced inside a Dynamic Section**.

You can also access nested properties using standard dot notation. For example, given an object like this:

```powershell
$data = @{
    User = @{
        Name = 'Alice'
        Address = @{
            City = 'Paris'
        }
    }
}
```

You could use the following placeholders in your template:
- `%User.Name%` would be replaced with `Alice`.
- `%User.Address.City%` would be replaced with `Paris`.

### 2. Dynamic Sections

A Dynamic Section is a block of text that repeats for every object in your data collection. You can have **multiple, independent dynamic sections** in a single template to build complex documents.

**Example with multiple sections (`report.md`):**

```markdown
# Weekly Report - %GenerationDate%

## User Summary Table
| User Name |
|-----------|
%Dynamic%
| %Name%    |
%Dynamic%

---

## Detailed User Profiles
%Dynamic%
### Profile for %Name%
- **User ID:** %Id%
- **Status:** Active
%Dynamic%
```

In this example, PowerMerger will first loop through all users to build the summary table, and then loop through them again to build the detailed profiles section.

### 3. The Golden Rule of Syntax

Because the engine processes templates by reading them line by line, it imposes one critical rule:

**Rule:** The dynamic section marker (e.g., `%Dynamic%`) **must be on its own line**.

**Correct:**
```
A static field like %MyCompany%
%Dynamic%
Hello %UserName%
%Dynamic%
```

**Incorrect:**
```
A static field like %MyCompany%
%Dynamic% Hello %UserName% %Dynamic%
```

## Advanced Features

### Customizing Markers

Use `-FieldWrapper` and `-DynamicContentField` to change the default markers. This is useful when the defaults conflict with your template's syntax (e.g., in SQL). For example, the template below uses `@@FieldName@@` for placeholders and `@@REPEAT@@` as the dynamic section marker.

**Template (`template.sql`):**

```sql
-- Batch job for user: @@RunAsUser@@
-- Generated on: @@Timestamp@@

@@REPEAT@@
-- Processing item @@ItemID@@
INSERT INTO Logs (ItemID, Description) VALUES ('@@ItemID@@', 'Processed by @@RunAsUser@@');
GO
@@REPEAT@@
```

**PowerShell script:**

```powershell
$items = @(
    [pscustomobject]@{ ItemID = 'A-101' },
    [pscustomobject]@{ ItemID = 'B-202' }
)

$request = New-MergerRequest -TemplatePath ".\template.sql" `
    -FieldWrapper "@@" `
    -DynamicContentField "REPEAT" `
    -StaticFields @{ RunAsUser = 'sa'; Timestamp = (Get-Date) } `
    -Object $items

$processor = New-MergerOutStringProcessor

$result = $request | New-MergerBuild -Processor $processor
$result | Write-Output
```

### Using the Progress Bar

For large datasets, you can enable a progress bar using the `-ProgressGranularity` parameter. This parameter specifies how often the progress bar should update, as a percentage. For example, a value of `1` updates the bar every 1% of completion.

```powershell
# 1. Generate a large sample dataset
$largeDataset = 1..2000 | ForEach-Object {
    [pscustomobject]@{ Id = $_; Name = "Item-$_" }
}

# 2. Define a simple multi-line template directly in the script using a here-string.
$templateContent = @'
%Dynamic%
- Item %Id% processed.
%Dynamic%
'@

# 3. Create the request with a progress bar that updates every 5%.
$request = New-MergerRequest -TemplateContent $templateContent `
    -Object $largeDataset `
    -ProgressGranularity 5

# 4. For this example, we use the New-MergerEmptyProcessor. 
#    This processor runs the entire build process but does nothing with the output,
#    which is perfect for demonstrating the progress bar without cluttering the console.
$processor = New-MergerEmptyProcessor

$request | New-MergerBuild -Processor $processor
```

**Expected Behavior:**

When you run this script, a progress bar will appear and update as the items are processed, but no text output will be generated.

```
MergingObject
[ooooooooooooooooooooooooooooooooooooooooooooooooo                               ]
Status: 1000/2000
50%
```

*(The visual appearance may vary based on your PowerShell version and host.)*

## Encoding

- `New-MergerOutFileProcessor` writes files using PowerShell’s `Out-File` and therefore inherits PowerShell’s default encoding:
  
  | PowerShell version       | Default encoding        |
  |--------------------------|-------------------------|
  | Windows PowerShell 5.1   | UTF-16 LE with BOM      |
  | PowerShell 7+            | UTF-8 (no BOM)          |

- `New-MergerOutStringProcessor` returns strings (no encoding is applied until you save them yourself).
- `New-MergerEmptyProcessor` does not write any output.
- Custom processors can choose their own encoding; consider exposing an -Encoding parameter.

Explicit encoding support for the built-in OutFile processor will be added in a future release.

Workaround: set a session-level default for Out-File:

```powershell
# Session-level default for Out-File (with restore afterwards)
$prevEncoding = $PSDefaultParameterValues['Out-File:Encoding']
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'   # or 'utf8BOM', 'ascii', etc.

# ... run PowerMerger build(s) here ...

if ($null -ne $prevEncoding) {
  $PSDefaultParameterValues['Out-File:Encoding'] = $prevEncoding
} else {
  $PSDefaultParameterValues.Remove('Out-File:Encoding') | Out-Null
}
```
  
## API Reference

### `New-MergerRequest`
Creates the main request object. This is typically the first command you'll run.

**Key Parameters:**
- `-TemplatePath <string>`: Path to the template file.
- `-TemplateContent <string>`: The template content as a string, instead of from a file.
- `-StaticFields <hashtable>`: A hashtable of placeholders that are the same for the entire document.
- `-Object <object[]>`: The collection of objects to be used in the dynamic sections. This can be piped.
- `-FieldWrapper <string>`: (Optional) The character(s) used to enclose placeholders. Default is `%`.
- `-DynamicContentField <string>`: (Optional) The name for the dynamic section marker. Default is `Dynamic`.
- `-ProgressGranularity <int>`: (Optional) Enables and sets the update frequency (in percent) for the progress bar.

### Processors: `New-Merger...Processor`
Processors determine what to do with the generated output. You create one and pass it to `New-MergerBuild`.

- **`New-MergerOutStringProcessor`**: Returns the generated content as one or more strings. This is useful for further processing in PowerShell.
- **`New-MergerOutFileProcessor`**: Saves the generated content to files.

  **Behavior Details:**

  * **Destination Directory:** The `-DestDir <string>` parameter is optional and defaults to the current directory (`.`). The directory will be created if it does not exist.

  *   **File Naming**
      - **Combined Mode (`-FileName`):** The entire output is saved to a single file. The name is taken directly from the `-FileName` parameter.
      - **Separated Mode (`-PropertyName`):** A separate file is created for each object. The base name of each file is taken from the value of the property you specify. **Nested properties are supported using dot notation (e.g., `-PropertyName 'User.FileName'`).**
        - **Fallback:** If an object's property is null or empty, a fallback name like `noname(index-01)` is automatically generated.

  *   **File Extension Logic**
      The processor determines the file extension using the following priority:
      1.  It will always use the value from the `-Extension` parameter if provided.
      2.  If `-Extension` is not provided, it tries to infer the extension from another source:
          - In **Combined mode**: from the `-FileName` parameter (e.g., `report.html` implies `.html`).
          - In **all modes**: as a last resort, from the template file path (`-TemplatePath`).

  *   **Important Rules**
      - **Overwriting:** Existing files at the destination **will be overwritten** without warning (uses `Out-File -Force`).
      - **No Sanitization:** Filenames are used as-is. If a property contains characters that are invalid for a filename (like `:`, `\`, or `?`), the operation will fail for that file.

### `New-MergerBuild`
The engine that executes the merge operation. It takes a `MergerRequest` and a `MergerProcessor`. It's designed to be used at the end of a pipeline.

**Usage:**
```powershell
$request | New-MergerBuild -Processor $processor
```

## Extensibility

PowerMerger is designed to be extensible. You can create your own custom processors without modifying the module's source code, allowing you to send output to any target, like a database, a REST API, or a custom log file.

The core idea is simple: you create a PowerShell class that acts as an "event listener" during the build process, reacting to events like `BuildBegin` or `ContentGenerated`.

### A Simple Example: A Basic Log Processor

Let's start with a minimal but useful example. This processor logs key events to the console, including a snippet of the content as it's generated.

**1. Save this class definition in a file named `MyProcessors.ps1`:**

```powershell
using module PowerMerger

class SimpleLogProcessor : MergerProcessor {

    # We want to process each object individually.
    [BuildType]GetRequiredBuildType() {
        return [BuildType]::Separated
    }

    # This is where the logic goes. We use a switch to react to events we care about.
    [void]BuildStateChanged([BuildEvent]$BuildEvent) {
        switch ($BuildEvent.EventType) {
            ([BuildEventType]::BuildBegin) {
                Write-Host "Build is starting..." -ForegroundColor Cyan
            }
            ([BuildEventType]::ContentGenerated) {
                $snippet = $BuildEvent.Content.Trim()
                Write-Host "  -> Content generated for object $($BuildEvent.Object.Name): '$snippet'"
            }
            ([BuildEventType]::BuildEnd) {
                Write-Host "Build has finished. $($BuildEvent.ObjectCount) objects processed." -ForegroundColor Cyan
            }
        }
    }

}
```

**2. Use it in your main script:**

```powershell
# Load the custom class
. ".\MyProcessors.ps1"

# Prepare a request
$users = @(
    [pscustomobject]@{ Name = 'Alice' },
    [pscustomobject]@{ Name = 'Bob' }
)
$templateContent = @'
%Dynamic%
Hello, %Name%!
%Dynamic%
'@
$request = New-MergerRequest -TemplateContent $templateContent -Object $users

# Instantiate and use your new processor
$logProcessor = [SimpleLogProcessor]::new()
$request | New-MergerBuild -Processor $logProcessor
```

**Expected output:**

```
Build is starting...
  -> Content generated for object Alice: 'Hello, Alice!'
  -> Content generated for object Bob: 'Hello, Bob!'
Build has finished. 2 objects processed.
```

As you can see, creating a custom processor is straightforward. You only need to implement logic for the events you care about.

### The Processor Contract in Detail

For more advanced scenarios, you need to understand the full contract for a `MergerProcessor`.

#### 1. Class Structure

Your class must inherit from `MergerProcessor` and implement two methods:

```powershell
class MyCustomProcessor : MergerProcessor {
    [BuildType]GetRequiredBuildType() { /* ... */ }
    [void]BuildStateChanged([BuildEvent]$BuildEvent) { /* ... */ }
}
```

#### 2. `GetRequiredBuildType()` Method

This method controls how the content is generated and sent to your processor.

- **`[BuildType]::Separated`**: Your processor will receive a `ContentGenerated` event **for each object** in the data collection. This is ideal for generating separate files or performing an action for each item.
- **`[BuildType]::Combined`**: Your processor will receive a **single** `ContentGenerated` event at the very end, containing the fully merged content for all objects. This is ideal for generating a single report or file.

#### 3. BuildStateChanged(`[BuildEvent]$BuildEvent`) Method

This is the heart of your processor. It's an event handler that is called multiple times during the build lifecycle. You can inspect the `$BuildEvent.EventType` property to decide what to do.

The `$BuildEvent` object contains all the context about the current state of the build. Here are the different event types and the data available for each:

| EventType          | Key Data Available in `$BuildEvent` | Description |
| ------------------ | ----------------------------------- | ----------- |
| `BuildBegin`       | `.Request`                          | Fired once at the very beginning. Useful for initialization tasks (e.g., opening a file or connection).
| `MergingObject`    | `.Object`, `.ObjectCount`           | Fired for each object before its content is merged. Useful for logging or progress updates.
| `ContentGenerated` | `.Content`, `.Object`               | Fired after content has been generated. This is where most processors do their main work.
| `BuildEnd`         | `.ObjectCount`                      | Fired once at the very end. Useful for cleanup tasks (e.g., closing connections, writing footers).

### Storing Output

If your processor needs to return data, add it to the `$this.Output` list property, which is inherited from `MergerProcessor`. Anything in this list will be returned by `New-MergerBuild`. This is exactly how the built-in `New-MergerOutStringProcessor` works:

```powershell
[void]BuildStateChanged([BuildEvent]$BuildEvent) {
        if($BuildEvent.EventType -eq [BuildEventType]::ContentGenerated) {
            $this.Output.Add($BuildEvent.Content)
        }
}
```

## Known Limitations

- **Dynamic Sections:**
  - The dynamic marker (e.g., `%Dynamic%`) must be on its own line and appear in pairs (open/close).
  - Nested dynamic sections are not supported.
- **Replacement Scope:**
  - Object placeholders (from your data objects) are only replaced inside dynamic sections.
  - Static placeholders (provided via `-StaticFields`) are replaced everywhere.
  - Missing or null properties render as an empty string inside dynamic sections.
- **Placeholders:**
  - Field wrappers are symmetric (e.g., `%...%`, `@@...@@`). With the current implementation, avoid wrappers that contain regex metacharacters (`.`, `+`, `*`, `|`, etc.).
  - There is no built-in escaping to render a placeholder literally (e.g., to output "%Name%" verbatim).
- **Property Access:** Nested properties (e.g., `User.Address.City`) are supported, but accessing collection items by index (e.g., `Items[0]`) is not.
- **Collection Formatting:** Array or collection properties are rendered via `.ToString()` (often as “System.Object[]”). They should be pre-formatted into a string (e.g., with `-join ', '`) before merging.
- **Memory/Performance:**
  - In `Combined` mode, the entire output is aggregated in memory before emission. For very large data sets, prefer `Separated` mode.
- **Misc:**
  - Unreplaced placeholders remain as-is in the output.
  - No conditional logic or loops beyond repeating dynamic sections.
  - The progress bar relies on `Write-Progress` and may not display in non-interactive hosts.

## License

MIT License. See the `LICENSE` file for more details.
