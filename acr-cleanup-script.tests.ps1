BeforeAll {
    . $PSScriptRoot/acr-cleanup-script.ps1 -Testing $true
    $TestTags = @(
        "Build-124",
        "v1.0.22-20221010",
        "Build-Master-33",
        "Build-123",
        "Build-122",
        "Build-121",
        "v1.0.21-20220909",
        "Build-Master-32",
        "Build-120",
        "Build-119",
        "v1.0.20-20220808"
    )

    # Set up default mocks
    Mock Get-Tags -MockWith { $TestTags }
    Mock Delete-Image { return $true }

    # Initialise all params to a default value    
    $ContainerRegistry = "test"
    $Repository = "test"
    $Strictness = "Lenient"
    $TagToKeep = "v"
    $NumberToKeep = 0
}

Describe "Get-TagsToKeep" {    
    Context "When filtering is Strict" {
        BeforeAll {
            $Strictness = "Strict"
        }

        It "Keeping <NumberToKeep> filters TestTags to <Expected> tags" -TestCases @( 
            @{ NumberToKeep = 4; Expected = 3 }    
            @{ NumberToKeep = 3; Expected = 3 }
            @{ NumberToKeep = 2; Expected = 2 }
            @{ NumberToKeep = 1; Expected = 1 }
            @{ NumberToKeep = 0; Expected = 0 }
            ) {
                $Tags = Get-Tags
                $Filter = "v"
                $result = Get-TagsToKeep -TagsList $Tags -TagFilter $Filter -NumberToKeep $_.NumberToKeep
                $result.Count | Should -Be $Expected
        }
    }

    Context "When filtering is Lenient" {
        BeforeAll {
            $Strictness = "Lenient"
        }

        It "Keeping <NumberToKeep> filters TestTags to <expected> tags" -TestCases @(
            @{ NumberToKeep = 4; Expected = 11 }
            @{ NumberToKeep = 3; Expected = 11 }
            @{ NumberToKeep = 2; Expected = 7 }
            @{ NumberToKeep = 1; Expected = 2 }
            @{ NumberToKeep = 0; Expected = 0 }
            ) {
                $Tags = Get-Tags
                $Filter = "v"
                $result = Get-TagsToKeep -TagsList $Tags -TagFilter $Filter -NumberToKeep $_.NumberToKeep
                $result.Count | Should -Be $_.Expected
        }
    }
}

Describe "Delete-Images" {
    Context "When different NumberToBeKept" {
        It "<NumberImagesToKeep> to keep gives <ExpectedKept> kept, <ExpectedDeleted> deleted, and 0 failed." -TestCases @(
            @{ NumberImagesToKeep = 3; ExpectedKept = 11; ExpectedDeleted = 0 }
            @{ NumberImagesToKeep = 2; ExpectedKept = 7; ExpectedDeleted = 4 }
            @{ NumberImagesToKeep = 1; ExpectedKept = 2; ExpectedDeleted = 9 }
            @{ NumberImagesToKeep = 0; ExpectedKept = 0; ExpectedDeleted = 11 }
        ) {
            $NumberImagesToKeep = $_.NumberImagesToKeep
            $result = Remove-Images
            $result | Should -Be "Total Images: 11, Images Kept: $($_.ExpectedKept), Images Deleted: $($_.ExpectedDeleted), Image Deletion Fails: 0"
        }
    }

    Context "When there is a deletion failure" {
        It "Shows in the result text" {
            # Set up an image to fail deletion
            Mock Delete-Image -ParameterFilter { $Image -eq "test:Build-124" } -MockWith { return $false }
            $NumberImagesToKeep = 0
            $result = Remove-Images
            $result | Should -Be "Total Images: 11, Images Kept: 0, Images Deleted: 10, Image Deletion Fails: 1"

        }
    }
}


AfterAll {

}