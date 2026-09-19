patches
https://github.com/ivoronin/openbsd-port-cloudflared

doas patch -p0 < /usr/ports/mystuff/net/cloudflared/patches/patch-diagnostic_network_collector_unix_go

gitub release
https://github.com/cloudflare/cloudflared/archive/refs/tags/2026.7.0.tar.gz

doas install -m 755 cloudflared /usr/local/bin/cloudflared

change nameserver in namecheap

Update your origin server's firewall (usually via your web hosting provider or server console) to block all incoming traffic that doesn't originate from Cloudflare.
https://dash.cloudflare.com/30534f302a75cc4f0312b875dedd1e48/jfin.net/nameserver-directions

cloudflared tunnel login

cloudflared tunnel create jfin.net

cloudflared tunnel route dns jfin.net jfin.net

persistent on obsd
/etc/rc.d/cloudflared
doas chmod +x /etc/rc.d/cloudflared
doas rcctl enable cloudflared
doas rcctl start cloudflared

cloudflare edge certificates:
Always Use HTTPS

