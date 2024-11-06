using namespace System.Net
using namespace System.Net.Http
using namespace System.Text

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

try {
    # Read the JSON content from the request body
    $Body = $Request.Body
    $jsonContent = $Body | ConvertTo-Json -Depth 5
    Write-Host "JSON content received: $jsonContent"

    # Log the structure of $Body for debugging
    Write-Host "Body structure: $($Body | ConvertTo-Json -Depth 5)"

    # Validate the input JSON directly
    if (-not $Body.RunID -or -not $Body.BrandID -or -not $Body.CompanyID) {
        Write-Host "RunID: $($Body.RunID)"
        Write-Host "BrandID: $($Body.BrandID)"
        Write-Host "CompanyID: $($Body.CompanyID)"
        throw "Invalid input JSON: Missing required fields."
    }

    # Define the target endpoint URL - endpoint to be defined by LM
    $targetUrl = "https://ppouatapi.autodecisioningplatform.com/api/v1/DecisionEngine/Run"

    # Send the JSON content to the target endpoint
    $response = Invoke-RestMethod -Uri $targetUrl -Method Post -Body $jsonContent -ContentType "application/json"

    # Log the response from the target endpoint
    Write-Host "Response from target endpoint: $response"

    # Convert the response to JSON string
    $responseJson = $response | ConvertTo-Json -Depth 5

    # Convert the JSON response to PS object
    $responseObject = $responseJson | ConvertFrom-Json

    # Create a new JSON object to hold the combined data
    $combinedJsonObject = $Body.PSObject.Copy()

    # Append the new fields from the JSON response
    $combinedJsonObject["ResultID"] = $responseObject.ResultID
    $combinedJsonObject["ResultDesc"] = $responseObject.ResultDesc

    # Convert the combined JSON object to a string
    $combinedJsonContent = $combinedJsonObject | ConvertTo-Json -Depth 5

    # Return the JSON content as the response
    $Response = [HttpResponseMessage]::new([HttpStatusCode]::OK)
    $Response.Content = [StringContent]::new($combinedJsonContent, [Encoding]::UTF8, "application/json")
    
    Write-Host "Response has been successfully sent to the client."
} catch {
    Write-Host "An error occurred: $_"
    Write-Host "Request body: $jsonContent"
    $Response = [HttpResponseMessage]::new([HttpStatusCode]::InternalServerError)
    $Response.Content = [StringContent]::new("An error occurred while processing the request.", [Encoding]::UTF8, "text/plain")
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = $Response.StatusCode
    Body = $Response.Content.ReadAsStringAsync().Result
})