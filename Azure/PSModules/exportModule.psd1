@{
	# Script module or binary module file associated with this manifest
	RootModule = 'exportModule.psm1'
	
	# Version number of this module.
	ModuleVersion = '0.0.0.1'
	
	# ID used to uniquely identify this module
	GUID = ''
	
	# Author of this module
	Author = 'Jelle Hoekstra'
	
	# Company or vendor of this module
	CompanyName = 'CloudTechWorks'
	
	# Copyright statement for this module
	Copyright = '(c) 2025. All rights reserved. MIT License'
	
	# Description of the functionality provided by this module
	Description = 'This module is used for exporting from "GUI" configuration to Bicep or Terraform.'
	
	# Supported PSEditions
	CompatiblePSEditions = @('Core', 'Desktop')
	
	# Minimum version of the Windows PowerShell engine required by this module
	PowerShellVersion = '7.1'
	
	# Minimum version of the .NET Framework required by this module
	DotNetFrameworkVersion = '4.5.2'
	
	# Processor architecture (None, X86, Amd64, IA64) required by this module
	ProcessorArchitecture = 'None'
	
	# Modules that must be imported into the global environment prior to importing
	# this module
	RequiredModules = @("Az.Accounts", "Az.Resources")
	
	# Assemblies that must be loaded prior to importing this module
	RequiredAssemblies = @()
	
	# Script files (.ps1) that are run in the caller's environment prior to
	# importing this module
	ScriptsToProcess = @()
	
	# Type files (.ps1xml) to be loaded when importing this module
	TypesToProcess = @()
	
	# Format files (.ps1xml) to be loaded when importing this module
	FormatsToProcess = @()
	
	# Modules to import as nested modules of the module specified in
	# ModuleToProcess
	NestedModules = @()
	
	# Functions to export from this module
	FunctionsToExport = '*' #For performance, list functions explicitly
	
	# Cmdlets to export from this module
	CmdletsToExport = '*' 
	
	# Variables to export from this module
	VariablesToExport = '*'
	
	# Aliases to export from this module
	AliasesToExport = '*' #For performance, list alias explicitly
	
	# List of all modules packaged with this module
	ModuleList = @("exportModule.psm1")
	
	# List of all files packaged with this module
	FileList = @()
	
	# Private data to pass to the module specified in ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
	PrivateData = @{
		
		#Support for PowerShellGet galleries.
		PSData = @{
			
			# Tags applied to this module. These help with module discovery in online galleries.
			# Tags = @()
			
			# A URL to the license for this module.
			# LicenseUri = ''
			
			# A URL to the main website for this project.
			# ProjectUri = ''
			
			# A URL to an icon representing this module.
			# IconUri = ''
			
			# ReleaseNotes of this module
			# ReleaseNotes = ''
			
		} # End of PSData hashtable
		
	} # End of PrivateData hashtable
}









