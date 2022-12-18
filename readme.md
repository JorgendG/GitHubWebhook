# Webhook listener

Github offers a webhook whenever certain events happen, for example, whenever a repository is modified.
Great, but what is a webhook and why should I care?
Well, as far as I care it's a visit to site when the webhook fires. Just listen to the site and take action when it happens.

Example? Example:

I got a neat script which I use on some computers. As a good netcitizen I host the script on GitHub. Somewhere along the line the script is used on different servers. But I keep updating the script, bigger, better and faster. How do I ensure the script will also be updated on my servers?

Enter CreateWebhook.
It starts a http listener and perfoms actions when it receives the a request. The script which starts the http listener can run as a service using NSSM.

# Setup webhook

Add a webhook in the settings tab of a repository. For the time being, set content type to application/x-www-form-urlencoded.

![Image of a WebHook](/images/createwebhook.png)
I just use my public ipaddress and use portforwarding in my router.
![Image of a WebHook](/images/portforwarder.png)
**_ Do remember you're poking holes in your firewall. I got numerous hits, http request on this sorta random port_**

# Listener

The script has some optional parameters:

```powershell
param (
    [string]$portNumber = 1234,
    [string]$sourcerepo = 'https://github.com/JorgendG/BuildWDS/raw/master',
    [string]$destFolder = 'C:\Pullserver',
    [string]$updateaction = 'C:\Pullserver\MakeDSCConfig.ps1',
    [switch]$Install = $false,
    [string[]]$filestowatch = @("WebhookListener.ps1", "readme.md")
)
```

The $sourcerepo is a link to the repository. It is also somewhere part of the webhook data but I don't want to use that unless I'm 100% sure the request came from Github. Don't want to download files from a source solely based on a unverified http request.

The $updateaction parameter is the name of a powershell script which is executed after certain files have changed.

The current script has way too many hardcoded parameters. Fixed. Soon. Etc.

A minimal version looks like this

```powershell
Add-Type -AssemblyName System.Web

$portNumber = 1234
$HttpListener = New-Object System.Net.HttpListener
$HttpListener.Prefixes.Add('http://+:' + $portNumber + '/')

$HttpListener.Start()
While ($HttpListener.IsListening) {
    $HttpContext = $HttpListener.GetContext()
    $HttpRequest = $HttpContext.Request
    $RequestUrl = $HttpRequest.Url.OriginalString
    if ($HttpRequest.HasEntityBody) {
        $Reader = New-Object System.IO.StreamReader($HttpRequest.InputStream)
        $bla = $Reader.ReadToEnd()
        $decodedpayload = [System.Web.HttpUtility]::UrlDecode($bla)
        $whevent = $decodedpayload -replace "payload=", "["
        $whevent = $whevent + "]"

        $whevent = ConvertFrom-Json $whevent
        # $whevent | ConvertTo-Json -depth 100 | Out-File C:\location\whevent.json
        # uncomment to save the payload to a json file, vscode offers a nice way to inspect the content

        Write-Output "Files modified:"
        $whevent[0].head_commit.modified
        Write-Output "Files added:"
        $whevent[0].head_commit.added
    }
    $HttpResponse = $HttpContext.Response
    $HttpResponse.Headers.Add("Content-Type", "text/plain")
    $HttpResponse.StatusCode = 200
    $ResponseBuffer = [System.Text.Encoding]::UTF8.GetBytes("")
    $HttpResponse.ContentLength64 = $ResponseBuffer.Length
    $HttpResponse.OutputStream.Write($ResponseBuffer, 0, $ResponseBuffer.Length)
    $HttpResponse.Close()
    & "$updateaction"
}

$HttpListener.Stop()
```

It creates a httplistener on port $portnumber and prints the modified or added files in a push event.

This example will execute the $updateaction script on every hit. Not just a GitHub push event but also portscanners or other probes.

To check out the properties of a request, force a stop of the listener. If you run the fragment from an powershell console or ide, the interesting variables will still be present.

```powershell

```
