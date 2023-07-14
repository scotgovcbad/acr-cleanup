# Arranging which happens before all the tests are run
BeforeAll {
    # Load the script, making sure to set the testing flag (otherwise the script will try to delete images and fail)
    . $PSScriptRoot/AcrCleanupScript.ps1 -Testing $true `
        -ContainerRegistry "test" `
        -Repository "test" `
        -Strictness "Lenient" `
        -TagToKeep "v" `
        -NumberImagesToKeep 3

    # The array of tags we'll return from Get-Tags
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
    Mock Remove-SingleImage { return $true }
}

Describe "Get-TagsToKeep" {    
    Context "When Strictness is Strict" {
        It "Keeping <NumberToKeep> filters TestTags to <Expected> items" -TestCases @( 
            @{ NumberToKeep = 4; Expected = 3; Strictness = "Strict" }    
            @{ NumberToKeep = 3; Expected = 3; Strictness = "Strict" }
            @{ NumberToKeep = 2; Expected = 2; Strictness = "Strict" }
            @{ NumberToKeep = 1; Expected = 1; Strictness = "Strict" }
            @{ NumberToKeep = 0; Expected = 0; Strictness = "Strict" }
            ) {
                # Arrange
                $Tags = Get-Tags
                $Filter = "v"

                # Act
                $result = Get-TagsToKeep -TagsList $Tags -TagFilter $Filter -NumberToKeep $_.NumberToKeep

                # Assert
                $result.Count | Should -Be $Expected
        }
    }

    Context "When Strictness is Lenient" {
        It "Keeping <NumberToKeep> filters TestTags to <expected> items" -TestCases @(
            @{ NumberToKeep = 4; Expected = 11 }
            @{ NumberToKeep = 3; Expected = 11 }
            @{ NumberToKeep = 2; Expected = 7 }
            @{ NumberToKeep = 1; Expected = 2 }
            @{ NumberToKeep = 0; Expected = 0 }
            ) {
                # Arrange
                $Tags = Get-Tags
                $Filter = "v"

                # Act
                $result = Get-TagsToKeep -TagsList $Tags -TagFilter $Filter -NumberToKeep $_.NumberToKeep

                # Assert
                $result.Count | Should -Be $_.Expected
        }
    }    

    It "There are no tags which match the filter, function returns empty array" {
        # Arrange
        $Tags = Get-Tags
        $Filter = "q"

        # Act
        $result = Get-TagsToKeep -TagsList $Tags -TagFilter $Filter -NumberToKeep $_.NumberToKeep

        # Assert
        $result.Count | Should -Be 0
    }
}

Describe "Remove-AllImages" {
    Context "When strictness is Lenient" {
        It "<NumberImagesToKeep> to keep gives <ExpectedKept> kept, <ExpectedDeleted> deleted, and 0 failed."   -TestCases @(
            @{ NumberImagesToKeep = 3; ExpectedKept = 11; ExpectedDeleted = 0 }
            @{ NumberImagesToKeep = 2; ExpectedKept = 7; ExpectedDeleted = 4 }
            @{ NumberImagesToKeep = 1; ExpectedKept = 2; ExpectedDeleted = 9 }
            @{ NumberImagesToKeep = 0; ExpectedKept = 0; ExpectedDeleted = 11 }
        ){
            # Act
            $result = Remove-AllImages

            # Assert
            $result | Should -Be "Total Images: 11, Images Kept: $($_.ExpectedKept), Images Deleted: $($_.ExpectedDeleted), Image Deletion Fails: 0"
        }
    }

    Context "When strictness is Strict" {
        It "<NumberImagesToKeep> to keep gives <ExpectedKept> kept, <ExpectedDeleted> deleted, and 0 failed." -TestCases @(
            @{ NumberImagesToKeep = 3; ExpectedKept = 3; ExpectedDeleted = 8; Strictness = "Strict" }
            @{ NumberImagesToKeep = 2; ExpectedKept = 2; ExpectedDeleted = 9; Strictness = "Strict" }
            @{ NumberImagesToKeep = 1; ExpectedKept = 1; ExpectedDeleted = 10; Strictness = "Strict" }
            @{ NumberImagesToKeep = 0; ExpectedKept = 0; ExpectedDeleted = 11; Strictness = "Strict" }
        ){
            # Act
            $result = Remove-AllImages

            # Assert
            $result | Should -Be "Total Images: 11, Images Kept: $($_.ExpectedKept), Images Deleted: $($_.ExpectedDeleted), Image Deletion Fails: 0"
        }
    }

    Context "When there is a deletion failure" {
        It "Shows in the result text" -TestCases @(
            @{ NumberImagesToKeep = 0; BuildToFail = "test:Build-124"; ExpectedFails = 1 }
        ) {
            # Arrange
            # Set up an image to fail deletion
            Mock Remove-SingleImage -ParameterFilter { $Image -eq $BuildToFail } -MockWith { return $false }

            # Act
            $result = Remove-AllImages

            # Assert
            $result | Should -Be "Total Images: 11, Images Kept: 0, Images Deleted: 10, Image Deletion Fails: $($ExpectedFails)"
        }
    }

    It "There are no tags which match the filter, everything is deleted" -TestCases @(
        @{ TagToKeep = "q" }
    ) {
        # Act
        $result = Remove-AllImages

        # Assert
        $result | Should -Be "Total Images: 11, Images Kept: 0, Images Deleted: 11, Image Deletion Fails: 0"
    }
}