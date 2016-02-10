param (
    [Parameter(Mandatory=$True)]
    [string]$ProjectDir
)

Write-Host "Entered Inner Script";

$nugetPackagesPath = "$($env:USERPROFILE)/.dnx/packages";
$xprojFile = get-childitem "$ProjectDir" -Filter "*.xproj" -recurse; # | % { $_.FullName }

$projectJsonPath = "$ProjectDir/project.json";
$projectJsonContent = (Get-Content $projectJsonPath) -join "" | ConvertFrom-Json;

$fodyVersion = $projectJsonContent.dependencies.Fody;
$fodyPackagePath = "$nugetPackagesPath/Fody/$fodyVersion";

$projectName = $xprojFile.BaseName;
$projectConfiguration = "Debug";
$projectRuntime = "net451";

$projectArtifactBinPath = [System.IO.Path]::GetFullPath("$ProjectDir/../../../artifacts/bin/$projectName");
$projectArtifactBinOutPath = "$projectArtifactBinPath/$projectConfiguration";

Class FodyBuildEngine : Microsoft.Build.Framework.IBuildEngine {
  [int]$m_columnNumberOfTaskNode;
  [int]get_ColumnNumberOfTaskNode() { return $this.m_columnNumberOfTaskNode; }
  [void]set_ColumnNumberOfTaskNode([int]$val) { $this.m_columnNumberOfTaskNode = $val; }
  
  [bool]$ContinueOnError;
  [bool]get_ContinueOnError() { return $this.ContinueOnError }
  [void]set_ContinueOnError([bool]$val) { $this.ContinueOnError = $val; }
  
  [int]$LineNumberOfTaskNode;
  [int]get_LineNumberOfTaskNode() { return $this.LineNumberOfTaskNode }
  [void]set_LineNumberOfTaskNode([int]$val) { $this.LineNumberOfTaskNode = $val; }
  
  [string]$ProjectFileOfTaskNode;
  [string]get_ProjectFileOfTaskNode() { return $this.ProjectFileOfTaskNode}
  [void]set_ProjectFileOfTaskNode([string]$val) { $this.ProjectFileOfTaskNode = $val; }

  [bool]BuildProjectFile([string]$projectFileName, [string[]]$targetNames, [System.Collections.IDictionary] $globalProperties, [System.Collections.IDictionary] $targetOutputs) { 
    Write-Host "Unexpected BuildProjectFile!"; 
    throw [System.NotSupportedException]; 
  }
  [void]LogCustomEvent([Microsoft.Build.Framework.CustomBuildEventArgs]$e) { $this.DisplayMessage($e, "Custom"); }
  [void]LogErrorEvent([Microsoft.Build.Framework.BuildErrorEventArgs]$e) { $this.DisplayMessage($e, "Error"); }
  [void]LogMessageEvent([Microsoft.Build.Framework.BuildMessageEventArgs]$e) { $this.DisplayMessage($e, "Message"); }
  [void]LogWarningEvent([Microsoft.Build.Framework.BuildWarningEventArgs]$e) { $this.DisplayMessage($e, "Warning"); }
  [void]DisplayMessage([Microsoft.Build.Framework.BuildEventArgs]$e, $category) {
    Write-Host "[$category] $($e.Message)";
  }
}

$buildEngine = [FodyBuildEngine]::new();

Add-Type -Path "$fodyPackagePath/Fody.dll";
$weaver = New-Object -TypeName Fody.WeavingTask;
$weaver.BuildEngine = $buildEngine;
$weaver.AssemblyPath = "$projectArtifactBinOutPath/$projectRuntime/$projectName.dll";
$weaver.IntermediateDir = $null; # Doesn't seem to be used by Fody source code?
$weaver.KeyFilePath = $null; # Not supported by us.
$weaver.SignAssembly = $false; # Not supported by us.
$weaver.ProjectDirectory = $ProjectDir;
$weaver.References = "C:\\Windows\\Microsoft.NET\\Framework64\\v4.0.30319\\mscorlib.dll"; # Not sure how it's used.
$weaver.ReferenceCopyLocalPaths = [System.Array]::CreateInstance([Microsoft.Build.Framework.ITaskItem], 0); # Not sure how it's used.
$weaver.SolutionDir = $ProjectDir; # Can we find the sln by traversing tree? Used as one of many ways to find fodyweavers.xml.
$weaver.DefineConstants = "";
$weaver.NuGetPackageRoot = $nugetPackagesPath;
Write-Host ($weaver | Out-String);
$result = $weaver.Execute();
Write-Host "Result: $result";

# ghetto - return success/failure via string.
# don't put anything after this.
if ($result) {
  Write-Output(0);
} else { 
  Write-Output(1);
}