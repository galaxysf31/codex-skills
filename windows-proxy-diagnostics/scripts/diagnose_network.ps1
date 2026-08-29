[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string[]]$Domains = @('api.openai.com', 'chatgpt.com'),

    [Parameter(Mandatory = $false)]
    [string]$ProxyUrl,

    [ValidateRange(3, 60)]
    [int]$TimeoutSeconds = 10
)

$ErrorActionPreference = 'Continue'
$Domains = @(
    $Domains |
        ForEach-Object { $_ -split ',' } |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ } |
        Select-Object -Unique
)

function Get-ARecords {
    param([string]$Domain)

    try {
        return @(
            Resolve-DnsName -Name $Domain -Type A -DnsOnly -ErrorAction Stop |
                Where-Object Type -eq 'A' |
                Select-Object -ExpandProperty IPAddress -Unique
        )
    }
    catch {
        return @()
    }
}

function Get-DoHARecords {
    param(
        [string]$Domain,
        [string]$Provider
    )

    $template = if ($Provider -eq 'Google') {
        'https://dns.google/resolve?name={0}&type=A'
    }
    else {
        'https://cloudflare-dns.com/dns-query?name={0}&type=A'
    }

    try {
        $response = Invoke-RestMethod `
            -Uri ($template -f [uri]::EscapeDataString($Domain)) `
            -Headers @{ Accept = 'application/dns-json' } `
            -TimeoutSec $TimeoutSeconds

        return @(
            $response.Answer |
                Where-Object type -eq 1 |
                Select-Object -ExpandProperty data -Unique
        )
    }
    catch {
        return @()
    }
}

function Format-ProxyEndpoint {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return '(not set)'
    }

    $candidate = $Value
    if ($candidate -match ';') {
        $httpsPart = ($candidate -split ';' | Where-Object { $_ -match '^https=' } | Select-Object -First 1)
        $candidate = if ($httpsPart) { $httpsPart -replace '^https=', '' } else { ($candidate -split ';')[0] -replace '^http=', '' }
    }
    $candidate = $candidate -replace '^https?=', ''
    if ($candidate -notmatch '^[a-z]+://') {
        $candidate = "http://$candidate"
    }

    try {
        $uri = [uri]$candidate
        return "$($uri.Scheme)://$($uri.Host):$($uri.Port)"
    }
    catch {
        return '(set, unparseable; value hidden)'
    }
}

function Invoke-CurlProbe {
    param(
        [string]$Domain,
        [string]$ResolvedIp,
        [string]$Proxy
    )

    $format = 'http=%{http_code} remote=%{remote_ip} dns=%{time_namelookup}s connect=%{time_connect}s tls=%{time_appconnect}s total=%{time_total}s err=%{errormsg}'
    $arguments = @('-sS', '-o', 'NUL', '--connect-timeout', $TimeoutSeconds, '--max-time', ($TimeoutSeconds + 5), '-w', $format)

    if ($Proxy) {
        $arguments += @('-x', $Proxy)
    }
    else {
        $arguments += @('--noproxy', '*')
        if ($ResolvedIp) {
            $arguments += @('--resolve', "${Domain}:443:${ResolvedIp}")
        }
    }

    $arguments += "https://$Domain/"
    $output = & curl.exe @arguments 2>&1
    return [pscustomobject]@{
        ExitCode = $LASTEXITCODE
        Detail   = ($output -join ' ')
    }
}

Write-Output '=== Local DNS configuration ==='
Get-DnsClientServerAddress -AddressFamily IPv4 |
    Where-Object { $_.ServerAddresses.Count -gt 0 } |
    Select-Object InterfaceAlias, ServerAddresses |
    Format-Table -AutoSize

Write-Output '=== Hosts overrides for requested domains ==='
$hostsPath = Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'
$hostLines = Get-Content -LiteralPath $hostsPath -ErrorAction SilentlyContinue |
    Where-Object {
        $line = $_
        $Domains | Where-Object { $line -match [regex]::Escape($_) }
    }
if ($hostLines) { $hostLines } else { '(none)' }

Write-Output '=== Proxy configuration ==='
netsh winhttp show proxy
$internetSettings = Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction SilentlyContinue
$userProxy = if ($internetSettings.ProxyEnable -eq 1) { Format-ProxyEndpoint $internetSettings.ProxyServer } else { '(disabled)' }
[pscustomobject]@{
    WindowsUserProxy = $userProxy
    AutoConfig       = if ($internetSettings.AutoConfigURL) { '(configured; URL hidden)' } else { '(not set)' }
} | Format-List

Get-ChildItem Env: |
    Where-Object Name -Match '^(HTTP|HTTPS|ALL|NO)_PROXY$' |
    ForEach-Object {
        [pscustomobject]@{ Name = $_.Name; Endpoint = Format-ProxyEndpoint $_.Value }
    } |
    Format-Table -AutoSize

if (-not $ProxyUrl -and $internetSettings.ProxyEnable -eq 1) {
    $ProxyUrl = $userProxy
}

if ($ProxyUrl -and $ProxyUrl -notmatch '^\(') {
    try {
        $proxyUri = [uri]$ProxyUrl
        if ($proxyUri.IsLoopback) {
            Write-Output '=== Local proxy listener ==='
            $listeners = Get-NetTCPConnection -LocalPort $proxyUri.Port -State Listen -ErrorAction SilentlyContinue
            if ($listeners) {
                $listeners | Select-Object LocalAddress, LocalPort, OwningProcess | Format-Table -AutoSize
                $processIds = $listeners.OwningProcess | Select-Object -Unique
                Get-Process -Id $processIds -ErrorAction SilentlyContinue |
                    Select-Object Id, ProcessName, Path |
                    Format-Table -AutoSize
            }
            else {
                Write-Output "No listener found on loopback port $($proxyUri.Port)."
            }
        }
    }
    catch {
        Write-Output 'Proxy URL could not be parsed; proxy probes will be skipped.'
        $ProxyUrl = $null
    }
}

Write-Output '=== DNS and HTTPS probes ==='
foreach ($domain in $Domains) {
    $domain = $domain.Trim()
    if (-not $domain) { continue }

    $local = Get-ARecords $domain
    $google = Get-DoHARecords -Domain $domain -Provider 'Google'
    $cloudflare = Get-DoHARecords -Domain $domain -Provider 'Cloudflare'
    $reference = @($google + $cloudflare | Select-Object -Unique)
    $dnsMismatch = $false
    if ($local.Count -gt 0 -and $reference.Count -gt 0) {
        $dnsMismatch = @($local | Where-Object { $_ -notin $reference }).Count -gt 0
    }

    Write-Output "--- $domain ---"
    Write-Output "Local DNS:      $($local -join ', ')"
    Write-Output "Google DoH:     $($google -join ', ')"
    Write-Output "Cloudflare DoH: $($cloudflare -join ', ')"
    Write-Output "DNS mismatch:   $dnsMismatch"

    $correctIp = $reference | Select-Object -First 1
    if ($correctIp) {
        $direct = Invoke-CurlProbe -Domain $domain -ResolvedIp $correctIp
        Write-Output "Direct/correct-IP: exit=$($direct.ExitCode) $($direct.Detail)"
    }
    else {
        Write-Output 'Direct/correct-IP: skipped because no DoH reference address was available.'
    }

    if ($ProxyUrl -and $ProxyUrl -notmatch '^\(') {
        $proxied = Invoke-CurlProbe -Domain $domain -Proxy $ProxyUrl
        Write-Output "Via proxy $(Format-ProxyEndpoint $ProxyUrl): exit=$($proxied.ExitCode) $($proxied.Detail)"
    }
    else {
        Write-Output 'Via proxy: skipped because no usable proxy URL was found.'
    }
}

Write-Output '=== Interpretation reminder ==='
Write-Output 'A completed TLS request with any nonzero HTTP status confirms network reachability. If DoH differs from local DNS and direct TLS resets while proxy TLS succeeds, secure DNS fixes resolution only; the affected application must still use the proxy.'
