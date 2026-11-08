# Installs or upgrades Kindle Library on Windows. Personal use only.
#   irm https://raw.githubusercontent.com/mkol5222/kindle-lib-tool-dist/main/install.ps1 | iex
# Runs the release's setup program silently: per user, no administrator rights, Start menu and uninstall entries.
& {
    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'
    $release = Invoke-RestMethod 'https://api.github.com/repos/mkol5222/kindle-lib-tool-dist/releases/latest' -UseBasicParsing
    $suffix = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { '-arm64' } else { '' }
    $version = $release.tag_name.TrimStart('v')
    $name = "Kindle-Library-Setup-$version$suffix.exe"
    $asset = $release.assets | Where-Object { $_.name -eq $name }
    $sums = $release.assets | Where-Object { $_.name -eq 'SHA256SUMS' }
    if (-not $asset -or -not $sums) { throw "The release has no $name." }
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ("kindle-library-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $tmp | Out-Null
    try {
        Write-Host "Downloading Kindle Library $version..."
        Invoke-WebRequest $asset.browser_download_url -OutFile "$tmp\$name" -UseBasicParsing
        Invoke-WebRequest $sums.browser_download_url -OutFile "$tmp\SHA256SUMS" -UseBasicParsing
        $line = Get-Content "$tmp\SHA256SUMS" | Where-Object { $_ -match "  $([regex]::Escape($name))$" }
        $expected = ($line -split '\s+')[0]
        $actual = (Get-FileHash "$tmp\$name" -Algorithm SHA256).Hash.ToLower()
        if (-not $expected -or $expected -ne $actual) { throw 'Checksum mismatch, nothing installed.' }

        Get-Process 'Kindle Library' -ErrorAction SilentlyContinue | Stop-Process -Force
        Start-Sleep -Seconds 1
        Write-Host 'Installing...'
        Start-Process -FilePath "$tmp\$name" -ArgumentList '/S' -Wait
        $exe = Join-Path $env:LOCALAPPDATA 'Programs\Kindle Library\Kindle Library.exe'
        if (-not (Test-Path $exe)) { throw "Setup finished but $exe is missing." }
        Write-Host "Installed Kindle Library $version (Start menu: Kindle Library)"
        Start-Process $exe
    } finally {
        Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}
