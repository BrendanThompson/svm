$userSvmPath = $env:USERPROFILE + "\.svm"

#
# helper functions
#
function Write-TitleMessage
{
  param (
    [string] $message
  )
  Write-Host  $("{0}" -f "`n $message `n") -BackgroundColor DarkGray -ForegroundColor Black
}
function Write-InfoMessage
{
  param (
    [string] $message
  )
  Write-Host $("{0}" -f " $message ")
}

function Write-ErrorMessage
{
  param (
    [string] $message
  )
  Write-Host $("{0}" -f " $message ") -BackgroundColor DarkRed -ForegroundColor White
}

function New-SvmInstallLocation
{
  param (
    [string] $installPath
  )

  if (Test-Path $installPath)
  {
    Write-ErrorMessage "An existing svm installation exists at '$installPath'. Please remove this manually before re-installing."
    break
  }

  Write-InfoMessage "Creating svm install location at '$installPath'."
  New-Item $installPath -type Directory | Out-Null
}

function Download-SvmPackage
{
  param (
    [string] $url,
    [string] $downloadPath
  )

  Write-InfoMessage "Downloading svm install package from '$url'."

  New-Item $([System.IO.Path]::GetDirectoryName($downloadPath)) -type Directory | Out-Null
  $wc = New-Object System.Net.WebClient
  $wc.DownloadFile($url, $downloadPath)
}

function Install-SvmPackage
{
  param (
    [string] $downloadPath,
    [string] $installPath
  )

  Write-InfoMessage "Installing svm to '$installPath'."

  $unzipFolder = [System.IO.Path]::ChangeExtension($downloadPath, $null).TrimEnd('.')
  New-Item $unzipFolder -type Directory | Out-Null

  # Use the shell to uncompress the zip file
  $shellApp = New-Object -com shell.application
  $zipFile = $shellApp.namespace($downloadPath)
  $destination = $shellApp.namespace($unzipFolder)
  $destination.CopyHere($zipFile.items(), 0x14) #0x4 = don't show UI, 0x10 = overwrite files

  # Only copy Windows specific contents into the install folder
  $zipFolderToExtract = [System.IO.Path]::Combine($unzipFolder, 'scriptcs-svm-0.2.0', 'src', 'bin')
  Remove-Item -Path $([System.IO.Path]::Combine($zipFolderToExtract, 'svm'))
  Copy-Item -Path $zipFolderToExtract -Recurse -Destination $installPath
  $zipFolderToExtract = [System.IO.Path]::Combine($unzipFolder, 'scriptcs-svm-0.2.0', 'src', 'shims')
  Remove-Item -Path $([System.IO.Path]::Combine($zipFolderToExtract, 'scriptcs'))
  Copy-Item -Path $zipFolderToExtract -Recurse -Destination $installPath

  # TODO - remove temp download folder
}

function Configure-Environment
{
  param (
    [string] $installPath
  )

  Write-InfoMessage "Configuring path environment variables for svm."

  $envPath = [Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::User)

  $foldersToPrependToPath = @()
  $foldersToPrependToPath += [System.IO.Path]::Combine($installPath, 'bin')
  $foldersToPrependToPath += [System.IO.Path]::Combine($installPath, 'shims')

  $newPath = ($foldersToPrependToPath)
  foreach($path in $envPath.Split(';'))
  {
    if (!$foldersToPrependToPath.Contains($path)) { $newPath += $path }
  }
  $path = [String]::Join(';', $newPath)

  # set process path
  $env:Path = $path

  # set user path
  [Environment]::SetEnvironmentVariable("Path", $path, [System.EnvironmentVariableTarget]::User)
}

#
# installer
#
Write-TitleMessage "scriptcs version manager - installer"

$installPath  = $userSvmPath
$url          = "https://github.com/paulbouwer/scriptcs-svm/archive/v0.2.0.zip"
$downloadPath = [System.IO.Path]::Combine($env:TEMP, [Guid]::NewGuid(), 'svm-install.zip')

New-SvmInstallLocation $installPath
Download-SvmPackage -url $url -downloadPath $downloadPath
Install-SvmPackage -downloadPath $downloadPath -installPath $installPath
Configure-Environment $installPath

Write-InfoMessage "Successfully installed!"
Write-InfoMessage "`nStart a new console and run 'svm help' to get started."
