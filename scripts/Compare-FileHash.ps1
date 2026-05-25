<#
.SYNOPSIS
  Compare the hash of a file against an expected value.

.DESCRIPTION
  Useful for verifying downloads (e.g. Kali Linux images).
  Supports SHA256, SHA1, and MD5.

.EXAMPLE
  \.Compare-FileHash.ps1 -FilePath "kali-linux.7z" -ExpectedHash "abc123..."
#>

param(
  [Parameter(Mandatory)]
  [string]$FilePath,

  [Parameter(Mandatory)]
  [string]$ExpectedHash,

  [ValidateSet("SHA256", "SHA1", "MD5")]
  [string]$Algorithm = "SHA256"
)

function Test-FileExists {
  param([string]$Path)
  if (-not (Test-Path -Path $Path -PathType Leaf)) {
    throw "File not found: $Path"
  }
}

function Test-ExpectedHash {
  param(
      [string]$Hash,
      [string]$Algorithm
  )

  $lengths = @{
      "SHA256" = 64
      "SHA1"   = 40
      "MD5"    = 32
  }

  $Hash = $Hash.Trim().ToLowerInvariant()

  if ($Hash.Length -ne $lengths[$Algorithm] -or -not ($Hash -match '^[0-9a-f]+$')) {
      throw "ExpectedHash must be $($lengths[$Algorithm]) hex characters for $Algorithm."
  }

  return $Hash
}

function Main {
  param(
      [string]$FilePath,
      [string]$ExpectedHash,
      [string]$Algorithm
  )

  try {
    Test-FileExists -path $FilePath;
    $ExpectedHash = Test-ExpectedHash -Hash $ExpectedHash -Algorithm $Algorithm

    $actual = (Get-FileHash -Path $FilePath -Algorithm $Algorithm -ErrorAction Stop).Hash.toLower()

    if ($actual -eq $ExpectedHash) {
      return [PSCustomObject]@{
        Success   = $true
        Expected  = $ExpectedHash
        Actual    = $actual
        Algorithm = $Algorithm
        FilePath  = $FilePath
      }
    }
    return [PSCustomObject]@{
      Success   = $false
      Expected  = $ExpectedHash
      Actual    = $actual
      Algorithm = $Algorithm
      FilePath  = $FilePath
    };
  } catch {
    throw "Failed to compute hash: $_"
  }
}

try {
  if ($MyInvocation.InvocationName -ne '.') {
    $result = Main @PSBoundParameters
    if ($result.Success) {
        Write-Output "✅ Hash matched!"
        exit 0
    } else {
        Write-Output "❌ Hash mismatch"
        Write-Output "Expected: $($result.Expected)"
        Write-Output "Actual:   $($result.Actual)"
        exit 1
    }
  }
} catch {
  Write-Error $_
  exit 2
}
