$targetSearchServiceName = Read-Host -Prompt "Enter the name of the search service you want to script to prepopulate with data."
$targetAdminKey = Read-Host -Prompt "Enter the admin key for your search service."

$serviceUri = "https://" + $targetSearchServiceName + ".search.windows.net"

$uri = $serviceUri + "/indexes?api-version=2019-05-06"

$headers = @{
    'api-key' = $targetAdminKey
}

#Getting a list of indexes for user selection
$result = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers -ContentType "application/json" | Select-Object -ExpandProperty value

$indexOptions = [System.Collections.ArrayList]::new()
for($indexIdx=0; $indexIdx -lt $result.length; $indexIdx++)
{
	$opt = New-Object System.Management.Automation.Host.ChoiceDescription "$($result[$indexIdx].Name)", "Selects the $($result[$indexIdx].Name) index."   
	$indexOptions.Add($opt)
}
$selectedIndexIdx = $host.ui.PromptForChoice('Enter the desired Index','Copy and paste the name of the index to make your choice.', $indexOptions.ToArray(),0)
$selectedIndexName = $result[$selectedIndexIdx]

#Downloading a copy of the index schema
$uri = $serviceUri + "/indexes/$($selectedIndexName.Name)?api-version=2019-05-06"
$result = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers -ContentType "application/json" |
    ConvertTo-Json -Depth 9 |
    Set-Content "$($selectedIndexName.Name).schema"

#Get Document Count 

#Using .NET WebRequest because of some weird encoding issue in Invoke-RestMethod
#Ref:https://social.technet.microsoft.com/Forums/en-US/26f6a32e-e0e0-48f8-b777-06c331883555/invokewebrequest-encoding?forum=winserverpowershell

$uri = $serviceUri + "/indexes/$($selectedIndexName.Name)/docs/`$count?api-version=2020-06-30"
$req = [System.Net.WebRequest]::Create($uri)

$req.ContentType = "application/json; charset=utf-8"
$req.Accept = "application/json"
$req.Headers["api-key"] = $targetAdminKey

$resp = $req.GetResponse()
$reader = new-object System.IO.StreamReader($resp.GetResponseStream())
$result = $reader.ReadToEnd()
$documentCount = [int]$result

#Downloading Documents
$pageCount = [math]::ceiling($documentCount / 500) 

$job = 1..$pageCount  | ForEach-Object -Parallel {
    $skip = ($_ - 1) * 500
    $uri = $using:serviceUri + "/indexes/$($using:selectedIndexName.name)/docs?api-version=2020-06-30&search=*&`$skip=$($skip)&`$top=500&searchMode=all"
    Invoke-RestMethod -Uri $uri -Method GET -Headers $using:headers -ContentType "application/json" |
        ConvertTo-Json -Depth 9 |
        Set-Content "$($using:selectedIndexName.Name)_$($_).json"
    "Output: $uri"
} -ThrottleLimit 5 -AsJob
$job | Receive-Job -Wait




