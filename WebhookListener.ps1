param (
    [string]$portNumber = 1234, 
    [string]$sourcerepo = 'https://github.com/JorgendG/GitHubWebhook/raw/master',    
    [string]$destFolder = 'C:\Pullserver',
    [string]$updateaction = 'C:\Pullserver\GitHubWebhook.ps1',
    [switch]$Install = $false
)
<#
    # Heb credentials nodig om logon voor service in te stellen
    $credpwd = Get-Content c:\Windows\Temp\credpwd.txt | ConvertTo-SecureString
    $usr = Get-Content c:\Windows\Temp\credusr.txt
    $credential = New-Object System.Management.Automation.PsCredential($usr, $credpwd)
    $usr
    $credential.Password

    $credential.Password | Out-File C:\pullserver\dinges.txt
#>

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

Add-Type -AssemblyName System.Web

$HttpListener = New-Object System.Net.HttpListener
$HttpListener.Prefixes.Add('http://+:' + $portNumber + '/')

$HttpListener.Start()
While ($HttpListener.IsListening) {
    $getMakeDSCConfigps1 = $false
    $getMakeDSCConfigpsd1 = $false

    $HttpContext = $HttpListener.GetContext()
    $HttpRequest = $HttpContext.Request
    $RequestUrl = $HttpRequest.Url.OriginalString
    Write-Output "$RequestUrl"
    if ($HttpRequest.HasEntityBody) {
        $Reader = New-Object System.IO.StreamReader($HttpRequest.InputStream)
        $bla = $Reader.ReadToEnd()
        $decodedpayload = [System.Web.HttpUtility]::UrlDecode($bla)
        $whevent = $decodedpayload -replace "payload=", "["
        $whevent = $whevent + "]"

        $whevent = ConvertFrom-Json $whevent

        Write-Output "Files modified:"
        $whevent[0].head_commit.modified
        if ( 'MakeDSCConfig.ps1' -in $whevent[0].head_commit.modified ) {
            $getMakeDSCConfigps1 = $true
        }
        if ( 'MakeDSCConfig.psd1' -in $whevent[0].head_commit.modified ) {
            $getMakeDSCConfigpsd1 = $true
        }
        Write-Output "Files added:"
        $whevent[0].head_commit.added
        
        #Write-Output $decodedpayload
    }
    $HttpResponse = $HttpContext.Response
    $HttpResponse.Headers.Add("Content-Type", "text/plain")
    $HttpResponse.StatusCode = 200
    $ResponseBuffer = [System.Text.Encoding]::UTF8.GetBytes("")
    $HttpResponse.ContentLength64 = $ResponseBuffer.Length
    $HttpResponse.OutputStream.Write($ResponseBuffer, 0, $ResponseBuffer.Length)
    $HttpResponse.Close()
    Write-Output "" # Newline
    #$HttpListener.Stop()
    if ( $getMakeDSCConfigps1 ) {
        Invoke-WebRequest -Uri "$sourcerepo/MakeDSCConfig.ps1" -OutFile "$destFolder\MakeDSCConfig.ps1"
    }
    if ( $getMakeDSCConfigpsd1 ) {
        Invoke-WebRequest -Uri "$sourcerepo/MakeDSCConfig.psd1" -OutFile "$destFolder\MakeDSCConfig.psd1"
    }
    # trap makeconfig af
    if ( (Test-Path C:\pullserver\HomelabConfig\credpwd.txt) -and (Test-Path C:\pullserver\HomelabConfig\credusr.txt) ) {
        if ( $getMakeDSCConfigps1 -or $getMakeDSCConfigpsd1 ) {
            Write-Output "Start MakeDSCConfig" $((get-date).ToLocalTime()).ToString("yyyy-MM-dd HHmmss")
            #& C:\Pullserver\MakeDSCConfig.ps1
            #& "$updateaction"
            Write-Output "Einde MakeDSCConfig" $((get-date).ToLocalTime()).ToString("yyyy-MM-dd HHmmss")
        }
    }
}
$HttpListener.Stop()
