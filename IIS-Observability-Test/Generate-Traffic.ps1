param(
    [string]$BaseUrl = 'http://localhost:8080',
    [int]$Requests = 50,
    [int]$PauseMilliseconds = 500,
    # Every 5th request is an application error (exception, database failure, event log error, 503, 403, 401).
    [switch]$AppErrors
)
# Windows PowerShell 5.1+ / PowerShell 7. Use only against your own test site.
$base = $BaseUrl.TrimEnd('/')
$errorModes = @('exception', 'dberror', 'eventlog', 'typemismatch', 'unavailable', 'forbidden', 'unauthorized')
for ($i = 1; $i -le $Requests; $i++) {
    if ($AppErrors -and $i % 5 -eq 0) { $mode = $errorModes[($i / 5 - 1) % $errorModes.Count] }
    else { $mode = if ($i % 10 -eq 0) { 'error' } elseif ($i % 7 -eq 0) { 'slow' } else { 'ok' } }
    $uri = "$base/api.asp?mode=$mode"
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $response = Invoke-WebRequest -Uri $uri -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop
        $status = [int]$response.StatusCode
    } catch {
        $status = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 'NETWORK_ERROR' }
    }
    $watch.Stop()
    Write-Host ("{0,3}/{1}  HTTP {2}  {3,5}ms  {4}" -f $i, $Requests, $status, $watch.ElapsedMilliseconds, $mode)
    Start-Sleep -Milliseconds $PauseMilliseconds
}
