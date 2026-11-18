<%@ Language=VBScript %>
<%
Option Explicit
Response.ContentType = "application/json"
Response.CacheControl = "no-cache"
Response.Write "{""status"":""healthy"",""service"":""iis-observability-test""}"
%>
