$Registry = "cbadcontainerregistry"
$Repo = 'wsw'
$DeleteMode = 'Lenient'
$TagToKeep = "v"
$NumberImagesToKeep = 66
$ImagesDeleted = @()
$ImagesKept = @()
$ImageDeletionFails = @()

Function Get-Tags(){
    az acr repository show-tags --name $Registry --repository $Repo --orderby time_desc --output json | ConvertFrom-Json
}

Function Get-TagsToKeep($TagsList, $TagFilter, $NumberToKeep){
    if ($DeleteMode -eq 'Strict'){
        # Return only the NumberToKeep of the tags matching the TagFilter
        $TagsList | Where-Object {$_ -like "*$TagFilter*"} | Select-Object -First $NumberToKeep
    } else {
        # Otherwise, return a list of tags between the most resent and the
        $IndexTag = ($TagsList | Where-Object {$_ -like "*$TagFilter*"} | Select-Object -First $NumberToKeep)[($NumberToKeep - 1)]
        $Index = [array]::IndexOf($TagsList, $IndexTag)
        $TagsList[0..$Index]
    }
}

# Get all Tags in time descending order
$Tags = Get-Tags

# Identify Tags to keep
$TagsToKeep = Get-TagsToKeep -TagsList $Tags -TagFilter $TagToKeep -NumberToKeep $NumberImagesToKeep

# Delete images if they are older than $date or if the user wants to delete all images which do not include the TagToKeep
foreach ($Tag in $Tags){
    $ImageNameTag = $Repo + ":" + $Tag

    if ($TagsToKeep -NotContains $Tag){
        # az acr repository delete --name $Registry --image $ImageNameTag --yes
        # If the CLI command succeeded, then '$?' is true.
        if ($? -eq $true) {
            $ImagesDeleted += $ImageNameTag
        } else {
            Write-Error "Could not delete image $ImageNameTag."
            $ImageDeletionFails += $ImageNameTag
        }
    } else {
        $ImagesKept += $ImageNameTag
    }
}

Write-Host "Total Images: $($Tags.Count), Images Kept: $($ImagesKept.Count), Images Deleted: $($ImagesDeleted.Count), Image Deletion Fails: $($ImageDeletionFails.Count)"