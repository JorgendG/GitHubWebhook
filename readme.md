# Webhook listener

Github offers a webhook whenever certain events happen, for example, whenever a repository is modified.
Great, but what is a webhook and why should I care?
Well, as far as I care it's a visit to site when the webhook fires. Just listen to the site and take action when it happens.
Example? Example:
I got a neat script which I use on some computers. As a good netcitizen I host the script on GitHub. Somewhere along the line the script is used on different servers. But I keep updating the script, bigger, better and faster. How do I ensure the script will also be updated on my servers?

Enter CreateWebhook.
It starts a http listener and perfoms actions when it receives the a request. The script which starts the http listener can run as a service using NSSM.

# Setup webhook

Add a webhook in the settings tab of a repository.
![Image of a WebHook](/images/createwebhook.png)
I just use my public ipaddress and use portforwarding in my router.

# Listener

Run the script and wait for a request.
