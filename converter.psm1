class OpenPoseVideoConverter {

  [bool] $Body;
  [bool] $Face;
  [bool] $Hand;
  [int] $Tracking;
  [int] $NumberPeopleMax;
  [string] $ModeName;
  [int] $ScaleNumber;
  [double] $ScaleGap;
  [int] $HandScaleNumber;
  [double] $HandScaleGap;
  [string[]] $Include;
  [int] $NetHeight;
  [string] $HandNetResolution;
  [string] $FaceNetResolution;
  [int] $MaxTries;

  [hashtable] $IgnoreTable;
  [string] $OpenPosePath;
  [string] $DatasetPath;
  [string] $OutputPath;

  [string] hidden $ConfigurationsFilePath;
  [string] hidden $ModePath;
  [string] hidden $ProgessFileName = '.progress';
  [string] hidden $TempFolderName = '__temp';
  [string] hidden $ConfigurationsDir = './configs';
  [string] hidden $ConfigurationsFileName = 'config.json';
  [string] hidden $ProgressFilePath;
  [System.Collections.Generic.HashSet[string]] hidden $FinishedFiles;
  [string] hidden $TempFolder;

  OpenPoseVideoConverter([string] $mode) {
    $this.ReadConfig($mode);
    $this.Init();
  }

  OpenPoseVideoConverter([hashtable] $config) {
    $this.ReadConfig($config);
    $this.Init();
    $this.WriteConfig();
  }

  [void] hidden Init() {
    $this.FinishedFiles = New-Object System.Collections.Generic.HashSet[string];
    $this.IgnoreTable = @{};
    Set-Location $this.OpenPosePath;
    $this.ModePath = Join-Path -Path $this.ConfigurationsDir -ChildPath $this.ModeName
    $this.ConfigurationsFilePath = Join-Path -Path $this.ModePath -ChildPath $this.ConfigurationsFileName

    if (!(Test-Path $this.ModePath -PathType Container)) {
      New-Item -Path $this.ModePath -ItemType Directory;
    }

    $this.ProgressFilePath = Join-Path -Path $this.ModePath -ChildPath $this.ProgessFileName;
    $this.TempFolder = Join-Path -Path $this.OutputPath -ChildPath $this.TempFolderName

    if (!(Test-Path -LiteralPath $this.TempFolder -PathType Container)) {
      New-Item -Path $this.TempFolder -ItemType Directory;
    }

    if (!(Test-Path -LiteralPath $this.OutputPath -PathType Container)) {
      New-Item -Path $this.OutputPath -ItemType Directory;
    }

    $this.ReadFinishedFiles();
  }

  [void] hidden UpdateProgress([string] $FinishedFile) {
    Add-Content -Path $this.ProgressFilePath -Value $FinishedFile;
    $this.FinishedFiles.Add($FinishedFile);
  }

  [void] hidden ReadFinishedFiles() {
    if (Test-Path -LiteralPath $this.ProgressFilePath -PathType Leaf) {
      $files = Get-Content -Path $this.ProgressFilePath;
      
      foreach ($file in $files) {
        $this.FinishedFiles.Add($file);
      }
    }
    else {
      New-Item -Path $this.ProgressFilePath -ItemType File;
    }
  }

  [void] hidden ConvertVideo([string] $VideoPath, [string] $VideoOutDir) {
    if (!$this.FinishedFiles.Contains($VideoPath)) {
      $videoName = Split-Path $VideoPath -LeafBase;
      $videoDir = Join-Path -Path $VideoOutDir -ChildPath $videoName;
      
      if (!(Test-Path -LiteralPath $videoDir -PathType Container)) {
        New-Item -Path $videoDir -ItemType Directory;
      }
      
      # Muss alles gemacht werden damit die Pfadlänge von Win nicht überschritten wird
      $videoCopy = Copy-Item -LiteralPath $VideoPath -Destination (Join-Path -Path $this.TempFolder -ChildPath "$($this.ModeName).avi") -PassThru -Force
      # https://github.com/CMU-Perceptual-Computing-Lab/openpose/blob/master/doc/demo_overview.md
      $openpose_args = @(
        # Zeigt keine GUI an
        "--display", "0", "--no_gui_verbose", "--render_pose", "0",
        # Besagt das die berechneten Koordinaten nach den Maßen der Eingangsdatei skaliert werden.
        "--keypoint_scale", "0", 
        # Anzahl der Skalen die geaveraged wird.
        "--scale_number", $this.ScaleNumber,
        # Skalierungsabstand wischen den Skalen
        "--scale_gap", $this.ScaleGap,
        # (Hand) Anzahl der Skalen die geaveraged wird.
        "--hand_scale_number", $this.HandScaleNumber,
        # (Hand) Skalierungsabstand wischen den Skalen.
        "--hand_scale_range", $this.HandScaleGap,
        "--net_resolution", "-1x$($this.NetHeight)",
        "--hand_net_resolution", $this.HandNetResolution,
        "--face_net_resolution", $this.FaceNetResolution,
        "--model_pose", "BODY_25", 
        "--video", $videoCopy, "--write_json", $videoDir);
                  
      if (!$this.Body) {
        # Ist default schon auf 1.
        $openpose_args += "--body";
        $openpose_args += "0";
      }
      
      if ($this.Face) {
        $openpose_args += "--face";
      }
      
      if ($this.Hand) {
        $openpose_args += "--hand";
      }
      
      $openpose_args += "--tracking";
      $openpose_args += $this.Tracking;
      $numpeople = $this.Tracking -gt -1 ? 1 : $this.NumberPeopleMax ;
      $openpose_args += "--number_people_max";
      $openpose_args += $numpeople;
      $tries = 0;
      $success = $false;
      
      do {
        $out = & "./bin/OpenPoseDemo.exe" $openpose_args;
      
        if (!($out[$out.Length - 1].StartsWith(("OpenPose demo successfully finished.")))) {
          Write-Host "Error: Trying again ...";
          $tries++;
        }
        else {
          $success = $true;
        }
                      
      } while ($tries -lt $this.MaxTries -and !$success);
      
      if ($success) {
        $parentDir = Split-Path -Path $VideoOutDir -Leaf
        Remove-Item -LiteralPath $videoCopy
        $this.UpdateProgress($VideoPath)
        Write-Host "Converted $parentDir/$videoName"
      }
      else {
        Write-Host "OpenPose ERROR" -BackgroundColor Red -ForegroundColor Black
        Write-Host "Max Tries exceeded" -BackgroundColor Red -ForegroundColor Black
                      
        throw $VideoPath
      }
    } 
  }
  [void] hidden ConvertVideos() {    
    $videos = Get-ChildItem ($this.DatasetPath + '\*.avi') -File;
    
    foreach ($video in $videos) {
      $this.ConvertVideo($video, $this.OutputPath);
    }
  }

  [void] hidden ConvertVideos([string] $VideoFolder) {
    $category = (Get-Item -Path $VideoFolder).BaseName
    $videoOutDir = Join-Path -Path $this.OutputPath -ChildPath $category
    
    if (!(Test-Path -LiteralPath $videoOutDir -PathType Container)) {
      New-Item -Path $videoOutDir -ItemType Directory | Out-Null;
    }
    
    $videos = Get-ChildItem ($VideoFolder + '\*.avi') -File;
    
    if ($this.IgnoreTable -and $this.IgnoreTable.Contains($category)) {
      $videos = $videos | Where-Object -FilterScript { (Get-Item -Path $_).BaseName -notin $this.IgnoreTable[$category] };
    }
    
    foreach ($video in $videos) {
      $this.ConvertVideo($video, $videoOutDir);
    }

    Write-Host "Finished `"$category`".";
  }

  [void] ConvertDataset() {
    Write-Host "Converting Videos in $($this.DatasetPath)";
    Write-Host "Basename: $($this.ModeName)";

    $dirs = $this.Include ?? ((Get-ChildItem -LiteralPath $this.DatasetPath -Directory) | Where-Object -FilterScript { $_ -ne $this.TempFolderName });
    
    foreach ($dir in $dirs) {
      $this.ConvertVideos($dir);
    }

    Remove-Item -Path $this.ProgressFilePath | Out-Null;
    Remove-Item -Path $this.TempFolder -Recurse | Out-Null;

    Write-Host "Finished Conversion succesfully." -ForegroundColor Green;
  }

  [void] hidden WriteConfig() {
    if (Test-Path -Path $this.ConfigurationsFilePath) {
      # throw; // TODO
      return;
    }
    else {
      New-Item -Path $this.ConfigurationsFilePath -ItemType File;
      # Only get non-hidden Properties
      $savedProperties = @{};
      $type = $this.GetType();
      $properties = $this | Get-Member -MemberType Properties

      foreach ($property in $properties) {
        $propertyInfo = $type.GetProperty($property.Name);
        $propertyValue = $propertyInfo.GetValue($this);
        $savedProperties.Add($property.Name, $propertyValue)
      }

      $thisJson = $savedProperties | ConvertTo-Json;
      $thisJson | Set-Content -Path $this.ConfigurationsFilePath;
    }
  }

  [void] hidden ReadConfig([string] $mode) {
    if (Test-Path -LiteralPath $mode) {
      $content = Get-Content -LiteralPath $mode -Raw;
      [hashtable] $configTable = $content | ConvertFrom-Json -AsHashtable;
      $this.ReadConfig($configTable); 
    }
    else {
      throw "Config file does not exist.";
    }
  }

  [void] hidden ReadConfig([hashtable] $config) {
    [Type] $ownType = $this.GetType();

    foreach ($key in $config.Keys) {
      Write-Host $key
      if ($null -ne $config[$key]) {
        if ($config[$key].GetType() -eq [long]) {
          $ownType.GetProperty($key).SetValue($this, [int] $config[$key]);
        }
        else {
          $ownType.GetProperty($key).SetValue($this, $config[$key]);
        }
      }
    }
  }

  [OpenPoseVideoConverter] static continueFrom([string] $mode) {
    return [OpenPoseVideoConverter]::new($mode);
  }
}