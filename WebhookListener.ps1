param (
    [string]$portNumber = 1234, 
    [string]$sourcerepo = 'https://github.com/JorgendG/GitHubWebhook/raw/master',    
    [string]$destFolder = 'C:\Pullserver',
    [string]$updateaction = 'C:\Pullserver\GitHubWebhook.ps1',
    [switch]$Install = $false,
    [string[]]$filestowatch = @("WebhookListener.ps1", "readme.md")
)

function Install-WebhookService {
    param (
        $serviceName = 'GitHubWebHook',
        $nssm = 'c:\pullserver\nssm.exe'
    )
    $ghwbservice = Get-Service $serviceName -ErrorAction SilentlyContinue
    if ( $null -eq $ghwbservice ) {
        $powershell = (Get-Command powershell).Source
        $scriptPath = 'C:\pullserver\githubseintje.ps1'
        $arguments = '-ExecutionPolicy Bypass -NoProfile -File "{0}"' -f $scriptPath
        & $nssm install $serviceName $powershell $arguments
        & $nssm status $serviceName
        Start-Service $serviceName
        Get-Service $serviceName
    }
}

Start-Transcript c:\pullserver\GitHubWebHooktransscipt.txt -Append
Add-Type -AssemblyName System.Web

$HttpListener = New-Object System.Net.HttpListener
$HttpListener.Prefixes.Add('http://+:' + $portNumber + '/')

$HttpListener.Start()
While ($HttpListener.IsListening) {

    $HttpContext = $HttpListener.GetContext()
    $HttpRequest = $HttpContext.Request
    $RequestUrl = $HttpRequest.Url.OriginalString
    Write-Output "RequestUrl      : $RequestUrl"
    Write-Output "X-Forwarded-For : $($HttpRequest.Headers['X-Forwarded-For'])"
    Write-Output "UserAgent       : $($HttpRequest.Headers['UserAgent'])"
    if ($HttpRequest.HasEntityBody) {
        $Reader = New-Object System.IO.StreamReader($HttpRequest.InputStream)
        $bla = $Reader.ReadToEnd()
        $decodedpayload = [System.Web.HttpUtility]::UrlDecode($bla)
        $whevent = $decodedpayload -replace "payload=", "["
        $whevent = $whevent + "]"

        $whevent = ConvertFrom-Json $whevent
        # $whevent | ConvertTo-Json -depth 100 | Out-File C:\location\whevent.json
        # uncomment to save the eventdata to a json file, vscode offers a nice way to inspect the content

        Write-Output "Files modified:"
        $whevent[0].head_commit.modified
       
        Write-Output "Files added:"
        $whevent[0].head_commit.added
        $filemodified = $false
        foreach ( $filename in $filestowatch) {
            if ( $filename -in $whevent[0].head_commit.modified ) {
                Write-Output "DateTime      : $($((get-date).ToLocalTime()).ToString('yyyy-MM-dd HHmmss'))"
                Write-Output "Download file : $sourcerepo/$filename $((get-date).ToLocalTime()).ToString("yyyy-MM-dd HHmmss"))"
                Invoke-WebRequest -Uri "$sourcerepo/$filename" -OutFile "$destFolder\$filename"
                $filemodified = $true
            }
        }
    }
    $HttpResponse = $HttpContext.Response
    $HttpResponse.Headers.Add("Content-Type", "text/plain")
    $HttpResponse.StatusCode = 200
    $ResponseBuffer = [System.Text.Encoding]::UTF8.GetBytes("")
    $HttpResponse.ContentLength64 = $ResponseBuffer.Length
    $HttpResponse.OutputStream.Write($ResponseBuffer, 0, $ResponseBuffer.Length)
    $HttpResponse.Close()
    Write-Output " " # Newline
    
    if ($filemodified) {
        # execute updateaction
        Write-Output "Start updateaction" $((get-date).ToLocalTime()).ToString("yyyy-MM-dd HHmmss")
        # & "$updateaction"
        Write-Output "Ended updateaction" $((get-date).ToLocalTime()).ToString("yyyy-MM-dd HHmmss")
    }
    if ( ($HttpRequest.Headers['X-Forwarded-For'] -eq '192.168.1.186') -and ($RequestUrl -eq 'http://192.168.1.76:1234/stop') ) {
        $HttpListener.Stop()
    }
    # $HttpListener.Stop()
    # uncomment in case you want to inspect varianbles
}
$HttpListener.Stop()
