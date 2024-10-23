using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

# Read the XML content from the request body
$xmlContent = $Request.Body.ReadAsStringAsync().Result

# Load the XML content into an XML document
[xml]$xmlDoc = $xmlContent

# Define the target endpoint URL - endpoint to be defined by LM
$targetUrl = "https://example.com/endpoint"

# Send the XML content to the target endpoint
$response = Invoke-RestMethod -Uri $targetUrl -Method Post -Body $xmlContent -ContentType "application/xml"

# Log the response from the target endpoint
Write-Host "Response from target endpoint: $response"

# Convert the JSON response to PS object
$responseObject = $response | ConvertFrom-Json

# Create a new XML document with only the required fields
$filteredXmlDoc = New-Object System.Xml.XmlDocument
$root = $filteredXmlDoc.CreateElement("response")

# Fields to include from the original XML, The rest should be removed
$originalFields = @(
    "RunID", "CaseID", "CaseRef", "SubCaseID", "SubCaseRef", "CategoryID"
)

# Fields to include from the JSON response from ADP
$jsonFields = @(
    "CallGUID", "CategoryName", "CaseRunSeq", "ResultID", "ResultDesc",
    "DateBegin", "DateEnd", "CallDurationTotal", "CallDurationInt", "CallDurationExt"
)

# Append original fields from the request XML to the converted XML document
foreach ($field in $originalFields) {
    $node = $xmlDoc.SelectSingleNode("//$field")
    if ($node) {
        $importedNode = $filteredXmlDoc.ImportNode($node, $true)
        $root.AppendChild($importedNode) | Out-Null
    }
}

# Append required fields from the JSON response to the converted XML document
foreach ($field in $jsonFields) {
    $newFieldElement = $filteredXmlDoc.CreateElement($field)
    $newFieldElement.InnerText = $responseObject.$field
    $root.AppendChild($newFieldElement) | Out-Null
}

# Finalize the XML document
$filteredXmlDoc.AppendChild($root) | Out-Null

# Convert the XML document to a string
$filteredXmlContent = $filteredXmlDoc.OuterXml

# Return the XML content as the response
$filteredXmlContent

Write-Host "Response has been successfully sent to the client."