# Load additional assemblies needed by script_inner, then exec it.
Add-Type -AssemblyName Microsoft.Build.Framework;
Invoke-Expression "$PSScriptRoot/script_inner.ps1";