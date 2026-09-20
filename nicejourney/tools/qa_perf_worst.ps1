param(
    [string]$GodotPath = "C:\Users\LENOVO\Desktop\GodotC#\Godot_v4.6.2-stable_mono_win64_console.exe",
    [string]$OutputDirectory = "build\qa_perf",
    [switch]$QuickSmoke,
    [switch]$SkipExport
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$presetName = "QA-PERF-WORST Windows x64"
$outputCandidate = if ([System.IO.Path]::IsPathRooted($OutputDirectory)) { $OutputDirectory } else { Join-Path $projectRoot $OutputDirectory }
$outputRoot = [System.IO.Path]::GetFullPath($outputCandidate)
$warmupSeconds = if ($QuickSmoke) { 0.25 } else { 60.0 }
$sampleSeconds = if ($QuickSmoke) { 2.0 } else { 600.0 }

if (-not (Test-Path -LiteralPath $GodotPath)) {
    throw "Godot executable not found: $GodotPath"
}
if (-not (Test-Path -LiteralPath (Join-Path $projectRoot "export_presets.cfg"))) {
    throw "export_presets.cfg is required for QA-PERF-WORST export validation"
}

$projectText = Get-Content -LiteralPath (Join-Path $projectRoot "project.godot") -Raw
if ($projectText -notmatch 'renderer/rendering_method="gl_compatibility"') {
    throw "QA-PERF-WORST requires gl_compatibility"
}
if ($projectText -notmatch 'window/size/window_width_override=1280' -or $projectText -notmatch 'window/size/window_height_override=720') {
    throw "QA-PERF-WORST requires the approved 1280x720 output override"
}

if (-not (Test-Path -LiteralPath $outputRoot)) {
    New-Item -ItemType Directory -Path $outputRoot | Out-Null
}

$stageRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("nice-journey-qa-perf-{0}" -f [System.Diagnostics.Process]::GetCurrentProcess().Id)
if (Test-Path -LiteralPath $stageRoot) {
    Remove-Item -LiteralPath $stageRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $stageRoot | Out-Null

try {
    foreach ($directoryName in @("src", "assets", "tests")) {
        Copy-Item -LiteralPath (Join-Path $projectRoot $directoryName) -Destination (Join-Path $stageRoot $directoryName) -Recurse
    }
    foreach ($fileName in @("icon.svg", "export_presets.cfg")) {
        Copy-Item -LiteralPath (Join-Path $projectRoot $fileName) -Destination (Join-Path $stageRoot $fileName)
    }
    $stageProject = $projectText -replace 'run/main_scene="[^"]+"', 'run/main_scene="res://tests/qa_perf_worst.tscn"'
    Set-Content -LiteralPath (Join-Path $stageRoot "project.godot") -Value $stageProject -Encoding UTF8

    $importOutput = @(& $GodotPath --headless --path $stageRoot --editor --quit | ForEach-Object { [string]$_ })
    if ($LASTEXITCODE -ne 0) {
        $importOutput | ForEach-Object { Write-Host $_ }
        throw "QA-PERF-WORST staging import/parse failed with exit code $LASTEXITCODE"
    }

    $exportedExe = Join-Path $outputRoot "nice-journey-qa-perf.exe"
    if (-not $SkipExport) {
        $exportOutput = @(& $GodotPath --headless --path $stageRoot --export-release $presetName $exportedExe | ForEach-Object { [string]$_ })
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $exportedExe)) {
            $exportOutput | ForEach-Object { Write-Host $_ }
            throw "QA-PERF-WORST release export failed"
        }
    }

    $runExecutable = if ($SkipExport) { $GodotPath } else { $exportedExe }
    $runArguments = if ($SkipExport) {
        @("--path", $stageRoot, "res://tests/qa_perf_worst.tscn", "--", "--warmup-seconds=$warmupSeconds", "--sample-seconds=$sampleSeconds")
    } else {
        @("--", "--warmup-seconds=$warmupSeconds", "--sample-seconds=$sampleSeconds")
    }
    $runOutput = @(& $runExecutable @runArguments | ForEach-Object { [string]$_ })
    $runExitCode = $LASTEXITCODE
    $resultLine = $runOutput | Where-Object { $_ -like "QA_PERF_WORST:*" } | Select-Object -Last 1
    if ($runExitCode -ne 0 -or -not $resultLine) {
        $runOutput | ForEach-Object { Write-Host $_ }
        throw "QA-PERF-WORST execution failed or produced no evidence line (exit $runExitCode)"
    }
    $result = $resultLine.Substring("QA_PERF_WORST:".Length).Trim() | ConvertFrom-Json

    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1 Name, NumberOfCores, NumberOfLogicalProcessors
    $gpu = Get-CimInstance Win32_VideoController | Select-Object -First 1 Name, DriverVersion
    $computer = Get-CimInstance Win32_ComputerSystem | Select-Object -First 1 TotalPhysicalMemory
    $os = Get-CimInstance Win32_OperatingSystem | Select-Object -First 1 Caption, Version, BuildNumber, OSArchitecture
    $evidence = [ordered]@{
        evidence_kind = "QA-PERF-WORST developer/reference run"
        generated_utc = [DateTime]::UtcNow.ToString("o")
        final_hardware_acceptance = $false
        exported_non_editor_build = (-not $SkipExport)
        quick_smoke = [bool]$QuickSmoke
        engine_version = (& $GodotPath --version | Select-Object -First 1).ToString().Trim()
        renderer_method = "gl_compatibility"
        output_resolution = "1280x720"
        reference_machine = [ordered]@{
            cpu = $cpu.Name
            cpu_cores = $cpu.NumberOfCores
            cpu_logical_processors = $cpu.NumberOfLogicalProcessors
            gpu = $gpu.Name
            gpu_driver = $gpu.DriverVersion
            ram_bytes = [int64]$computer.TotalPhysicalMemory
            os = $os.Caption
            os_version = $os.Version
            os_build = $os.BuildNumber
            os_architecture = $os.OSArchitecture
        }
        harness = $result
        # This script records developer/reference evidence only. It must never
        # become a DR-08 certification switch merely because route coverage or
        # timing happens to pass on the current machine.
        certification_blocked = $true
        certification_blockers = @(
            "Final DR-08 acceptance requires a separately identified minimum-class i5-8250U/UHD-620-equivalent hardware run.",
            "Final DR-08 acceptance requires the full 60-second warm-up plus at least 10 continuous measured minutes in an exported non-editor build.",
            "Harness route remains incomplete until representative production projectile entities, authored audio-stream mix, and authored Tenth Warden timing are available."
        )
    }
    $evidencePath = Join-Path $outputRoot "qa-perf-worst-latest.json"
    $evidence | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $evidencePath -Encoding UTF8
    Write-Host "QA-PERF-WORST evidence: $evidencePath"
    Write-Host ("Exported build: {0} | Quick smoke: {1} | Route complete: {2} | Timing thresholds on this machine: {3}" -f (-not $SkipExport), [bool]$QuickSmoke, [bool]$result.protocol_route_complete, [bool]$result.threshold_evaluation_reference_machine_only.thresholds_met)
} finally {
    if (Test-Path -LiteralPath $stageRoot) {
        Remove-Item -LiteralPath $stageRoot -Recurse -Force
    }
}
