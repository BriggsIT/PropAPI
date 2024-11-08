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
    $Uri = "https://ppouatapi.autodecisioningplatform.com/api/v1/DecisionEngine/Run"
    $params = @{
        Method      = 'POST'
        Uri         = $Uri
        ContentType = 'application/json; charset=utf-8'
        Body        = $jsonContent 
    }
    $QueryResult = Invoke-RestMethod @params
 
    # Log the response from the target endpoint
    Write-Host "Response from target endpoint: $QueryResult"
 
    $Output = @()
    $Output = $Body | Select-Object RunID, BrandID, APIKey, CompanyID, DateSubmitted, CategoryID, CaseID, CaseRef, Properties, SubCaseID, SubCaseRef, Configs
    $Output | Add-Member NoteProperty ResultID $QueryResult.ResultID
    $Output | Add-Member NoteProperty ResultDesc $QueryResult.ResultDesc
 
    $OutputJson = $Output | ConvertTo-Json -Depth 5
 
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        ContentType = "application/json; charset=utf-8"
        Body = $OutputJson
    })
    Write-Host "Response has been successfully sent to the client."
} catch {
    Write-Host "An error occurred: $_"
    Write-Host "Request body: $jsonContent"
    $Response = [HttpResponseMessage]::new([HttpStatusCode]::InternalServerError)
    $Response.Content = [StringContent]::new("An error occurred while processing the request.", [Encoding]::UTF8, "text/plain")
 
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::InternalServerError
        ContentType = "text/plain; charset=utf-8"
        Body = "An error occurred while processing the request."
    })
}
 