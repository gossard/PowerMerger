# PowerMerger - A PowerShell Data and Template Merging Engine

**PowerMerger** is a PowerShell tool for generating text files from templates and PowerShell objects. It's designed to automate the creation of reports, configuration files, HTML, and more.

## Key Features

- **Simple Templating:** Use plain text templates with placeholders like `%FieldName%`.
- **Dynamic Sections:** Define blocks in your template that repeat for each object in a collection.
- **Static Placeholders:** Set placeholders that are the same for the entire document (e.g., a report date).
- **Extensible Output Processors:** You decide where the output goes.
  - `OutStringProcessor`: Returns the content as string(s).
  - `OutFileProcessor`: Saves the content to one or more files.
  - You can create your own processors to write to a database, call a REST API, etc. (not yet documented)
- **Progress Bar:** An optional progress bar shows the status when processing large datasets.

## Installation

Clone this repository and import the module directly:
```powershell
Import-Module -Name .\Path\To\PowerMerger.psm1
```

## Quick Start

Let's generate a Markdown user list.

**1. Create a template file (template.md):**

The template contains static placeholders (``%ReportDate%``) and a dynamic section. The content between the two ``%Dynamic%`` markers will be repeated for each data object.

```markdown
# User Report - %ReportDate%

This report was generated for **%CompanyName%**.

---
%Dynamic%
## %Name%
- **ID:** %Id%
- **Email:** %Email%
%Dynamic%
---

End of report.
```

**2. Write your PowerShell script:**

```powershell
# 1. Your data objects
$users = @(
    [pscustomobject]@{ Id = 101; Name = 'Alice'; Email = 'alice@example.com' }
    [pscustomobject]@{ Id = 102; Name = 'Bob';   Email = 'bob@example.com' }
    [pscustomobject]@{ Id = 103; Name = 'Charlie'; Email = 'charlie@example.com' }
)

# 2. Your static data
$staticFields = @{
    ReportDate  = (Get-Date).ToString('yyyy-MM-dd')
    CompanyName = 'My Awesome Corp'
}

# 3. Create a merge request
$request = New-MergerRequest -TemplatePath ".\template.md" -StaticFields $staticFields -Object $users

# 4. Choose an output processor (get the result as a string)
$processor = New-MergerOutStringProcessor

# 5. Run the build process using the pipeline
$result = $request | New-MergerBuild -Processor $processor

# 6. Display the result
$result | Write-Host
```

**Expected Output:**

```markdown
# User Report - 2024-11-03

This report was generated for **My Awesome Corp**.

---
## Alice
- **ID:** 101
- **Email:** alice@example.com
## Bob
- **ID:** 102
- **Email:** bob@example.com
## Charlie
- **ID:** 103
- **Email:** charlie@example.com
---

End of report.
```

## Core Concepts

- `New-MergerRequest`: Creates a request object that holds all the input: the template, the data objects (`-Object`), static fields, and other settings.
- `New-Merger...Processor`: Creates a processor object that defines the output destination.
  - `New-MergerOutStringProcessor`: For in-memory string output.
  - `New-MergerOutFileProcessor`: For saving to file(s).
- `New-MergerBuild`: The engine that takes a `MergerRequest` and a `MergerProcessor` and performs the merge.

## More Examples

### Generating One File Per Object

This is useful for creating individual profile pages, reports, or configuration files.

**1. Create the template file (user-profile.html):**

Notice how the entire HTML structure is enclosed between the two `%Dynamic%` lines. Static placeholders like `%GenerationDate%` will still work correctly inside this block.

```html
%Dynamic%
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>User Profile: %Name%</title>
    <style>
        body { font-family: sans-serif; color: #333; }
        .profile-card { border: 1px solid #ccc; padding: 1em; margin: 1em; border-radius: 8px; max-width: 400px; }
        footer { font-size: 0.8em; color: #777; margin-top: 2em; }
    </style>
</head>
<body>

    <div class="profile-card">
        <h1>%Name%</h1>
        <ul>
            <li><strong>User ID:</strong> %UserID%</li>
            <li><strong>Contact:</strong> %Email%</li>
        </ul>
    </div>

    <footer>
        Page generated on %GenerationDate%.
    </footer>

</body>
</html>
%Dynamic%
```

**2. Write the PowerShell script:**

The script will process each user object, populate the template, and create a unique HTML file for each one.

```powershell
# Data for the user profiles
$users = @(
    [pscustomobject]@{ UserID = 'u-001'; Name = 'Alice'; Email = 'alice@example.com'; HtmlFileName = 'alice-profile' }
    [pscustomobject]@{ UserID = 'u-002'; Name = 'Bob';   Email = 'bob@example.com';   HtmlFileName = 'bob-profile' }
    [pscustomobject]@{ UserID = 'u-003'; Name = 'Charlie'; Email = 'charlie@example.com'; HtmlFileName = 'charlie-profile' }
)

# Static data for the footer
$staticData = @{
    GenerationDate = (Get-Date).ToString('yyyy-MM-dd')
}

# 1. Create the request
$request = New-MergerRequest -TemplatePath ".\user-profile.html" `
    -StaticFields $staticData `
    -Object $users

# 2. Configure the file processor for separate files
#    -PropertyName points to the property on our objects that holds the file name.
$processor = New-MergerOutFileProcessor -PropertyName 'HtmlFileName' -DestDir ".\output_profiles" -Extension ".html"

# 3. Run the build process
$request | New-MergerBuild -Processor $processor

Write-Host "Profile pages generated in '.\output_profiles'"
```

**Result:**

This will create a folder named `output_profiles` containing three files:
- `alice-profile.html`
- `bob-profile.html`
- `charlie-profile.html`

Each file will be a complete HTML page with the specific user's information and the static generation date in the footer.
