# Installs or upgrades Kindle Library on Windows. Personal use only.
#   irm https://raw.githubusercontent.com/mkol5222/kindle-lib-tool-dist/main/install.ps1 | iex
& {
    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'
    $base = 'https://github.com/mkol5222/kindle-lib-tool-dist/releases/latest/download'
    $arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'x64' }
    $name = "kindle-library-win-$arch.zip"
    $dest = Join-Path $env:LOCALAPPDATA 'Programs\Kindle Library'
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ("kindle-library-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $tmp | Out-Null
    try {
        Write-Host "Downloading Kindle Library for $arch..."
        Invoke-WebRequest "$base/$name" -OutFile "$tmp\$name" -UseBasicParsing
        Invoke-WebRequest "$base/SHA256SUMS" -OutFile "$tmp\SHA256SUMS" -UseBasicParsing
        $line = Get-Content "$tmp\SHA256SUMS" | Where-Object { $_ -match "  $([regex]::Escape($name))$" }
        $expected = ($line -split '\s+')[0]
        $actual = (Get-FileHash "$tmp\$name" -Algorithm SHA256).Hash.ToLower()
        if (-not $expected -or $expected -ne $actual) { throw 'Checksum mismatch, nothing installed.' }

        Get-Process 'Kindle Library' -ErrorAction SilentlyContinue | Stop-Process -Force
        Start-Sleep -Seconds 1
        if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
        Expand-Archive "$tmp\$name" -DestinationPath $dest
        $exe = Join-Path $dest 'Kindle Library.exe'
        $shell = New-Object -ComObject WScript.Shell
        $link = $shell.CreateShortcut((Join-Path ([Environment]::GetFolderPath('Programs')) 'Kindle Library.lnk'))
        $link.TargetPath = $exe
        $link.WorkingDirectory = $dest
        $link.Save()
        Write-Host "Installed Kindle Library $((Get-Item $exe).VersionInfo.ProductVersion) in $dest (Start menu: Kindle Library)"
        Start-Process $exe
    } finally {
        Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}
