Import-Module AWSPowerShell
# The version string needs to be in the format "x.x.x.x"
$installerVersion = "6.0.0.0" # Replace this with the version of the Qualys Cloud Agent you want to install
$customerId="00000000-0000-0000-0000-000000000000" # Replace this with your customer ID
$activationId="00000000-0000-0000-0000-000000000000" # Replace this with your activation ID

$installerBasename = "QualysCloudAgent"
$installerFilename = "$installerBasename-$installerVersion.exe"
$installerTargetDir = "C:\Windows\Temp"
$installer = "$installerTargetDir\$installerFilename"
$QualysDisplayName = "Qualys Cloud Security Agent"
$SoftwareSource = "SSM - Qualys Installer Script"

$installerBucketName = "my-qualys-bucket" # Replace this with your bucket
$installerKeyPath = "/mypath/$installerFilename" # Replace this with the path to the installer in your bucket

### FUNCTIONS ###

# Function to initialize the Eventlog
# This makes sure that the EventLog with Source $SourceName exists
function Initialize-Eventlog($SourceName)
{
  # Check if Eventlog source exists and create if not
  if (!([System.Diagnostics.EventLog]::SourceExists($SourceName)))
  {
    New-EventLog -LogName Application -Source $SourceName
  }
}

# Function to retrieve information about the currently installed QualysCloudAgent version
# The function will return the version number of the installed software, or "0.0.0.0" if not installed.
function Get-Current-Version($installedDisplayName)
{
  # Inspired by https://blogs.technet.microsoft.com/heyscriptingguy/2011/11/13/use-powershell-to-quickly-find-installed-software/

  $UninstallKey1 = "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall"
  $UninstallKey2 = "SOFTWARE\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall"

  $currentInstalledVersion = Get-Version -UninstKey $uninstallKey1 -DisplayName $installedDisplayName
  if ($currentInstalledVersion -eq "0.0.0.0") {
    $currentInstalledVersion = Get-Version -UninstKey $uninstallKey2 -DisplayName $installedDisplayName
  }

  return $currentInstalledVersion
}


function Get-Version($UninstKey, $DisplayName)
{
  # The default version for "uninstalled" is set to 0.0.0.0 to accomodate the [version] type cast
  $result = "0.0.0.0"

  #Create an instance of the Registry Object and open the HKLM base key
  $reg = [microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Default)
  #Drill down into the Uninstall key using the OpenSubKey Method
  $regkey = $reg.OpenSubKey($UninstKey)
  #Retrieve an array of string that contain all the subkey names
  $subkeys = $regkey.GetSubKeyNames()

  #Open each Subkey and use GetValue Method to return the required values for each
  foreach ($key in $subkeys)
  {
    $thiskey = $UninstKey + "\\" + $key
    $thisSubKey = $reg.OpenSubKey($thiskey)
    if ($thisSubKey.GetValue("DisplayName") -like $DisplayName)
    {
      $result = $thisSubKey.GetValue("DisplayVersion")
    }
  }

  return $result
}

function installQualysAgent{
    Try
    {
      if($patch){
        #This is an upgrade
        Write-Host "Upgrading $QualysDisplayName version $currentVersion to $installerVersion"
        Write-EventLog -EntryType Information -EventId 10021 -LogName Application -Message "Preparing to download and install $QualysDisplayName version $installerVersion" -Source $SoftwareSource
        Read-S3Object -BucketName $installerBucketName -Key $installerKeyPath -File "$installer" > $null
        Write-Host "Upgrading Qualys Agent version $installerVersion"
        cmd /c "$installer PatchInstall=TRUE"
      }
      else{
        # This is a new installation
        Write-Host "Downloading $QualysDisplayName version $installerVersion"
        Write-EventLog -EntryType Information -EventId 10021 -LogName Application -Message "Preparing to download and install $QualysDisplayName version $installerVersion" -Source $SoftwareSource
        Read-S3Object -BucketName $installerBucketName -Key $installerKeyPath -File "$installer" > $null
        Write-Host "Installing Qualys Agent version $installerVersion"
        cmd /c "$installer CustomerId=$customerId ActivationId=$activationId"
      }
    }
    Catch {
      exit 1
    }
}

### BEGIN ###

# Make sure the Eventlog is ready to receive our events
Initialize-Eventlog($SoftwareSource)

# Obtain the currently installed version (will be empty string if not installed)
$currentVersion = Get-Current-Version($QualysDisplayName)
Write-Host "Current version: $currentVersion"

#Clearing out patch
$patch = ""

### INSTALL SOFTWARE ###
# Check if the program is already installed and the same version
# If the program is already installed we don't need to clutter the EventLog
# with useless messages.

if ([version]$currentVersion -ne [version]$installerVersion) {
  if ([version]$currentVersion -ge [version]$installerVersion) {
    Write-EventLog -EntryType Error -EventId 10030 -LogName Application -Message "An error occured during installation of $QualysDisplayName version $installerVersion.`nThe currently installed version $currentVersion is greater than the version that is to be installed." -Source $SoftwareSource
	Write-Host "The currently installed version $currentVersion is greater than or equal to the version that is to be installed $installerVersion."
  }
  elseif([version]$currentVersion -lt [version]$installerVersion -and $currentVersion.length -gt 3){
    # If the currentVersion less than the installerVersion, a clean install needs to be performed. 
	# For the old version the commands are a bit different..
	Write-Host "Now attempting an upgrade"
	$patch = "Yes"
	installQualysAgent
  }
  else {
	Write-Host "A new installation will commence"
    # Either the application is not yet installed.
    # Download and install the application
    installQualysAgent
  }
}