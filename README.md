# acr-cleanup
A GitHub Action which will clean up a given Azure Container Registry repo.

## Inputs
| Paramater | Description | Type
|---|---|---|
| ContainerRegistry | The name of the Azure Container Registry in question. | String
| Repository | The name of the repository to cleanse within ContainerRegistry. | String
| Strictness | A deletion mode, either "Strict" of "Lenient". | String
| TagToKeep | A string which, if found in an image tag, will mark that tag as to be kept. | String
| NumberImagesToKeep | The number of images to keep of those which contain TagToKeep. | Int

## How It Works
The script gets all the image tags from the given container registry in descending time order. A sub-list is made of the tags from the first tag to the n-th tag (where n is the NumberImagesToKeep) which contains TagToKeep. "Lenient" strictness means the script will keep (i.e. not delete) any tags in the sub-list which do not contain TagToKeep. "Strict" strictness means the script will keep (i.e. not delete) only those tags in the sub-list which contain TagToKeep. 

## Strictness - A Worked Example
Given a scenario where `TagToKeep = v` and `NumberImagesToKeep = 2`, the script would keep/delete the following images:

| Tag | "Strict" | "Lenient"
|---|---|---
|Build-124| Delete | Keep
|v1.0.22-20221010| Keep | Keep
|Build-Master-33| Delete | Keep
|Build-123| Delete | Keep
|Build-122| Delete | Keep
|Build-121| Delete | Keep
|v1.0.21-20220909| Keep | Keep
|Build-Master-32| Delete | Delete
|Build-120| Delete | Delete
|Build-119| Delete | Delete
|v1.0.20-20220808| Delete | Delete

## No Tag Matches
If no tags match the TagToKeep string, **all** tags will be deleted.

## Example Usage
```yaml
name: Smoke Test

on: 
  workflow_dispatch:
  
jobs: 
  smoke-test:
    runs-on: windows-latest

    steps:
    - uses: actions/checkout@master   

    - name: Run cleansing action
      uses: scotgovcbad/acr-cleanup@Add-az-login
      with:
        azure-credentials: ${{ secrets.ACTUAL_AZURE_CREDENTIALS }}
        container-registry: "cbadcontainerregistry"
        repo: "wsw"
        tag: "v"
        number-to-keep: 100
        strictness: "Lenient"
```