using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

try {
    # Read the JSON content from the request body
    $jsonContent = $Request.Body #.ReadAsStringAsync().Result

    # Convert the JSON content to a PS object
    $requestObject = $jsonContent | ConvertFrom-Json

    # Validate the input JSON
    if (-not $requestObject.RunID -or -not $requestObject.BrandID -or -not $requestObject.CompanyID) {
        throw "Invalid input JSON: Missing required fields."
    }

    # Define the target endpoint URL - endpoint to be defined by LM
    $targetUrl = "ppouatapi.autodecisioningplatform.com/api/v2/DecisionEngine/Run"

    # Send the JSON content to the target endpoint
    $response = Invoke-RestMethod -Uri $targetUrl -Method Post -Body $jsonContent -ContentType "application/json"

    # Log the response from the target endpoint
    Write-Host "Response from target endpoint: $response"

    # Convert the JSON response to PS object
    $responseObject = $response | ConvertFrom-Json

    $jsonFields = @(
        "RunID", "BrandID", "APIKey", "CompanyID", "DateSubmitted", "CategoryID",
        "CaseID", "CaseRef", "Properties", "SubCaseID", "SubCaseRef", "Configs"
    )
    
    # Function to add fields to the filtered JSON object
    function Add-Fields {
        param ($sourceObject, $targetObject, $fields)
        foreach ($field in $fields) {
            if ($field -contains ".") {
                $parts = $field -split "\."
                $currentField = $parts[0]
                $remainingField = $parts[1..($parts.Length - 1)] -join "."
                if ($sourceObject.PSObject.Properties.Name -contains $currentField) {
                    if (-not $targetObject[$currentField]) {
                        $targetObject[$currentField] = @{ }
                    }
                    Add-Fields -sourceObject $sourceObject.$currentField -targetObject $targetObject[$currentField] -fields @($remainingField)
                }
            } else {
                if ($sourceObject.PSObject.Properties.Name -contains $field) {
                    $targetObject[$field] = $sourceObject.$field
                }
            }
        }
    }
    
    # Append required fields from the original request to the new JSON object
    Add-Fields -sourceObject $requestObject -targetObject $filteredJsonObject -fields $jsonFields
    
    # Append the new field from the JSON response
    $filteredJsonObject["ResultID"] = $responseObject.ResultID
    
    # Convert the JSON object to a string
    $filteredJsonContent = $filteredJsonObject | ConvertTo-Json
    
    # Return the JSON content as the response
    $Response = [HttpResponseMessage]::new([HttpStatusCode]::OK)
    $Response.Content = [System.Net.Http.StringContent]::new($filteredJsonContent, [System.Text.Encoding]::UTF8, "application/json")
    $Response
    
    Write-Host "Response has been successfully sent to the client."
} catch {
    Write-Host "An error occurred: $_"
    $Response = [HttpResponseMessage]::new([HttpStatusCode]::InternalServerError)
    $Response.Content = [System.Net.Http.StringContent]::new("An error occurred while processing the request.", [System.Text.Encoding]::UTF8, "text/plain")
    $Response
}