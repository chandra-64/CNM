$api = "http://localhost:4566/_aws/execute-api/your-api-id/local/books"

Clear-Host
Write-Host "Starting traffic simulator..."
[Console]::Out.Flush()

$titles = @("BookA", "BookB", "BookC", "BookD", "BookE")
$count = 1
$activeBookIds = @()

while ($true) {
    $randomIndex = Get-Random -Minimum 0 -Maximum 5
    $bookId = (Get-Random -Minimum 100 -Maximum 9999).ToString()
    $title = $titles[$randomIndex]

    # Force first 3 requests to be POST
    if ($count -le 3) {
        $diceRoll = 1
    }
    else {
        $diceRoll = Get-Random -Minimum 1 -Maximum 11
    }

    # 70% chance of POST, 30% chance of GET
    if ($diceRoll -le 7 -or $activeBookIds.Count -eq 0) {

        $body = @{
            book_id = $bookId
            title   = $title
            author  = "Author"
        } | ConvertTo-Json

        $res = Invoke-RestMethod `
            -Uri $api `
            -Method Post `
            -ContentType "application/json" `
            -Body $body `
            -ErrorAction SilentlyContinue

        if ($?) {
            $activeBookIds += $bookId
            Write-Host "POST Success: Added ID $bookId"
        }
        else {
            Write-Host "POST Failed"
        }
    }
    else {

        $randomSavedId = $activeBookIds | Get-Random
        $targetUrl = "$api/$randomSavedId"

        $res = Invoke-RestMethod `
            -Uri $targetUrl `
            -Method Get `
            -ErrorAction SilentlyContinue

        if ($?) {
            Write-Host "GET Success: Found ID $randomSavedId"
        }
        else {
            Write-Host "GET Failed for ID $randomSavedId"
        }
    }

    [Console]::Out.Flush()
    $count++

    # Wait 3 seconds before the next request
    Start-Sleep -Seconds 3
}