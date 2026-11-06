$ErrorActionPreference = 'Stop'
$base = 'http://127.0.0.1:5000/api/reimbursements'
$script:checks = 0
function Check($condition, $label) {
    if (!$condition) { throw "FAIL: $label" }
    $script:checks++
    Write-Host "PASS: $label"
}
function Request($method, $url, $body = $null, $type = 'application/json') {
    $options = @{ Method = $method; Uri = $url; SkipHttpErrorCheck = $true; TimeoutSec = 15 }
    if ($null -ne $body) { $options.Body = $body; $options.ContentType = $type }
    $response = Invoke-WebRequest @options
    $json = $response.Content | ConvertFrom-Json
    Check ($json.PSObject.Properties.Name.Count -eq 5 -and $null -ne $json.success -and $json.message -and $json.traceId -and $null -ne $json.errors) "envelope $method $url"
    if ($response.StatusCode -ge 400) { Check (!$json.success -and $null -eq $json.data -and $json.errors.Count -gt 0) 'error envelope' }
    return @{ Status = [int]$response.StatusCode; Json = $json; Headers = $response.Headers }
}
function Send($method, $url, $body = $null, $type = 'application/json') {
    return Request $method $url $body $type
}
$identity = 'API Verification ' + [guid]::NewGuid().ToString('N')
function Create($amount) { Send POST $base ('{"employeeName":" ' + $identity + ' ","amount":' + $amount + ',"category":" Transporte ","description":" Prueba SQL "}') }
foreach ($amount in @('499999','500000','500000.01','500001','9999999999999999.99','1.2300','1e2')) {
    $r = Create $amount
    Check ($r.Status -eq 201 -and $r.Headers.Location) "create $amount"
    $expected = if ([decimal]$amount -le 500000) { 'Approved' } else { 'Pending' }
    Check ($r.Json.data.status -eq $expected -and $r.Json.data.employeeName -eq $identity) "state/trim $amount"
    Check ($r.Json.data.createdAtUtc.Kind -eq [DateTimeKind]::Utc) 'UTC date'
    $read = Send GET "$base/$($r.Json.data.id)"
    Check ($read.Json.data.amount -eq [decimal]$amount) "SQL amount $amount"
    if ($amount -eq '500001') { $pendingId = $r.Json.data.id }
    if ($amount -eq '500000') { $approvedId = $r.Json.data.id }
}
foreach ($amount in @('0','-1','1.001','9999999999999999.999','10000000000000000','"abc"','null','1.000000000000000000000000000001','1e-100','1e100')) {
    $r = Create $amount
    Check ($r.Status -eq 400) "invalid amount $amount"
}
foreach ($body in @('{}','{"employeeName":" ","category":" ","description":" "}','{"','null','{"employeeName":4}')) {
    $r = Send POST $base $body
    Check ($r.Status -eq 400) "invalid body $body"
}
$r = Send POST $base (@{ employeeName = 'x' * 101; category = 'x' * 61; description = 'x' * 501; amount = 1 } | ConvertTo-Json)
Check ($r.Status -eq 400 -and $r.Json.errors.Count -eq 3) 'all long fields'
foreach ($path in @('?status=pending','?status=','?status=0','?status=1','?status=Unknown','/0','/abc')) { $r = Send GET "$base$path"; Check ($r.Status -eq 400) "bad filter/id $path" }
foreach ($url in @("$base/2147483647",'http://127.0.0.1:5000/api/missing')) { $r = Send GET $url; Check ($r.Status -eq 404) '404' }
$r = Send DELETE $base; Check ($r.Status -eq 405 -and $r.Json.errors[0].code -eq 'METHOD_NOT_ALLOWED') '405'
$r = Send POST $base 'test' 'text/plain'; Check ($r.Status -eq 415 -and $r.Json.errors[0].code -eq 'UNSUPPORTED_MEDIA_TYPE') '415'
$r = Send PATCH "$base/$approvedId/approve"; Check ($r.Status -eq 409) 'final conflict'
$r = Send PATCH "$base/$pendingId/reject" '{"reason":" "}'; Check ($r.Status -eq 400) 'blank reason'
$r = Send PATCH "$base/$pendingId/reject" '{"reason":" Motivo verificado "}'; Check ($r.Status -eq 200 -and $r.Json.data.rejectionReason -eq 'Motivo verificado' -and $r.Json.data.decidedAtUtc.Kind -eq [DateTimeKind]::Utc) 'reject'
$r = Send PATCH "$base/$pendingId/approve"; Check ($r.Status -eq 409) 'rejected conflict'
$filter = [uri]::EscapeDataString(" $identity ")
$r = Send GET "$base`?status=Rejected&employeeName=$filter"
Check ($r.Json.data.Count -eq 1 -and $r.Json.data[0].id -eq $pendingId) 'intersect filters'
$r = Send GET "$base`?employeeName=API%20Verification"; Check ($r.Json.data.Count -eq 0) 'complete name filter'
$created = Create '700000'
$raceId = $created.Json.data.id
$client = [System.Net.Http.HttpClient]::new()
$approve = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Patch, "$base/$raceId/approve")
$reject = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Patch, "$base/$raceId/reject")
$reject.Content = [System.Net.Http.StringContent]::new('{"reason":"Concurrent decision"}', [System.Text.Encoding]::UTF8, 'application/json')
$a = $client.SendAsync($approve)
$b = $client.SendAsync($reject)
$codes = @([int]$a.Result.StatusCode, [int]$b.Result.StatusCode) | Sort-Object
Check ($codes[0] -eq 200 -and $codes[1] -eq 409) 'concurrent decision single winner'
$client.Dispose()
Write-Output "TOTAL: $script:checks checks. Durability record: $raceId"

