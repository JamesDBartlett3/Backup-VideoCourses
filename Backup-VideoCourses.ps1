<#
Author: @JamesDBartlett3@techhub.social
TODO:
  - Get actual course titles for display in Out-ConsoleGridView, rather than their shortened versions as is current behavior
  - Add support for courses
  - Add support for topics
  - Use logging to detect if a download was interrupted and resume/restart
#>

Function Backup-VideoCourses {
  
  Param(
    [parameter(Mandatory = $true)][string]$DomainName,
    [parameter(Mandatory = $true)][string]$AppName,
    [parameter(Mandatory = $false)][string]$FileType = 'mp4'
  )
  
  #requires -Module Microsoft.PowerShell.ConsoleGuiTools
  
  $courseURLs = ((Invoke-WebRequest -Method GET -Uri "https://$DomainName/library/application/$AppName").Links | 
    Where-Object -Property class -like "*Coursetiles__link*").href |
    Split-Path -Leaf | Out-ConsoleGridView
  
  $courseContent = $courseURLs |
    ForEach-Object {
      $courseUrl = "https://$DomainName/ajax/videos/$_"
      (Invoke-RestMethod -Method GET -Uri $courseUrl -ContentType "application/json;charset=utf-8").data.videos | 
      Select-Object -Property tutorial, ned_programmanifest, @{Name = 'video_medium'; Expression = {
        $_.thumbnail_medium.mediaURL.Substring(0, ($_.thumbnail_medium.mediaURL |
          Select-String -Pattern '/' -AllMatches |
          Select-Object -First 4).Matches[3].Index + 1) + "hls.m3u8"}}
    }
  
  $tutorial = $courseContent | Select-Object -ExpandProperty tutorial
  $ned_programmanifest = $courseContent | Select-Object -ExpandProperty ned_programmanifest
  $video_medium = $courseContent | Select-Object -Property video_medium
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
    $videoURL = $video_medium[$i].video_medium
    
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
      
    } 
    else {
      Write-Host "$completedVideoFileName already exists. Skipping...".Replace("$targetDirectory\", '')
    }
  
  }
  
}
