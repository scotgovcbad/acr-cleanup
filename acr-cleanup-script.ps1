$tags = az acr repository show-tags --name cbadcontainerregistry --repository wsw --orderby time_desc --output json | ConvertFrom-Json
$tagsToKeep = $tags | Where-Object {$_ -like "*v1*"} | Select-Object -First 3
$images = @()

foreach ($tag in $tagsToKeep){
    #$actualTag = $tag.Replace("`"","").Replace(",","").Trim()
    $images += (az acr repository show --name cbadcontainerregistry --image wsw:$tag --output json | ConvertFrom-Json)
}

$date = $images[2].createdTime

foreach ($tag in $tags){
    $image = az acr repository show --name cbadcontainerregistry --image wsw:$tag --output json | ConvertFrom-Json
    if ($image.createdTime -lt $date)
    {
        Write-Host "Delete the image with tag $tag created on date " + $image.createdTime + " because it is less than $date."
    }
}