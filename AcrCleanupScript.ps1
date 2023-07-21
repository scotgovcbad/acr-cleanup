param (
    [string]$ContainerRegistry,
    [string]$Repository,
    [string]$Strictness,
    [string]$TagToKeep,
    [int]$NumberImagesToKeep,
    [switch]$Testing = $false
)

# Wrapper function so we can mock this behaviour
Function Get-Tags(){
    return (az acr repository show-tags --name $ContainerRegistry --repository $Repository --orderby time_desc --output json | ConvertFrom-Json)
}

# Wrapper function so we can mock this behaviour
Function Remove-SingleImage($Image){
    az acr repository delete --name $ContainerRegistry --image $Image --yes
    # Return true or false depending on if the previous line was successful
    return ($? -eq $true)
}

# Yet another wrapper to assist mocking
# Function Connect-ToAzure() {
#     $creds = ConvertFrom-Json -InputObject $env:AZURE_CREDS    
#     az login --service-principal -u $creds.clientId -p $creds.clientSecret --tenant $creds.tenantId
#     return ($? -eq $true)
# }

Function Get-TagsToKeep($TagsList, $TagFilter, $NumberToKeep){
    Write-Host "Filtering tags..."
    if ($NumberToKeep -eq 0){
        return @()
    }

    $KeepTheseTags = $TagsList | Where-Object {$_ -like "*$TagFilter*"}
    If ($KeepTheseTags.Count -eq 0) {
        return @()
    }

    if ($Strictness -eq 'Strict'){
        # Return only the NumberToKeep of the tags matching the TagFilter
        return ($TagsList | Where-Object {$_ -like "*$TagFilter*"} | Select-Object -First $NumberToKeep)
    } else {
        # Otherwise, return a list of tags between the most recent and the last tag we want to keep
        $IndexTag = ($KeepTheseTags | Select-Object -First $NumberToKeep)[-1]
        $Index = [array]::IndexOf($TagsList, $IndexTag)
        return $TagsList[0..$Index]
    }
}

Function Remove-AllImages() {
    #if (Connect-ToAzure) {
        # Get all Tags in time descending order
        $Tags = Get-Tags
        
        # Identify Tags to keep
        $TagsToKeep = Get-TagsToKeep -TagsList $Tags -TagFilter $TagToKeep -NumberToKeep $NumberImagesToKeep
        
        $ImagesDeleted = @()
        $ImagesKept = @()
        $ImageDeletionFails = @()
    
        # Delete images if they are older than $date or if the user wants to delete all images which do not include the TagToKeep
        foreach ($Tag in $Tags){
            # Initialise this at the start of the loop because concatenation is a bit weird if we try to do it in the middle of the az cli command.
            # Also means we can reuse it.
            $ImageNameTag = $Repository + ":" + $Tag
        
            if ($TagsToKeep -NotContains $Tag) {
                $result = Remove-SingleImage -Image $ImageNameTag
                # If the CLI command succeeded, then '$?' is true.
                if ($result) {
                    $ImagesDeleted += $ImageNameTag
                } else {
                    $ImageDeletionFails += $ImageNameTag
                }
            } else {
                $ImagesKept += $ImageNameTag
            }
        }
        
        return "Total Images: $($Tags.Count), Images Kept: $($ImagesKept.Count), Images Deleted: $($ImagesDeleted.Count), Image Deletion Fails: $($ImageDeletionFails.Count)"    
    #} else {
    #    return "Couldn't connect to Azure. Check credentials are valid and in the correct format."
    #}
}

# Only run cleanup if we're not testing
if ($Testing -eq $false) {
    Write-Host "Live run, script began..."
    Remove-AllImages
    Write-Host "Script finished."
}
