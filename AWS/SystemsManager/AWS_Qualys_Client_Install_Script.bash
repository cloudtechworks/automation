#!/bin/bash

# This script is intented to be used in an SSM document for installing the
# Qualys agent on Linux instances.
# The script will check if the Qualys agent is already installed and if not, it will download the agent from an S3 bucket.
# The script will also check if the unzip utility is available and install it if necessary.
# Be aware that you will still need to configure the values in the systemsmanager document upon uploading it to AWS.

INSTALLERVERSION="6.0.0-1" # Replace this with the version of the Qualys agent you want to install
CUSTOMERID="00000000-0000-0000-0000-000000000000" # Replace this with your customer ID
ACTIVATIONID="00000000-0000-0000-0000-000000000000" # Replace this with your activation ID

QUALYSBASENAME="qualys-cloud-agent-$INSTALLERVERSION.x86_64" # No need to change this as the extension will automatically be selected. Just make sure the naming matches.
TMPDIR="/tmp"

INSTALLBUCKET="my-qualys-bucket" # Replace this with the name of your S3 bucket
INSTALLPATH="qualys/$QUALYSBASENAME" # Replace this with the path to the Qualys agent installer in your S3 bucket

# Check if the script will work on this distribution
if hash yum 2>/dev/null; then
  EXT=rpm
elif hash apt-get 2>/dev/null; then
  EXT=deb
else
  echo "ERROR: This script only works with YUM or APT based distributions"
  exit 1
fi

# Check if the Qualys agent is already installed
if [ "$EXT" = "deb" ]; then
  CURRENTVERSION="$(dpkg-query -W -f='${Version}' qualys-cloud-agent 2>/dev/null)"
  if [ "$CURRENTVERSION" = "$INSTALLERVERSION" ]; then
	  echo "Qualys Agent version $INSTALLERVERSION already installed"
	  exit 0
  fi
else
  CURRENTVERSION="$(rpm -q qualys-cloud-agent --queryformat '%{PROVIDEVERSION}')"
  if [ "$CURRENTVERSION" = "$INSTALLERVERSION" ]; then
	  echo "Qualys Agent version $INSTALLERVERSION already installed"
	  exit 0
  fi
fi

PKG="$TMPDIR/$QUALYSBASENAME.$EXT"

# Check if unzip is available
UNZIPINSTALLED="false"
if ! hash unzip 2>/dev/null ; then
  # unzip not available: attempt to install
  echo "Installing unzip"
  if [ "$EXT" = "deb" ]; then
	apt-get update
	apt-get -y install unzip
  else
	yum -y install unzip
  fi
  if [ $? != 0 ]; then
	echo "ERROR: unzip is not available on this distribution"
	exit 1
  fi
  UNZIPINSTALLED="true"
fi

# Not all distributions have awscli installed or available in the repositories.
# Therefore, we download the awscli v2 installer to perform our S3 download.
# There is no need to run the install script. The AWS CLI can be used directly
# from the installation directory. Afterwards we remove the files.
# This will work on all distributions. No configurations will be changed.
echo "Downloading AWSCLI zip file"
curl --silent --show-error "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip -d $TMPDIR

# Download the Qualys package
$TMPDIR/aws/dist/aws s3 cp s3://$INSTALLBUCKET/$INSTALLPATH.$EXT $TMPDIR/

# Cleanup the awscli files
rm -f awscliv2.zip
rm -rf $TMPDIR/aws
# Uninstall unzip if it was installed by this script
if [ $UNZIPINSTALLED == "true" ]; then
  echo "Removing unzip from this computer"
  if [ "$EXT" = "deb" ]; then
	apt-get -y remove unzip
  else
	yum -y remove unzip
  fi
  if [ $? != 0 ]; then
	echo "WARNING: unzip could not be uninstalled"
	exit 1
  fi
fi

if [ ! -f $PKG ]; then
  echo "ERROR: Qualys agent installer could not be downloaded from S3."
  exit 1
fi
if [ -d "/usr/local/qualys/cloud-agent/" ]; then
  # Install the package
  echo "Updating Qualys Agent to version $INSTALLERVERSION"
  if [ "$EXT" = "deb" ]; then
	apt-get -y install $PKG
  else
	yum -y install $PKG
  fi
  if [ $? != 0 ]; then
	echo "ERROR: Installation of package $PKG failed."
	exit 1
  fi
  echo "Restarting the agent"
  sudo /usr/local/qualys/cloud-agent/bin/qagent_restart.sh
  # Remove the package file
  rm -f $PKG
  exit 0
else
  # Install the package
  echo "installing Qualys Agent version $INSTALLERVERSION"
  if [ "$EXT" = "deb" ]; then
	apt-get -y install $PKG
  else
	yum -y install $PKG
  fi
  if [ $? != 0 ]; then
	echo "ERROR: Installation of package $PKG failed."
	exit 1
  fi
  # Remove the package file
  rm -f $PKG

  # Configure the cloud agent
  echo "Configuring Qualys Agent"
  /usr/local/qualys/cloud-agent/bin/qualys-cloud-agent.sh ActivationId=$ACTIVATIONID CustomerId=$CUSTOMERID LogLevel=5 ProviderName=AWS
  if [ $? != 0 ]; then
	echo "ERROR: Configuration of the Qualys cloud agent failed."
	exit 1
  else
	exit 0
  fi
fi