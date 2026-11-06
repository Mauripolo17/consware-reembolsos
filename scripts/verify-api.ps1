#requires -Version 7.5
[CmdletBinding()]
param(
    [string]$BaseUrl = 'http://localhost:5000',
    # Save outside the repository; run VerifyPersistence only after a coordinated restart.
    [string]$SnapshotPath = (Join-Path ([IO.Path]::GetTempPath()) 'consware-api-acceptance.json'),
    [switch]$VerifyPersistence
)
$ErrorActionPreference = 'Stop'
$BaseUrl = $BaseUrl.TrimEnd('/')
$script:passed = 0
$script:failed = 0
$script:records = [System.Collections.Generic.List[object]]::new()
$employee = 'Acceptance-' + [guid]::NewGuid().ToString('N')
$client = [System.Net.Http.HttpClient]::new()
$client.Timeout = [TimeSpan]::FromSeconds(15)

function Read-Json([string]$Text) {
    # PowerShell 7.5+ otherwise converts ISO strings into DateTime values.
    $options = @{ InputObject=$Text; Depth=30 }
    if ((Get-Command ConvertFrom-Json).Parameters.ContainsKey('DateKind')) { $options.DateKind='String' }
    $value = ConvertFrom-Json @options
    # ConvertFrom-Json decodes fractional numbers as Double; preserve decimal(18,2).
    $document = [System.Text.Json.JsonDocument]::Parse($Text)
    try {
        foreach ($property in @('data','records')) {
            $node = [System.Text.Json.JsonElement]::new()
            if ($document.RootElement.ValueKind -eq 'Object' -and $document.RootElement.TryGetProperty($property, [ref]$node)) {
                $nodes = @(if ($node.ValueKind -eq 'Array') { $node.EnumerateArray() } else { $node })
                $items = @($value.$property)
                for ($i=0; $i -lt $nodes.Count; $i++) {
                    $amountNode = [System.Text.Json.JsonElement]::new()
                    if ($nodes[$i].ValueKind -eq 'Object' -and $nodes[$i].TryGetProperty('amount', [ref]$amountNode)) {
                        $items[$i].amount = $amountNode.GetDecimal()
                    }
                }
            }
        }
    } finally { $document.Dispose() }
    return $value
}

function Assert-True($Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Test-Case([string]$Name, [scriptblock]$Action) {
    try { & $Action; $script:passed++; Write-Host "PASS $Name" }
    catch { $script:failed++; Write-Host "FAIL ${Name}: $($_.Exception.Message)" -ForegroundColor Red }
}
function Send-Request([string]$Method, [string]$Path, $Body = $null, [string]$MediaType = 'application/json', [switch]$Raw) {
    $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::new($Method), "$BaseUrl$Path")
    if ($null -ne $Body) {
        $json = if ($Raw) { [string]$Body } else { ConvertTo-Json -InputObject $Body -Depth 10 -Compress }
        $request.Content = [System.Net.Http.StringContent]::new($json, [Text.Encoding]::UTF8, $MediaType)
    }
    try {
        $response = $client.SendAsync($request).GetAwaiter().GetResult()
        try {
            $text = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
            try { $bodyObject = Read-Json $text } catch { throw "Non-JSON HTTP $([int]$response.StatusCode): $text" }
            return @{ Status = [int]$response.StatusCode; Body = $bodyObject; Location = [string]$response.Headers.Location }
        } finally { $response.Dispose() }
    } finally { $request.Dispose() }
}
function Assert-Response($Response, [int]$Status, [string]$Code = '', [string]$Field = '') {
    Assert-True ($Response.Status -eq $Status) "Expected HTTP $Status, got $($Response.Status)"
    $b = $Response.Body
    Assert-True ((@($b.PSObject.Properties.Name | Sort-Object) -join ',') -ceq 'data,errors,message,success,traceId') 'Envelope keys differ'
    Assert-True ($b.success -is [bool]) 'success must be boolean'
    Assert-True ($b.message -is [string] -and -not [string]::IsNullOrWhiteSpace($b.message)) 'Missing summary'
    Assert-True ($b.traceId -is [string] -and -not [string]::IsNullOrWhiteSpace($b.traceId)) 'Missing traceId'
    Assert-True ($b.errors -is [array]) 'errors must be an array'
    # A language heuristic catches framework English; actual wording still needs human review.
    Assert-True ($b.message -notmatch '(?i)^(the |an error|one or more|unsupported|not found|method not)') 'English framework summary'
    if ($Status -lt 400) {
        Assert-True ($b.success -and $null -ne $b.data -and $b.errors.Count -eq 0) 'Invalid success envelope'
    } else {
        Assert-True (-not $b.success -and $null -eq $b.data -and $b.errors.Count -gt 0) 'Invalid error envelope'
        foreach ($e in $b.errors) {
            Assert-True ((@($e.PSObject.Properties.Name | Sort-Object) -join ',') -ceq 'code,field,message') 'Error keys differ'
            Assert-True ($e.code -cmatch '^[A-Z_]+$') 'Invalid error code'
            Assert-True ($null -eq $e.field -or $e.field -cmatch '^[a-z][a-zA-Z0-9]*$') 'Invalid field name'
            Assert-True (-not [string]::IsNullOrWhiteSpace($e.message)) 'Missing error message'
            Assert-True ($e.message -notmatch '(?i)^(the |a value|an error|one or more|unsupported|not found)') 'English error message'
            Assert-True ($e.message -notmatch '(?i)SqlException|stack trace|Microsoft\.| at System\.') 'Internal details exposed'
        }
        if ($Code) { Assert-True (@($b.errors | Where-Object { $_.code -ceq $Code -and (-not $Field -or $_.field -ceq $Field) }).Count -gt 0) "Missing $Code error for $Field" }
    }
}
function New-Payload($Amount = 500001) {
    return @{ employeeName = $employee; amount = $Amount; category = 'Transporte'; description = 'Prueba de aceptación persistente' }
}
function New-Record($Amount = 500001, [hashtable]$Payload = $null) {
    if ($null -eq $Payload) { $Payload = New-Payload $Amount }
    $r = Send-Request POST '/api/reimbursements' $Payload
    Assert-Response $r 201
    Assert-True ($r.Location -match "/api/reimbursements/$($r.Body.data.id)$") 'Missing/incorrect Location'
    Assert-Record $r.Body.data
    return $r.Body.data
}
function Assert-Record($Item) {
    Assert-True ((@($Item.PSObject.Properties.Name | Sort-Object) -join ',') -ceq 'amount,category,createdAtUtc,decidedAtUtc,description,employeeName,id,rejectionReason,status') 'Record keys differ'
    Assert-True ($Item.id -gt 0 -and $Item.amount -gt 0) 'Invalid identity/amount'
    Assert-True ($Item.status -cin @('Pending','Approved','Rejected')) 'Invalid status'
    Assert-True ($Item.createdAtUtc -match 'Z$') 'Creation must be UTC Z'
    if ($Item.status -ceq 'Pending') { Assert-True ($null -eq $Item.decidedAtUtc -and $null -eq $Item.rejectionReason) 'Pending has decision data' }
    else { Assert-True ($Item.decidedAtUtc -match 'Z$') 'Decision must be UTC Z' }
    if ($Item.status -ceq 'Rejected') { Assert-True (-not [string]::IsNullOrWhiteSpace($Item.rejectionReason)) 'Missing rejection reason' }
    else { Assert-True ($null -eq $Item.rejectionReason) 'Unexpected rejection reason' }
}
function Save-Record($Item) { $script:records.Add($Item) }
function Assert-Unchanged($Expected) {
    $r = Send-Request GET "/api/reimbursements/$($Expected.id)"
    Assert-Response $r 200
    Assert-Record $r.Body.data
    foreach ($property in $Expected.PSObject.Properties) {
        $actual = $r.Body.data.($property.Name)
        $equal = if ($property.Name -eq 'amount') { [decimal]$actual -eq [decimal]$property.Value } else { $actual -ceq $property.Value }
        Assert-True $equal "Record $($Expected.id) field $($property.Name) changed"
    }
}

try {
    if ($VerifyPersistence) {
        $saved = Read-Json (Get-Content -LiteralPath $SnapshotPath -Raw)
        Assert-True (@($saved.records).Count -gt 0) 'Snapshot contains no records'
        Assert-True ($saved.baseUrl -eq $BaseUrl) 'Snapshot belongs to another API'
        foreach ($item in $saved.records) { Test-Case "durability id=$($item.id)" { Assert-Unchanged $item } }
    } else {
        Write-Host "Employee: $employee"
        # A failed readiness probe exits before attempting mutations.
        $ready = Send-Request GET '/api/reimbursements'
        Assert-Response $ready 200
        Test-Case 'list array and ordering' {
            Assert-True ($ready.Body.data -is [array]) 'List must be array'
            $items = @($ready.Body.data)
            foreach ($item in $items) { Assert-Record $item }
            for ($i = 1; $i -lt $items.Count; $i++) {
                $previous = [DateTimeOffset]::Parse($items[$i-1].createdAtUtc)
                $current = [DateTimeOffset]::Parse($items[$i].createdAtUtc)
                Assert-True ($previous -gt $current -or ($previous -eq $current -and $items[$i-1].id -gt $items[$i].id)) 'List ordering incorrect'
            }
        }
        foreach ($amount in @(499999,500000,500000.01,500001,0.01,9999999999999999.99d)) {
            Test-Case "amount $amount" {
                $item = New-Record $amount
                Assert-True ($item.amount -eq $amount) 'Amount changed'
                $expected = if ($amount -le 500000) { 'Approved' } else { 'Pending' }
                Assert-True ($item.status -ceq $expected) 'Wrong automatic status'
                if ($expected -eq 'Approved') { Assert-True ($item.createdAtUtc -ceq $item.decidedAtUtc) 'Automatic approval dates differ' }
                Save-Record $item
            }
        }
        $invalidAmounts = @(
            @{ value=0; code='POSITIVE_AMOUNT_REQUIRED' }, @{ value=-1; code='POSITIVE_AMOUNT_REQUIRED' },
            @{ value=1.001; code='INVALID_AMOUNT_PRECISION' }, @{ value=10000000000000000d; code='AMOUNT_OUT_OF_RANGE' },
            @{ value=$null; code='REQUIRED' }, @{ value='invalid'; code='INVALID_REQUEST' }
        )
        foreach ($case in $invalidAmounts) {
            Test-Case "invalid amount $($case.value)" { $p = New-Payload; $p.amount = $case.value; Assert-Response (Send-Request POST '/api/reimbursements' $p) 400 $case.code }
        }
        Test-Case 'omitted amount' { $p=New-Payload; $p.Remove('amount'); Assert-Response (Send-Request POST '/api/reimbursements' $p) 400 'REQUIRED' 'amount' }
        foreach ($field in @('employeeName','category','description')) {
            $limit = @{ employeeName=100; category=60; description=500 }[$field]
            foreach ($value in @('', '   ', $null, ('x' * ($limit+1)))) {
                Test-Case "invalid $field length $([string]$value.Length)" {
                    $p=New-Payload; $p[$field]=$value
                    $code=if ([string]::IsNullOrWhiteSpace($value)) { 'REQUIRED' } else { 'MAX_LENGTH_EXCEEDED' }
                    Assert-Response (Send-Request POST '/api/reimbursements' $p) 400 $code $field
                }
            }
            Test-Case "omitted $field" { $p=New-Payload; $p.Remove($field); Assert-Response (Send-Request POST '/api/reimbursements' $p) 400 'REQUIRED' $field }
        }
        Test-Case 'trim and maximum text lengths' {
            $p=New-Payload; $p.employeeName=' ' + ('E'*100) + ' '; $p.category=' ' + ('C'*60) + ' '; $p.description=' ' + ('D'*500) + ' '
            $item=New-Record -Payload $p
            Assert-True ($item.employeeName.Length -eq 100 -and $item.category.Length -eq 60 -and $item.description.Length -eq 500) 'Text not trimmed'
            Save-Record $item
        }
        Test-Case 'aggregate required fields' {
            $r=Send-Request POST '/api/reimbursements' @{}
            Assert-Response $r 400
            foreach ($field in @('employeeName','amount','category','description')) { Assert-True (@($r.Body.errors | Where-Object field -CEQ $field).Count -gt 0) "Missing validation for $field" }
        }
        Test-Case 'meaningless trailing decimal zeros' { $p=New-Payload 1; $raw=($p|ConvertTo-Json -Compress) -replace '"amount":1', '"amount":1.000'; $r=Send-Request POST '/api/reimbursements' $raw -Raw; Assert-Response $r 201; Save-Record $r.Body.data }
        foreach ($raw in @('{', '', 'null', '[]')) {
            Test-Case "invalid JSON/body [$raw]" { Assert-Response (Send-Request POST '/api/reimbursements' $raw -Raw) 400 }
        }
        Test-Case 'malformed JSON code' { Assert-Response (Send-Request POST '/api/reimbursements' '{' -Raw) 400 'INVALID_JSON' }
        foreach ($status in @('invalid','pending','1')) {
            Test-Case "invalid status $status" { Assert-Response (Send-Request GET "/api/reimbursements?status=$status") 400 'INVALID_STATUS' }
        }
        Test-Case 'missing record' { Assert-Response (Send-Request GET '/api/reimbursements/2147483647') 404 'NOT_FOUND' }
        Test-Case 'missing record decisions' {
            Assert-Response (Send-Request PATCH '/api/reimbursements/2147483647/approve') 404 'NOT_FOUND'
            Assert-Response (Send-Request PATCH '/api/reimbursements/2147483647/reject' @{reason='No existe'}) 404 'NOT_FOUND'
        }
        Test-Case 'invalid ID' { Assert-Response (Send-Request GET '/api/reimbursements/0') 400 'INVALID_ID' }
        Test-Case 'unknown API route' { Assert-Response (Send-Request GET '/api/acceptance-missing') 404 'NOT_FOUND' }
        Test-Case 'unsupported method' { Assert-Response (Send-Request PUT '/api/reimbursements' @{}) 405 'METHOD_NOT_ALLOWED' }
        Test-Case 'unsupported media type' { Assert-Response (Send-Request POST '/api/reimbursements' 'test' 'text/plain' -Raw) 415 'UNSUPPORTED_MEDIA_TYPE' }
        Test-Case 'intersected and complete employee filters' {
            $encoded=[uri]::EscapeDataString(" $employee ")
            foreach ($status in @('Pending','Approved','Rejected')) {
                $r=Send-Request GET "/api/reimbursements?employeeName=$encoded&status=$status"
                Assert-Response $r 200
                Assert-True ($r.Body.data -is [array]) 'Filtered list must be array'
                foreach ($item in $r.Body.data) { Assert-True ($item.employeeName -ceq $employee -and $item.status -ceq $status) 'Filters not intersected' }
                $expected=@($script:records | Where-Object { $_.employeeName -ceq $employee -and $_.status -ceq $status })
                Assert-True ($r.Body.data.Count -eq $expected.Count) 'Filter omitted records'
            }
            $r=Send-Request GET ('/api/reimbursements?employeeName=' + [uri]::EscapeDataString($employee.Substring(0,$employee.Length-1)))
            Assert-Response $r 200; Assert-True ($r.Body.data.Count -eq 0) 'Employee substring matched'
        }
        Test-Case 'reject validation and final state preservation' {
            $item=New-Record
            foreach ($p in @(@{}, @{reason=$null}, @{reason=''}, @{reason='   '}, @{reason=('x'*501)})) {
                $code=if ($p.reason -and $p.reason.Length -gt 500) { 'MAX_LENGTH_EXCEEDED' } else { 'REQUIRED' }
                Assert-Response (Send-Request PATCH "/api/reimbursements/$($item.id)/reject" $p) 400 $code 'reason'
                Assert-Unchanged $item
            }
            $r=Send-Request PATCH "/api/reimbursements/$($item.id)/reject" @{reason=(' ' + ('R'*500) + ' ')}
            Assert-Response $r 200; Assert-Record $r.Body.data
            Assert-True ($r.Body.data.status -ceq 'Rejected' -and $r.Body.data.rejectionReason -ceq ('R'*500)) 'Wrong rejection'
            $final=$r.Body.data
            Assert-Response (Send-Request PATCH "/api/reimbursements/$($item.id)/approve") 409 'STATE_CONFLICT'
            Assert-Response (Send-Request PATCH "/api/reimbursements/$($item.id)/reject" @{reason='Otro motivo'}) 409 'STATE_CONFLICT'
            Assert-Unchanged $final; Save-Record $final
        }
        Test-Case 'approve and immutable final state' {
            $item=New-Record
            $r=Send-Request PATCH "/api/reimbursements/$($item.id)/approve"
            Assert-Response $r 200; Assert-Record $r.Body.data
            Assert-True ($r.Body.data.status -ceq 'Approved') 'Approval failed'
            $final=$r.Body.data
            Assert-Response (Send-Request PATCH "/api/reimbursements/$($item.id)/approve") 409 'STATE_CONFLICT'
            Assert-Response (Send-Request PATCH "/api/reimbursements/$($item.id)/reject" @{reason='No procede'}) 409 'STATE_CONFLICT'
            Assert-Unchanged $final; Save-Record $final
            $automatic=New-Record 500000
            Assert-Response (Send-Request PATCH "/api/reimbursements/$($automatic.id)/reject" @{reason='No procede'}) 409 'STATE_CONFLICT'
            Assert-Unchanged $automatic; Save-Record $automatic
        }
        Test-Case 'simultaneous approval/rejection exactly one winner' {
            $item=New-Record
            $approve=[Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::Patch,"$BaseUrl/api/reimbursements/$($item.id)/approve")
            $reject=[Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::Patch,"$BaseUrl/api/reimbursements/$($item.id)/reject")
            $reject.Content=[Net.Http.StringContent]::new('{"reason":"Decisión concurrente"}',[Text.Encoding]::UTF8,'application/json')
            try {
                $a=$client.SendAsync($approve); $b=$client.SendAsync($reject)
                $responses=@($a.GetAwaiter().GetResult(),$b.GetAwaiter().GetResult())
                try {
                    $results=@(foreach ($response in $responses) { @{Status=[int]$response.StatusCode; Body=(Read-Json ($response.Content.ReadAsStringAsync().GetAwaiter().GetResult()))} })
                    Assert-True ((@($results.Status | Sort-Object) -join ',') -eq '200,409') 'Race must return exactly 200 and 409'
                    foreach ($result in $results) { if ($result.Status -eq 200) { Assert-Response $result 200; $winner=$result.Body.data; Assert-Record $winner } else { Assert-Response $result 409 'STATE_CONFLICT' } }
                    Assert-Unchanged $winner; Save-Record $winner
                } finally { foreach ($response in $responses) { $response.Dispose() } }
            } finally { $approve.Dispose(); $reject.Dispose() }
        }
        @{ baseUrl=$BaseUrl; employeeName=$employee; capturedAtUtc=[DateTime]::UtcNow.ToString('o'); records=@($script:records.ToArray()) } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $SnapshotPath -Encoding utf8
        Write-Host "Persistence snapshot: $SnapshotPath (restart NOT performed)"
    }
} catch { $script:failed++; Write-Host "FAIL prerequisite: $($_.Exception.Message)" -ForegroundColor Red }
finally { $client.Dispose() }
Write-Host "Results: $script:passed passed; $script:failed failed"
if ($script:failed -gt 0) { exit 1 }
exit 0
