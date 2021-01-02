$targetSearchServiceName = Read-Host -Prompt "Enter the name of the search service you want to script to prepopulate with data."
$targetAdminKey = Read-Host -Prompt "Enter the admin key for your search service."

$serviceUri = "https://" + $targetSearchServiceName + ".search.windows.net"

$uri = $serviceUri + "/indexes?api-version=2019-05-06"

$headers = @{
    'api-key' = $targetAdminKey
}

# Selecting a schema file from the list of local schema files
$files = Get-ChildItem "." -Filter *.schema 
if($files.GetType().IsArray -and $files.length -gt 1){
    $indexOptions = [System.Collections.ArrayList]::new()
    for($indexIdx=0; $indexIdx -lt $files.length; $indexIdx++)
    {
        $opt = New-Object System.Management.Automation.Host.ChoiceDescription "$($files[$indexIdx].Name)", "Selects the $($files[$indexIdx].Name) index."   
        $indexOptions.Add($opt)
    }
    $selectedIndexIdx = $host.ui.PromptForChoice('Enter the desired Index','Copy and paste the name of the index to make your choice.', $indexOptions.ToArray(),0)
    $selectedIndexNameFile = $files[$selectedIndexIdx]
}
else {
    $selectedIndexNameFile = $files[0]
}

$indexSchemaFile = Get-Content -Raw -Path $selectedIndexNameFile
$selectedIndexName = ($indexSchemaFile | ConvertFrom-Json).name

# Createing the Index
Write-Host "Creating Target Search Index."

$result = Invoke-RestMethod  -Uri $uri -Method POST -Body $indexSchemaFile -Headers $headers -ContentType "application/json"

# Uploading documents
Write-Host "Starting to upload index documents from saved JSON files."

$uri = $serviceUri + "/indexes/$($selectedIndexName)/docs/index?api-version=2019-05-06"
$files = Get-ChildItem "." -Filter *.json 
foreach ($f in $files){
    $content = Get-Content $f.FullName
    Write-Host "Uploading documents from file" $f.Name
    $result = Invoke-RestMethod  -Uri $uri -Method POST -Body $content -Headers $headers -ContentType "application/json; charset=utf-8"
}

Write-Host "Data upload completed."