param(
    [string]$GodotPath = "C:\Users\LENOVO\Desktop\GodotC#\Godot_v4.6.2-stable_mono_win64_console.exe",
    [string]$OutputPath = "docs\evidence\reference-validation-latest.json",
    [switch]$SkipRendererSmoke
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

if (-not (Test-Path -LiteralPath $GodotPath)) {
    throw "Godot executable not found: $GodotPath"
}

function Invoke-GodotRun {
    param([string[]]$Arguments)
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    $lines = @(& $GodotPath @Arguments | ForEach-Object { [string]$_ })
    $exitCode = $LASTEXITCODE
    $watch.Stop()
    $scriptErrors = @($lines | Where-Object {
        $_ -match 'SCRIPT ERROR:' -or
        $_ -match 'Parse Error:' -or
        $_ -match 'Failed to load script'
    })
    [pscustomobject]@{
        exit_code = $exitCode
        duration_ms = [math]::Round($watch.Elapsed.TotalMilliseconds, 3)
        output = $lines
        script_error_count = $scriptErrors.Count
        script_error_lines = $scriptErrors
    }
}

function Get-HashOrNull {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

$engineVersion = (& $GodotPath --version | Select-Object -First 1).ToString().Trim()
$projectText = Get-Content -LiteralPath "project.godot" -Raw
$renderer = if ($projectText -match 'renderer/rendering_method="([^"]+)"') { $Matches[1] } else { $null }
$viewportWidth = if ($projectText -match 'window/size/viewport_width=(\d+)') { [int]$Matches[1] } else { $null }
$viewportHeight = if ($projectText -match 'window/size/viewport_height=(\d+)') { [int]$Matches[1] } else { $null }
$windowWidth = if ($projectText -match 'window/size/window_width_override=(\d+)') { [int]$Matches[1] } else { $null }
$windowHeight = if ($projectText -match 'window/size/window_height_override=(\d+)') { [int]$Matches[1] } else { $null }

$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1 Name, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed
$gpu = Get-CimInstance Win32_VideoController | Select-Object -First 1 Name, DriverVersion, AdapterRAM, VideoModeDescription
$computer = Get-CimInstance Win32_ComputerSystem | Select-Object -First 1 Manufacturer, Model, TotalPhysicalMemory
$os = Get-CimInstance Win32_OperatingSystem | Select-Object -First 1 Caption, Version, BuildNumber, OSArchitecture
$projectDrive = ([System.IO.Path]::GetPathRoot($projectRoot)).TrimEnd('\').TrimEnd(':')
$volume = Get-Volume -DriveLetter $projectDrive -ErrorAction SilentlyContinue | Select-Object -First 1 DriveLetter, FileSystem, Size, SizeRemaining
$disk = $null
try {
    $disk = Get-Partition -DriveLetter $projectDrive -ErrorAction Stop | Get-Disk | Select-Object -First 1 FriendlyName, BusType, MediaType, Size
} catch {
    $disk = $null
}

$tests = @(Get-ChildItem -LiteralPath "tests" -Filter "test_*.gd" -File | Sort-Object Name)
$manifest = @()
foreach ($test in $tests) {
    $manifest += [pscustomobject]@{
        name = $test.Name
        resource_path = "res://tests/$($test.Name)"
        sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $test.FullName).Hash.ToLowerInvariant()
    }
}

$results = @()
$editor = Invoke-GodotRun @("--headless", "--path", ".", "--editor", "--quit")
$results += [pscustomobject]@{ kind = "editor_parse"; name = "editor_parse"; exit_code = $editor.exit_code; duration_ms = $editor.duration_ms; script_error_count = $editor.script_error_count }
if ($editor.script_error_count -gt 0) {
    $editor.script_error_lines | ForEach-Object { Write-Host $_ }
}

foreach ($test in $manifest) {
    $run = Invoke-GodotRun @("--headless", "--path", ".", "--script", $test.resource_path)
    $results += [pscustomobject]@{ kind = "test"; name = $test.name; exit_code = $run.exit_code; duration_ms = $run.duration_ms; script_error_count = $run.script_error_count }
    if ($run.exit_code -ne 0 -or $run.script_error_count -gt 0) {
        Write-Host ($run.output -join [Environment]::NewLine)
    }
}

$mainSmoke = Invoke-GodotRun @("--headless", "--path", ".", "--quit-after", "2")
$results += [pscustomobject]@{ kind = "main_scene_headless_smoke"; name = "main_scene"; exit_code = $mainSmoke.exit_code; duration_ms = $mainSmoke.duration_ms; script_error_count = $mainSmoke.script_error_count }
if ($mainSmoke.script_error_count -gt 0) {
    $mainSmoke.script_error_lines | ForEach-Object { Write-Host $_ }
}

$rendererSmoke = $null
if (-not $SkipRendererSmoke) {
    $run = Invoke-GodotRun @("--path", ".", "--script", "res://tests/reference_performance_smoke.gd")
    $smokeLine = $run.output | Where-Object { $_ -like "REFERENCE_PERF_SMOKE:*" } | Select-Object -Last 1
    $smokeData = $null
    if ($smokeLine) {
        $smokeData = ($smokeLine.Substring("REFERENCE_PERF_SMOKE:".Length).Trim() | ConvertFrom-Json)
    }
    $rendererLine = $run.output | Where-Object { $_ -match "OpenGL|Vulkan|Compatibility|Using.*Device" } | Select-Object -First 1
    $rendererSmoke = [pscustomobject]@{
        exit_code = $run.exit_code
        duration_ms = $run.duration_ms
        script_error_count = $run.script_error_count
        renderer_log = $rendererLine
        metrics = $smokeData
        visual_acceptance = $false
        note = "Reference greybox smoke only; not a DR-08 minimum-hardware or worst-case acceptance result."
    }
}

$evidence = [ordered]@{
    evidence_kind = "DR-08-safe reference validation and performance smoke"
    generated_utc = [DateTime]::UtcNow.ToString("o")
    final_hardware_acceptance = $false
    project_root = $projectRoot
    engine = [ordered]@{
        version = $engineVersion
        renderer_method = $renderer
        world_viewport = "$viewportWidth`x$viewportHeight"
        window_override = "$windowWidth`x$windowHeight"
    }
    reference_machine = [ordered]@{
        manufacturer = $computer.Manufacturer
        model = $computer.Model
        cpu = $cpu.Name
        cpu_cores = $cpu.NumberOfCores
        cpu_logical_processors = $cpu.NumberOfLogicalProcessors
        ram_bytes = [int64]$computer.TotalPhysicalMemory
        gpu = $gpu.Name
        gpu_driver = $gpu.DriverVersion
        reported_display_mode = $gpu.VideoModeDescription
        os = $os.Caption
        os_version = $os.Version
        os_build = $os.BuildNumber
        os_architecture = $os.OSArchitecture
        project_volume = $volume
        project_disk = $disk
    }
    content_identity = [ordered]@{
        project_godot_sha256 = Get-HashOrNull "project.godot"
        implementation_state_sha256 = Get-HashOrNull "docs\IMPLEMENTATION_STATE.md"
        master_spec_sha256 = Get-HashOrNull "..\Nice_Journey_Master_Game_Specification_V2_1.md"
        validation_script_sha256 = Get-HashOrNull "tools\reference_validation.ps1"
        performance_smoke_script_sha256 = Get-HashOrNull "tests\reference_performance_smoke.gd"
    }
    test_manifest_count = $manifest.Count
    test_manifest = $manifest
    validation_results = $results
    renderer_active_smoke = $rendererSmoke
    limitations = @(
        "Current gameplay greybox is not the authored section 41.1 worst-case scene.",
        "Final DR-08 acceptance has not been run on the approved minimum hardware class; this reference-machine run cannot substitute for it.",
        "Headless validation does not prove rendering quality, pixel readability, letterboxing, or other visual acceptance.",
        "Renderer-active smoke is a reference-machine baseline only and must not be called final performance acceptance."
    )
}

$outputFull = Join-Path $projectRoot $OutputPath
$outputDir = Split-Path -Parent $outputFull
if (-not (Test-Path -LiteralPath $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}
$evidence | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $outputFull -Encoding UTF8

$failed = @($results | Where-Object { $_.exit_code -ne 0 -or $_.script_error_count -gt 0 })
if ($rendererSmoke -ne $null -and ($rendererSmoke.exit_code -ne 0 -or $rendererSmoke.script_error_count -gt 0)) {
    $failed += [pscustomobject]@{ name = "reference_performance_smoke"; exit_code = $rendererSmoke.exit_code; script_error_count = $rendererSmoke.script_error_count }
}

Write-Host "Evidence: $outputFull"
Write-Host "Engine: $engineVersion | Renderer: $renderer"
Write-Host "Tests: $($manifest.Count) | Failures: $($failed.Count)"
if ($rendererSmoke -ne $null -and $rendererSmoke.metrics -ne $null) {
    Write-Host ("Reference smoke: p50={0} ms p95={1} ms p99={2} ms max={3} ms peakStatic={4} bytes" -f $rendererSmoke.metrics.frame_ms_p50, $rendererSmoke.metrics.frame_ms_p95, $rendererSmoke.metrics.frame_ms_p99, $rendererSmoke.metrics.frame_ms_max, $rendererSmoke.metrics.max_static_memory_bytes)
}

if ($failed.Count -gt 0) { exit 1 }
exit 0
