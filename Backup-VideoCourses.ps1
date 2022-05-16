<# TODO: 
- add selection menu with Out-ConsoleGridView
- refactor loop logic
    - create a new PSCustomObject variable to contain all course data
    - on each loop iteration, add a new record to the object with the current values
    - pass the completed PSCustomObject to a ForEach-Object loop
    - add optional parallelism parameter; default value = 1
- add optional "CourseName" parameter; default value = "All"
- add parameter to choose downloader
    - PS Module wrappers for ffmpeg, yt-dlp, etc?
    - add error handling and logging
- add parameter for verbose console output; default value = false
- add ability to resume partial downloads
- clean up variables:
    - remove non-numeric characters from $courseNumber, $sectionNumber, $lessonNumber variables
    - remove non-alphabetic and non-punctuation characters from $courseName, $sectionName, $lessonName variables
    - trim and eliminate redundant spaces from all variables
- refactor file path handling
    - split PascalCase course names into separate words
    - make functions for file path parsing
    - eliminate duplicate code
    - eliminate dummy delimiters
- add parameter for NestedFolderDepth; integer value from 0 to 3; default value = 3
    - case 3:
        - create a folder for each AppName, CourseName, and SectionName
        - name files "LessonNumber - LessonName"
    - case 2:
        - create a folder for each AppName and CourseName
        - name files "SectionNumber - SectionName - LessonNumber - LessonName"
    - case 1:
        - create a folder for each AppName
        - name files "CourseNumber - CourseName - SectionNumber - SectionName - LessonNumber - LessonName"
    - case 0:
        - name files "AppName - CourseNumber - CourseName - SectionNumber - SectionName - LessonNumber - LessonName"
- add metadata to video files
- add subtitles to video files
- add "--help" parameter
#>

Function Backup-VideoCourses {

    Param(
        [parameter(Mandatory = $true)][string]$DomainName,
        [parameter(Mandatory = $true)][string]$AppName,
        [parameter(Mandatory = $false)][string]$FileType = 'mp4'
    )

    <# Out-ConsoleGridView requires this module, so un-comment when that feature is finished
    #requires -Module Microsoft.PowerShell.ConsoleGuiTools
    #>

    $courseURLs = ((Invoke-WebRequest -Method GET -Uri "https://$DomainName/library/application/$AppName").Links | 
        Where-Object -Property class -like "*Coursetiles__link*").href |
        Split-Path -Leaf

    $courseContent = $courseURLs |
        ForEach-Object {
            $courseUrl = "https://$DomainName/ajax/videos/$_"
            (Invoke-RestMethod -Method GET -Uri $courseUrl -ContentType "application/json;charset=utf-8").data.videos | 
            Select-Object -Property tutorial, ned_programmanifest, video_medium
        }

    $tutorial = $courseContent | Select-Object -ExpandProperty tutorial
    $ned_programmanifest = $courseContent | Select-Object -ExpandProperty ned_programmanifest
    $video_medium = $courseContent | Select-Object -ExpandProperty video_medium
    $numberOfVideos = $courseContent.Count
    
    $targetDirectory = "$((Get-Location).Path)\$AppName"

    if(!(Test-Path $targetDirectory)) {
        New-Item -Path $targetDirectory -ItemType Directory | Out-Null
    }

    for($i = 0; $i -lt $numberOfVideos; $i++) {
        $courseNumber = $tutorial[$i].tu_num
        $courseTitle = $tutorial[$i].tu_title
        $sectionNumber = ([string]$ned_programmanifest[$i].sec_num).PadLeft(2,'0')
        $sectionTitle = $ned_programmanifest[$i].sec_title
        $lessonNumber = ([string]$ned_programmanifest[$i].serial_number).PadLeft(2,'0')
        $lessonTitle = $ned_programmanifest[$i].vid_title
        $videoURL = $video_medium[$i].mediaURL

        $filePath = "$courseNumber - $courseTitle⌿$sectionNumber - $sectionTitle⌿$lessonNumber - $lessonTitle"

        $courseFolder = Join-Path -Path $targetDirectory -ChildPath $($filePath.Split('⌿')[0].Split([IO.Path]::GetInvalidFileNameChars()) -Join '')
        $sectionFolder = Join-Path -Path $courseFolder -ChildPath $($filePath.Split('⌿')[1].Split([IO.Path]::GetInvalidFileNameChars()) -Join '')
        $videoFileName = Join-Path -Path $sectionFolder -ChildPath $($filePath.Split('⌿')[2].Split([IO.Path]::GetInvalidFileNameChars()) -Join '')
        
        $partialVideoFileName = $videoFileName + ".part.$FileType"
        $completedVideoFileName = $videoFileName + ".$FileType"

        if(!(Test-Path $courseFolder)) {
            Write-Host "Creating folder: $courseFolder...".Replace("$targetDirectory\", '')
            New-Item -ItemType Directory -Path $courseFolder | Out-Null
        }
        if(!(Test-Path $sectionFolder)) {
            Write-Host "Creating folder: $sectionFolder...".Replace("$targetDirectory\", '')
            New-Item -ItemType Directory -Path $sectionFolder | Out-Null
        }
        if(!(Test-Path $completedVideoFileName)) {
            if(Test-Path $partialVideoFileName) {
                Write-Host "Deleting partial file from previous failed or interrupted download: $partialVideoFileName".Replace("$targetDirectory\", '')
                Remove-Item -Path $partialVideoFileName -Force
            }
            Write-Host "Downloading $completedVideoFileName...".Replace("$targetDirectory\", '')
            ffmpeg -hide_banner -loglevel error -i $videoURL -c copy -format $FileType $partialVideoFileName
            # Need to find a way to check if the download was successful before renaming the file
            Move-Item -Path $partialVideoFileName -Destination $completedVideoFileName
        } else {
            Write-Host "$completedVideoFileName already exists. Skipping...".Replace("$targetDirectory\", '')
        }

    }

}
