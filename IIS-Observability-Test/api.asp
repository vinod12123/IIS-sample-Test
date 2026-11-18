<%@ Language="VBScript" %>
<%
Option Explicit
Response.Buffer = True
Response.ContentType = "application/json"
Response.CacheControl = "no-cache"
Dim mode, started, elapsed, eventLogged, conn, errNumber, errText, zero, bad
mode = LCase(Trim(Request.QueryString("mode")))
eventLogged = False

' Writes an entry to the Windows Application event log (source "WSH"), where the observability agent's
' Application channel picks it up. level: 1 = Error, 2 = Warning, 4 = Information. Failure to log is not fatal.
Sub WriteEvent(level, message)
  Dim shell
  On Error Resume Next
  Set shell = CreateObject("WScript.Shell")
  shell.LogEvent level, "IIS-Observability-Test: " & message
  eventLogged = (Err.Number = 0)
  Err.Clear
  On Error GoTo 0
End Sub

' Escapes text for a JSON string value.
Function J(text)
  J = Replace(Replace(CStr(text), "\", "\\"), """", "'")
End Function

Select Case mode
  Case "error"
    Response.Status = "500 Internal Server Error"
    Response.Write "{""status"":""error"",""scenario"":""intentional_http_500"",""message"":""Simulated server error for IIS access log testing""}"
  Case "exception"
    ' Unhandled VBScript runtime error: IIS returns 500 (500.100) and writes the ASP error to the access log
    ' (cs-uri-query: |<line>|<error code>|Division_by_zero).
    zero = 0
    Response.Write "{""result"":" & (10 / zero) & "}"
  Case "typemismatch"
    ' Unhandled type mismatch (ASP error 0013).
    bad = CLng("not-a-number")
    Response.Write "{""result"":" & bad & "}"
  Case "dberror"
    ' Handled failure of a dependency: the error goes to the access log, the Application event log and a 500 response.
    On Error Resume Next
    Set conn = CreateObject("ADODB.Connection")
    conn.ConnectionTimeout = 2
    conn.Open "Provider=NoSuchProvider;Data Source=orders-db.invalid;"
    errNumber = Err.Number
    errText = Err.Description
    Err.Clear
    On Error GoTo 0
    If errNumber = 0 Then errNumber = -1
    Response.AppendToLog "dberror " & errNumber
    WriteEvent 1, "Database connection failed (" & errNumber & "): " & errText
    Response.Status = "500 Internal Server Error"
    Response.Write "{""status"":""error"",""scenario"":""dberror"",""errorNumber"":" & errNumber & ",""message"":""" & J(errText) & """,""eventLogged"":" & LCase(CStr(eventLogged)) & "}"
  Case "eventlog"
    ' Application-level error that is logged to the Windows Application event log and returned as 500.
    Response.AppendToLog "application_error order_processing_failed"
    WriteEvent 1, "Order processing failed: simulated unhandled condition in api.asp"
    Response.Status = "500 Internal Server Error"
    Response.Write "{""status"":""error"",""scenario"":""eventlog"",""message"":""Order processing failed"",""eventLogged"":" & LCase(CStr(eventLogged)) & "}"
  Case "forbidden"
    Response.Status = "403 Forbidden"
    Response.Write "{""status"":""error"",""scenario"":""forbidden""}"
  Case "unauthorized"
    Response.Status = "401 Unauthorized"
    Response.Write "{""status"":""error"",""scenario"":""unauthorized""}"
  Case "unavailable"
    WriteEvent 2, "Upstream payment service unavailable"
    Response.Status = "503 Service Unavailable"
    Response.Write "{""status"":""error"",""scenario"":""unavailable"",""eventLogged"":" & LCase(CStr(eventLogged)) & "}"
  Case "slow"
    ' Simple capped CPU-bound delay for local testing. Avoid high request concurrency.
    started = Timer()
    Do
      elapsed = Timer() - started
      If elapsed < 0 Then elapsed = elapsed + 86400
    Loop While elapsed < 2
    Response.Status = "200 OK"
    Response.Write "{""status"":""ok"",""scenario"":""slow"",""delaySeconds"":2}"
  Case "badrequest"
    Response.Status = "400 Bad Request"
    Response.Write "{""status"":""error"",""scenario"":""badrequest""}"
  Case "ok", ""
    Response.Status = "200 OK"
    Response.Write "{""status"":""ok"",""scenario"":""healthy""}"
  Case Else
    Response.Status = "400 Bad Request"
    Response.Write "{""status"":""error"",""message"":""Unknown mode""}"
End Select
%>
