Using module ".\converter.psm1"

[CmdletBinding()]
param (
  [Parameter(Mandatory = $false)]
  [ValidateScript( { [System.IO.Path]::IsPathRooted($_) })]
  [string]
  $DatasetPath,
  [Parameter(Mandatory = $false)]
  [ValidateScript( { [System.IO.Path]::IsPathRooted($_) })]
  [string]
  $OutputPath,
  [Parameter(Mandatory = $false)]
  [ValidateScript( { [System.IO.Path]::IsPathRooted($_) })] # muss absolut sein, damit auch später noch darauf zugegriffen werden kann
  [string]
  $OpenPosePath,
  [Parameter(Mandatory = $false)]
  [int]
  $Tracking = -1,
  [Parameter(
    Mandatory = $false, 
    HelpMessage = "So ist dann der Basisname der Keypointsdateien"
  )]
  [string]
  $ModeName = "video",
  [Parameter(Mandatory = $false)]
  [int]
  $ScaleNumber = 1,
  [Parameter(Mandatory = $false)]
  [int]
  $HandScaleNumber = 1,
  [Parameter(Mandatory = $false)]
  [double]
  $ScaleGap = .25d,
  [Parameter(Mandatory = $false)]
  [double]
  $HandScaleGap = .4d,
  [Parameter(Mandatory = $false)]
  [string[]]
  $Include,
  [Parameter(Mandatory = $false)]
  [int]
  $NetHeight = 368,
  [Parameter(Mandatory = $false)]
  [string]
  $HandNetResolution = "368x368",
  [string]
  $FaceNetResolution = "368x368",
  [Parameter(Mandatory = $false)]
  [switch]
  $Hand,
  [Parameter(Mandatory = $false)]
  [switch]
  $Face,
  [Parameter(Mandatory = $false)]
  [switch]
  $Body,
  [Parameter(Mandatory = $false)]
  [int]
  $MaxTries = 2,
  [Parameter(Mandatory = $false, HelpMessage="Path to config file.")]
  [string]
  $Continue,
  [Parameter(Mandatory = $false)]
  [switch]
  $ShutDownAfter
)
process {
  $dataFolderPresent = ![string]::IsNullOrEmpty($DatasetPath)
  $targetFolderPresent = ![string]::IsNullOrEmpty($OutputPath)
  $continueModePresent = ![string]::IsNullOrEmpty($Continue)

  if ($dataFolderPresent -and $targetFolderPresent -and !$continueModePresent) {
    [hashtable] $converterArgs = @{};
    $exludedParams = @("Continue", "ShutDownAfter");

    foreach ($paramName in $MyInvocation.MyCommand.Parameters.Values) {
      if ($paramName.Name -notin $exludedParams) {
        try {
          $param = Get-Variable $paramName.Name -ErrorAction Stop
          $value = $param.Value.GetType() -eq [System.Management.Automation.SwitchParameter] ? $param.Value.IsPresent : $param.Value;
          $converterArgs.Add($paramName.Name, $value);
        }
        catch { }
      }
    } 

    # [hashtable] $converterArgs = @{
    #   "Body" = $Body.IsPresent;
    #   "Face" = $Face.IsPresent;
    #   "Hands" = $Body.IsPresent;
    #   "Tracking" = $Tracking;
    #   "NumberPeopleMax" = $NumberPeopleMax;
    #   "ModeName" = $ModeName;
    #   "ScaleNumber" = $ScaleNumber;
    #   "ScaleGap" = $ScaleGap;
    #   "HandScaleNumber" = $HandScaleNumber;
    #   "HandScaleGap" = $HandScaleGap;
    #   "Include" = $Include;
    #   "NetHeight" = $NetHeight;
    #   "HandNetResolution" = $HandNetResolution;
    #   "FaceNetResolution" = $FaceNetResolution;
    #   "MaxTries" = $MaxTries;
    #   "OpenPosePath" = $OpenPosePath;
    #   "DatasetPath" = $DatasetPath;
    #   "OutputPath" = $OutputPath;
    # };
    
    [OpenPoseVideoConverter] $converter = [OpenPoseVideoConverter]::new($converterArgs);
    $converter.ConvertDataset();

    if ($ShutDownAfter.IsPresent) {
      Stop-Computer -ComputerName 'localhost'
    }
  }

  if (!$dataFolderPresent -and !$targetFolderPresent -and $continueModePresent) {
    [OpenPoseVideoConverter] $converter = [OpenPoseVideoConverter]::continueFrom($Continue)
    $converter.ConvertDataset();

    if ($ShutDownAfter.IsPresent) {
      Stop-Computer -ComputerName 'localhost'
    }
  }

  throw "Either set DataFolder and TargetFolder or ContinueMode";
}