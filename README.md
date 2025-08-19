# PowerMerger

PowerMerger is a PowerShell tool for generating text from templates and data. Its core strength is its simplicity: it processes plain text templates line by line. This straightforward approach makes PowerMerger intuitive and easy to use for common automation tasks, without the overhead of a complex templating language.

- [Key Features](#key-features)
- [Common Use Cases](#common-use-cases)
- [Installation](#installation)
- [Quick Start: Generate a single document](#quick-start-generate-a-single-document)
- [Core Concepts: How Templating Works](#core-concepts-how-templating-works)
- [Working with Real-World Data](#working-with-real-world-data)
- [Advanced Features](#advanced-features)
- [API Reference](#api-reference)
- [Extensibility](#extensibility)
- [License](#license)
  
## Key Features

- **Simple Templating:** Use plain text templates with placeholders like `%FieldName%`.
- **Dynamic Sections:** Define blocks in your template that repeat for each object in a collection.
- **Static Placeholders:** Set placeholders that are the same for the entire document.
- **Extensible Output Processors:** Control where the output goes (string, files, or your own custom logic).
- **Customizable Markers:** Change the default placeholder wrapper (`%`) and dynamic section name to fit your needs.
- **Progress Bar:** An optional progress bar shows the status when processing large datasets.

## Common Use Cases

PowerMerger is a versatile tool that can be used in a wide range of automation scenarios. Here are just a few ideas

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

## Installation

Clone this repository and import the module directly:
```powershell
Import-Module -Name .\Path\To\PowerMerger.psm1
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
$result | Write-Host
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

### Example: Generating a Single Report from Active Directory Users

Let's create a simple HTML contact list for all users in a specific department and save it directly to a single file.

**1. The Template (`ad-report.html`):**

```html
<h1>Sales Department Contacts</h1>
<p>Generated on: %ReportDate%</p>
<hr>
%Dynamic%
<div class="user-card">
  <h3>%GivenName% %Surname%</h3>
  <p>Email: %EmailAddress%</p>
</div>
%Dynamic%
```

**2. The PowerShell script:**

To save the merged output as a single file, we use the `New-MergerOutFileProcessor` in its **Combined** mode by providing the `-FileName` parameter.

```powershell
# We directly use the output of Get-ADUser as our data source.
$users = Get-ADUser -Filter 'Department -eq "Sales"' -Properties GivenName, Surname, EmailAddress

$request = New-MergerRequest -TemplatePath ".\ad-report.html" `
    -StaticFields @{ ReportDate = (Get-Date).ToString('yyyy-MM-dd') } `
    -Object $users

$processor = New-MergerOutFileProcessor -FileName "Sales_Department_Report.html" -DestDir "."
$request | New-MergerBuild -Processor $processor

Write-Host "Report generated successfully at .\Sales_Department_Report.html"
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

**Note:** The destination directory passed to the `-DestDir` parameter must exist.

```powershell
# We use Import-Csv to get our data objects.
$users = Import-Csv -Path ".\users.csv"

# Create the request, adding a static field.
$request = New-MergerRequest -TemplatePath ".\user-profile.html" `
    -StaticFields @{ SystemName = 'PowerMerger Automation' } `
    -Object $users

# Use the OutFileProcessor in "Separated" mode.
# We tell it to use the 'Name' property from each object as the base for the filename.
$processor = New-MergerOutFileProcessor -PropertyName 'Name' -DestDir ".\output" -Extension ".html"
$request | New-MergerBuild -Processor $processor
```

This will create `Alice.html` and `Bob.html` in the `.\output` directory.

## Core Concepts: How Templating Works

PowerMerger templates are simple text files with two main components: **Placeholders** and **Dynamic Sections**.

### 1. Placeholders

Placeholders are markers in your template, like `%FieldName%`, that will be replaced with data. There are two types:

- **Static Placeholders:** These are replaced once for the entire document. You define them using the `-StaticFields` parameter. They work anywhere in your template, both inside and outside of dynamic sections.
- **Object Placeholders:** These correspond to the properties of your data objects (passed via the `-Object` parameter). They are **only replaced inside a Dynamic Section**.

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
Write-Host $result
```

### Using the Progress Bar

For large datasets, you can enable a progress bar using the `-ProgressGranularity` parameter. This parameter specifies how often the progress bar should update, as a percentage. For example, a value of `1` updates the bar every 1% of completion.

```powershell
# 1. Generate a large sample dataset
$largeDataset = 1..200 | ForEach-Object {
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
Status: 100/200
50%
```

*(The visual appearance may vary based on your PowerShell version and host.)*

## API Reference

### `New-MergerRequest`
Creates the main request object. This is typically the first command you'll run.

**Key Parameters:**
-   `-TemplatePath <string>`: Path to the template file.
-   `-TemplateContent <string>`: The template content as a string, instead of from a file.
-   `-StaticFields <hashtable>`: A hashtable of placeholders that are the same for the entire document.
-   `-Object <object[]>`: The collection of objects to be used in the dynamic sections. This can be piped.
-   `-FieldWrapper <string>`: (Optional) The character(s) used to enclose placeholders. Default is `%`.
-   `-DynamicContentField <string>`: (Optional) The name for the dynamic section marker. Default is `Dynamic`.
-   `-ProgressGranularity <int>`: (Optional) Enables and sets the update frequency (in percent) for the progress bar.

### Processors: `New-Merger...Processor`
Processors determine what to do with the generated output. You create one and pass it to `New-MergerBuild`.

-   **`New-MergerOutStringProcessor`**: Returns the generated content as one or more strings. This is useful for further processing in PowerShell.
-   **`New-MergerOutFileProcessor`**: Saves the generated content to files.
    -   **Combined mode:** Use `-FileName <string>` to save all output to a single file.
    -   **Separated mode:** Use `-PropertyName <string>` to specify which property on your objects contains the name for each individual file.
-   **`New-MergerEmptyProcessor`**: Runs the entire build process but discards all output. This is useful for testing or for scenarios where you only need side effects (like the progress bar).

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
class SimpleLogProcessor : MergerProcessor {

    # We want to process each object individually.
    [BuildType]GetRequiredBuildType() {
        return [BuildType]::Separated
    }

    # This is where the logic goes. We use a switch to react to events we care about.
    [void]BuildStateChanged([BuildEvent]$BuildEvent) {
        switch ($BuildEvent.EventType) {
            'BuildBegin' {
                Write-Host "Build is starting..." -ForegroundColor Cyan
            }
            'ContentGenerated' {
                $snippet = $BuildEvent.Content.Trim()
                Write-Host "  -> Content generated for object $($BuildEvent.Object.Name): '$snippet'"
            }
            'BuildEnd' {
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

### 1. Class Structure

Your class must inherit from `MergerProcessor` and implement two methods:

```powershell
class MyCustomProcessor : MergerProcessor {
    [BuildType]GetRequiredBuildType() { /* ... */ }
    [void]BuildStateChanged([BuildEvent]$BuildEvent) { /* ... */ }
}
```

### 2. `GetRequiredBuildType()` Method

This method controls how the content is generated and sent to your processor.

- **`[BuildType]::Separated`**: Your processor will receive a `ContentGenerated` event **for each object** in the data collection. This is ideal for generating separate files or performing an action for each item.
- **`[BuildType]::Combined`**: Your processor will receive a **single** `ContentGenerated` event at the very end, containing the fully merged content for all objects. This is ideal for generating a single report or file.

### 3. BuildStateChanged(`[BuildEvent]$BuildEvent`) Method

This is the heart of your processor. It's an event handler that is called multiple times during the build lifecycle. You can inspect the `$BuildEvent.EventType` property to decide what to do.

The `$BuildEvent` object contains all the context about the current state of the build. Here are the different event types and the data available for each:

| EventType          | Key Data Available in `$BuildEvent` | description |
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
}
```

## License

MIT License. See the `LICENSE` file for more details.
