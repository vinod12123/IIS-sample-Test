# IIS Observability Test v2 — Windows 11

A small **HTML + Classic ASP** app for testing real HTTP 200/400/404/500 codes, ~2-second latency, HTTP access logs, and request rates in Windows IIS. No external packages. Intended for a local test machine, **not a production/public server**.

## Install / update

1. Press **Win + R**, enter `optionalfeatures`.
2. Under **Internet Information Services → World Wide Web Services**, enable:
   - **Application Development Features → ASP** (**Classic ASP**, not merely ASP.NET).
   - **Common HTTP Features → Static Content** and **Default Document**.
   - **Health and Diagnostics → HTTP Logging**.
3. Extract the archive. Copy the **contents of `IIS-Observability-Test`** to `C:\inetpub\wwwroot\IIS-Observability-Test\`, **overwriting old files**.
4. In IIS Manager (`inetmgr`) verify **Default Web Site → IIS-Observability-Test** exists; right-click its folder and **Convert to Application** if necessary. Set an app pool configured for Classic ASP (Integrated pipeline; defaults usually work).
5. Visit `http://localhost/IIS-Observability-Test/` and use **Check IIS / ASP endpoints**. Use Ctrl+F5 if cached.

> Important: the browser dashboard and its **Start traffic** timer can appear to work even when `.asp` endpoints do not execute. This version explicitly checks `health.asp` and shows response status, body, and pass/mismatch.

## Expected results

| Button | Actual endpoint | Expected HTTP | Notes |
| --- | --- | --- | --- |
| Healthy | `api.asp?mode=ok` | 200 | Executes Classic ASP |
| Server error | `api.asp?mode=error` | 500 | Intentionally returned; does not cause a Windows Event Log exception |
| Slow response | `api.asp?mode=slow` | 200 after ~2 s | Simulates latency using a bounded busy loop; avoid high concurrency |
| Missing page | `does-not-exist-*.html` | 404 | IIS returns the 404; it may return an HTML body |
| Bad request | `api.asp?mode=badrequest` | 400 | Intentionally returned |
| Unhandled exception | `api.asp?mode=exception` | 500 | Real VBScript runtime error (division by zero). IIS returns 500.100 and records the ASP error (line, error code, `Division_by_zero`) in the access log's `cs-uri-query` field |
| Type mismatch | `api.asp?mode=typemismatch` | 500 | Real VBScript runtime error (ASP 0013), logged by IIS the same way |
| Database failure | `api.asp?mode=dberror` | 500 | Handled dependency failure: access log marker `dberror <code>`, Windows **Application** event log error (source `WSH`), JSON with `eventLogged` |
| Event log error | `api.asp?mode=eventlog` | 500 | Access log marker `application_error ...` and an Application event log error |
| Upstream down | `api.asp?mode=unavailable` | 503 | Application event log warning |
| Forbidden / Unauthorized | `api.asp?mode=forbidden` / `unauthorized` | 403 / 401 | Returned status only |

`eventLogged` in the JSON is `false` when the app pool identity may not write to the Application log; the access log lines are still produced.

To see the application errors in the agent: IIS access logs need the log source (`iis=C:\inetpub\logs\LogFiles\W3SVC1`) and read access for `NT SERVICE\observe-agent`; the Application event log channel is collected by default.

**404 and 500 are successful results when expected.** Read the status, expected code, and PASS/MISMATCH in the request log. The browser's fetch API resolves for HTTP 4xx and 5xx; they are not network errors.

## Manual troubleshooting

Check in a browser:

- `http://localhost/IIS-Observability-Test/health.asp` should display `{"status":"healthy","service":"iis-observability-test"}`.
- `http://localhost/IIS-Observability-Test/api.asp?mode=ok` should return JSON and HTTP 200.
- If `.asp` gives **404.3**, ASP is not installed/allowed or handler mapping is missing. Enable the Classic ASP Windows feature.
- If **404.0**, verify the physical folder and IIS application path; verify `api.asp` exists.
- If **500.19**, inspect IIS configuration and permissions.
- If **500.100**, inspect Classic ASP errors / code.
- If an HTTP 500 body is replaced by an IIS HTML error page, the HTTP **500 code still works for monitoring**.
- Press **F12 → Network** to inspect request status; ensure no browser extension is intercepting requests.
- Default IIS access logs: `C:\inetpub\logs\LogFiles\W3SVC*\u_ex*.log`. Check site settings in IIS Manager → Logging.

## Generate traffic in PowerShell

```powershell
cd C:\inetpub\wwwroot\IIS-Observability-Test
Set-ExecutionPolicy -Scope Process Bypass
.\Generate-Traffic.ps1 -BaseUrl 'http://localhost/IIS-Observability-Test' -Requests 50
# add application errors (exceptions, database failures, 503/403/401) every 5th request:
.\Generate-Traffic.ps1 -BaseUrl 'http://localhost/IIS-Observability-Test' -Requests 100 -AppErrors
```

## Telemetry notes

IIS HTTP log collection must be enabled/configured for the installed observability agent; hosting a test application alone does not guarantee traces, errors, or HTTP metrics. Host CPU/memory collection and Windows Event Log collection may be separate integrations. The intentional 500 is a **returned status**, not an unhandled application exception.
