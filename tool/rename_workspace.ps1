# Run from a separate PowerShell window after closing editors and dev servers.
$ErrorActionPreference = 'Stop'
$sourceRoot = [IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent))
$parentRoot = Split-Path $sourceRoot -Parent
$targetRoot = [IO.Path]::GetFullPath((Join-Path $parentRoot 'Dayflower'))
if ($sourceRoot -ceq $targetRoot) { Write-Output 'Workspace is already Dayflower.'; exit }
if (!(Test-Path -LiteralPath (Join-Path $sourceRoot '.git') -PathType Container)) {
    throw 'Run this script from the main repository, not a linked worktree.'
}
if ((Split-Path $targetRoot -Parent) -ne $parentRoot -or $targetRoot -eq $parentRoot) {
    throw 'Destination must be the Dayflower folder beside this workspace.'
}
if (Test-Path -LiteralPath $targetRoot) { throw "Destination already exists: $targetRoot" }
$linkedPaths = @(& git -C $sourceRoot worktree list --porcelain | Where-Object { $_.StartsWith('worktree ') } | ForEach-Object { $_.Substring(9) })
if ($LASTEXITCODE -ne 0) { throw 'Could not inspect Git worktrees.' }
$oldPortable = $sourceRoot.Replace('\', '/')
$newPortable = $targetRoot.Replace('\', '/')
$repairPaths = @($linkedPaths | ForEach-Object {
    if ($_ -eq $oldPortable) { $newPortable }
    elseif ($_.StartsWith($oldPortable + '/')) { $newPortable + $_.Substring($oldPortable.Length) }
    else { $_ }
})
Set-Location -LiteralPath $parentRoot
Move-Item -LiteralPath $sourceRoot -Destination $targetRoot
& git -C $targetRoot worktree repair @repairPaths
if ($LASTEXITCODE -ne 0) { throw "Folder moved to $targetRoot, but Git worktree repair needs attention." }
$localSettings = Join-Path $targetRoot '.claude/settings.local.json'
if (Test-Path -LiteralPath $localSettings) {
    $content = [IO.File]::ReadAllText($localSettings)
    $content = $content.Replace($oldPortable, $newPortable).Replace($sourceRoot.Replace('\', '\\'), $targetRoot.Replace('\', '\\'))
    [IO.File]::WriteAllText($localSettings, $content)
}
Set-Location -LiteralPath $targetRoot
& flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'Folder moved. Run flutter pub get in the new folder before building.' }
Write-Output "Reopen the project in Codex at $targetRoot. Regenerate any platform build caches before building."
