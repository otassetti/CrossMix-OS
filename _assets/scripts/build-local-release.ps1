param(
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$Version = '1.3.11',
    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory,
    [string]$SevenZip = 'C:\Program Files\7-Zip\7z.exe'
)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$utf8 = [System.Text.UTF8Encoding]::new($false)
function Invoke-Checked([string]$Program, [string[]]$Arguments) {
    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Program failed with exit code $LASTEXITCODE" }
}
if (!(Test-Path -LiteralPath $SevenZip)) { throw 'Install 7-Zip or pass -SevenZip.' }
$output = [IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Path $output -Force | Out-Null
$archive = Join-Path $output "CrossMix-OS_v$Version.zip"
if (Test-Path -LiteralPath $archive) { throw "Output already exists: $archive" }
$work = Join-Path $output ('build-' + [guid]::NewGuid().ToString('N'))
$stage = Join-Path $work 'sdcard'
New-Item -ItemType Directory -Path $stage -Force | Out-Null
Push-Location $repo
try {
    $branch = git branch --show-current
    if ($branch -ne 'main') { throw 'Run this build from main.' }
    $sha = git rev-parse HEAD
    if ($LASTEXITCODE -ne 0) { throw 'Cannot read HEAD.' }
    # Export tracked files, then normalize all runtime scripts below.
    $sourceZip = Join-Path $work 'source.zip'
    Write-Host "Exporting main ($sha)..."
    Invoke-Checked git @('archive', '--format=zip', "--output=$sourceZip", 'HEAD')
    Write-Host 'Preparing SD card files...'
    Invoke-Checked $SevenZip @('x', $sourceZip, "-o$stage", '-y', '-bso0')
    # Include tracked local patches, but never arbitrary untracked PC files.
    $patches = @(git -c core.quotepath=false diff HEAD --name-only --diff-filter=ACMRT)
    foreach ($relative in $patches) {
        $source = Join-Path $repo $relative
        $target = Join-Path $stage $relative
        New-Item -ItemType Directory -Path (Split-Path $target) -Force | Out-Null
        if ($relative.EndsWith('.sh') -or $relative.EndsWith('.txt')) {
            [IO.File]::WriteAllText($target, [IO.File]::ReadAllText($source).Replace("`r`n", "`n"), $utf8)
        } else { Copy-Item -LiteralPath $source -Destination $target -Force }
    }
    foreach ($relative in @(git -c core.quotepath=false diff HEAD --name-only --diff-filter=D)) {
        $target = Join-Path $stage $relative
        if (Test-Path -LiteralPath $target -PathType Leaf) { Remove-Item -LiteralPath $target }
    }
    # Explicitly include new runtime files while excluding other untracked files.
    $newRuntimeFiles = @(
        'System/resources/default_state.json',
        'System/usr/trimui/scripts/starttab_switcher.sh',
        'System/usr/trimui/scripts/restore_fw_settings.sh'
    )
    foreach ($relative in $newRuntimeFiles) {
        $target = Join-Path $stage $relative
        New-Item -ItemType Directory -Path (Split-Path $target) -Force | Out-Null
        [IO.File]::WriteAllText($target, [IO.File]::ReadAllText((Join-Path $repo $relative)).Replace("`r`n", "`n"), $utf8)
    }
    # Some committed blobs already have CRLF: git archive does not normalize them.
    # Include shell launchers stored without .sh (PortMaster uses .txt files too).
    foreach ($file in Get-ChildItem -LiteralPath $stage -Recurse -Force -File) {
        $stream = [IO.File]::OpenRead($file.FullName)
        try {
            $prefix = [byte[]]::new(5)
            $read = $stream.Read($prefix, 0, 5)
        } finally { $stream.Dispose() }
        $bom = $read -ge 3 -and $prefix[0] -eq 239 -and $prefix[1] -eq 187 -and $prefix[2] -eq 191
        $offset = 0
        if ($bom) { $offset = 3 }
        $shebang = $read -ge ($offset + 2) -and $prefix[$offset] -eq 35 -and $prefix[$offset + 1] -eq 33
        if ($file.Extension -ne '.sh' -and !$shebang) { continue }
        $content = [IO.File]::ReadAllText($file.FullName)
        if ($content.Contains("`r") -or $bom) {
            [IO.File]::WriteAllText($file.FullName, $content.Replace("`r`n", "`n").Replace("`r", "`n"), $utf8)
        }
    }
    [IO.File]::WriteAllText((Join-Path $stage 'System/usr/trimui/crossmix-version.txt'), "$Version`n", $utf8)
    $minimum = [IO.File]::ReadAllLines((Join-Path $stage 'trimui/firmwares/MinFwVersion.txt'))
    $firmware = Join-Path $stage "trimui/firmwares/firmware_tsp_v$($minimum[0])_$($minimum[1]).7z.001"
    if (!(Test-Path -LiteralPath $firmware)) { throw "Required firmware missing: $firmware" }
    Invoke-Checked $SevenZip @('t', $firmware, '-bso0')
    Write-Host 'Extracting RetroArch cores...'
    $cores = Join-Path $stage 'RetroArch/.retroarch/cores'
    foreach ($core in @(Get-ChildItem -LiteralPath $cores -Filter '*.7z' -File)) {
        Invoke-Checked $SevenZip @('x', $core.FullName, "-o$cores", '-y', '-bso0')
        Remove-Item -LiteralPath $core.FullName
    }
    Get-ChildItem -LiteralPath $stage -Recurse -Force -File -Filter '.gitkeep' | Remove-Item
    # Delete only known export paths, after checking they stay inside this stage.
    foreach ($relative in @('_assets', '.github', 'README.md', 'LICENSE', '.gitignore', '.gitattributes', 'AGENTS.md')) {
        $target = [IO.Path]::GetFullPath((Join-Path $stage $relative))
        if (!$target.StartsWith($stage + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
            throw 'Unsafe export cleanup path.'
        }
        if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
    }
    Push-Location $stage
    try {
        Write-Host 'Compressing local release...'
        Invoke-Checked $SevenZip @('a', 'RetroArch/default_config.7z', 'RetroArch/retroarch.cfg', 'RetroArch/.retroarch/config/*', '-bso0')
        Invoke-Checked $SevenZip @('a', '-tzip', '-mx=5', '-mcu=on', $archive, './*', '-bso0')
    } finally { Pop-Location }
    Write-Host 'Testing release integrity...'
    Invoke-Checked $SevenZip @('t', $archive, '-bso0')
    # Check actual archive bytes, not normalized copies used only for testing.
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $package = [IO.Compression.ZipFile]::OpenRead($archive)
    try {
        $scriptCount = 0
        foreach ($entry in $package.Entries) {
            if ($entry.FullName.EndsWith('/')) { continue }
            $stream = $entry.Open()
            try {
                $prefix = [byte[]]::new(5)
                $read = $stream.Read($prefix, 0, 5)
            } finally { $stream.Dispose() }
            $bom = $read -ge 3 -and $prefix[0] -eq 239 -and $prefix[1] -eq 187 -and $prefix[2] -eq 191
            $offset = 0
            if ($bom) { $offset = 3 }
            $shebang = $read -ge ($offset + 2) -and $prefix[$offset] -eq 35 -and $prefix[$offset + 1] -eq 33
            if (!$entry.FullName.EndsWith('.sh') -and !$shebang) { continue }
            $reader = [IO.StreamReader]::new($entry.Open())
            try { $content = $reader.ReadToEnd() } finally { $reader.Dispose() }
            if ($bom -or $content.Contains("`r")) { throw "Non-Linux script in ZIP: $($entry.FullName)" }
            $scriptCount++
        }
        foreach ($relative in @('System/usr/trimui/scripts/update_common.sh', 'System/usr/trimui/scripts/crossmix_update.sh') + $newRuntimeFiles) {
            if (!$package.GetEntry($relative)) { throw "Required ZIP entry missing: $relative" }
        }
        Write-Host "Verified Linux line endings for $scriptCount archived scripts."
    } finally { $package.Dispose() }
    $hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
    [IO.File]::WriteAllText("$archive.sha256", "$hash  $([IO.Path]::GetFileName($archive))`n", $utf8)
    $manifest = [ordered]@{
        version = $Version; kind = 'local development build'; commit = $sha
        localPatches = $patches; newRuntimeFiles = $newRuntimeFiles; firmware = "$($minimum[0]) ($($minimum[1]))"
        archiveBytes = (Get-Item -LiteralPath $archive).Length; sha256 = $hash
        unpackedBytes = (Get-ChildItem -LiteralPath $stage -Recurse -Force -File | Measure-Object Length -Sum).Sum
    }
    [IO.File]::WriteAllText("$archive.json", ($manifest | ConvertTo-Json), $utf8)
    Write-Host "Ready: $archive"
    Write-Host "Staged files retained for inspection: $stage"
} finally { Pop-Location }
