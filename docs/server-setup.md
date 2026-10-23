# Primo setup del mini PC

Dopo i passi 1-3, da root sul server (`su -`), il resto lo fa
[`scripts/bootstrap.sh`](../scripts/bootstrap.sh): pacchetti, Docker,
Tailscale, SSH, firewall, repo in `/opt/ron1n`, i `.env` degli stack
chiesti sul terminale (invio = default, password casuali) e avvio con
`./infra.sh up` (spec [SETUP](specs/server-setup.md)). Alla fine stampa gli
indirizzi dei servizi e dove stanno i `.env`.

```sh
curl -fsSL https://raw.githubusercontent.com/1r0n51uv/ron1n/main/scripts/bootstrap.sh | sh
```

Per usare i servizi dai client vedi [Accesso dai client](#accesso-dai-client).

Per tornare indietro, `sudo /opt/ron1n/scripts/cleanup.sh` chiede cosa
eliminare (stack, volumi, immagini, download, firewall, SSH, Tailscale,
repo) e lo toglie. Docker Engine resta.

I passi sotto sono la stessa cosa fatta a mano.

1. **BIOS:** aggiorna il firmware, attiva l'accensione automatica dopo un
   blackout (di solito "Restore on AC power loss") e disattiva il secure
   boot solo se l'installer lo richiede.
2. **Rete:** dal router assegna un IP fisso al mini PC.
3. **Debian 13:** installazione minimale, senza ambiente desktop, con il
   solo server SSH.
4. **SSH:** copia la tua chiave (`ssh-copy-id`) e in `/etc/ssh/sshd_config`
   imposta `PasswordAuthentication no` e `PermitRootLogin no`.
5. **Pacchetti base:** `sudo apt install -y git curl unattended-upgrades`
   e `sudo dpkg-reconfigure unattended-upgrades`.
6. **Docker:** installa Docker Engine dal repo ufficiale
   (docs.docker.com/engine/install/debian) e aggiungi il tuo utente al
   gruppo `docker`.
7. **Tailscale:** `curl -fsSL https://tailscale.com/install.sh | sh`, poi
   `sudo tailscale up --ssh`.
8. **Repo:** `sudo git clone https://github.com/1r0n51uv/ron1n /opt/ron1n`.
9. **Stack:** `cd /opt/ron1n && sudo ./infra.sh up` crea `.env`, reti e
   cartelle e avvia tutto; `sudo ./infra.sh down` spegne. Dettagli in
   [`infra/README.md`](../infra/README.md).

## Dati di Docker su `/srv`

Sul mini PC `/var` è di 12 GB e `/srv` di oltre 400: immagini, volumi e
cache di Docker vanno su `/srv` (SETUP-007). Con Docker 29 le immagini
stanno in `/var/lib/containerd`, non solo in `/var/lib/docker`, quindi si
spostano tutte e due e si rimontano al loro posto in bind. Su un server
nuovo lo fa il bootstrap; su uno già installato, a mano (gli stack si
fermano qualche minuto; `cp -a` perché su Debian minimale `rsync` non c'è). Un comando alla volta: se uno fallisce, fermati prima di avviare Docker.

```sh
docker builder prune -af
sudo systemctl stop docker docker.socket containerd
sudo cp -a /var/lib/docker /srv/docker
sudo cp -a /var/lib/containerd /srv/containerd
sudo mv /var/lib/docker /var/lib/docker.old
sudo mv /var/lib/containerd /var/lib/containerd.old
sudo mkdir /var/lib/docker /var/lib/containerd
echo '/srv/docker /var/lib/docker none bind,x-systemd.requires-mounts-for=/srv 0 0' | sudo tee -a /etc/fstab
echo '/srv/containerd /var/lib/containerd none bind,x-systemd.requires-mounts-for=/srv 0 0' | sudo tee -a /etc/fstab
sudo systemctl daemon-reload
sudo mount -a
findmnt /var/lib/docker /var/lib/containerd
sudo systemctl start containerd docker
cd /opt/ron1n && sudo ./infra.sh up
```

Riavvia una volta; se dopo il riavvio è tutto su,
`sudo rm -rf /var/lib/docker.old /var/lib/containerd.old`. Per tornare
indietro: togli le due righe da `/etc/fstab`, riavvia e rinomina le
cartelle `.old`.

## Dominio e certificati

I siti hanno certificati Let's Encrypt per `home.ron1n.space` e
`*.home.ron1n.space` (SETUP-008): validi su ogni client, app iOS comprese,
senza installare niente. Il dominio `ron1n.space` è registrato su Namecheap,
ma i DNS li gestisce Cloudflare, perché Caddy deve poter scrivere il record
TXT della verifica. Una volta sola:

1. **Cloudflare:** Add a site → `ron1n.space` → piano Free. Non servono
   record per `home.ron1n.space`: quei nomi li risolve solo la tailnet.
2. **Namecheap:** Domain List → `ron1n.space` → Nameservers → Custom DNS,
   con i due nameserver che indica Cloudflare. Di solito è attivo in meno di
   un'ora; Cloudflare manda una mail.
3. **Token:** su Cloudflare, My Profile → API Tokens → Create Token →
   template "Edit zone DNS", zona `ron1n.space`. Mettilo in
   `CF_API_TOKEN` di `infra/proxy/.env` (lo chiede anche il bootstrap) e
   rilancia `sudo ./infra.sh up proxy`. Caddy prende i certificati da solo
   e li rinnova.

Il dominio dei nomi privati sta in `DOMINIO` di `infra/proxy/.env`; lo
stack `dns` lo riprende da lì.

## Accesso dai client

I siti del server (`https://home.ron1n.space`,
`https://torrent.home.ron1n.space`…) si aprono dai dispositivi nella
tailnet.

**Nomi, nella [console Tailscale](https://login.tailscale.com/admin/dns)
(una volta):** DNS → Nameservers → Add nameserver → Custom, indirizzo =
IP Tailscale del server (`tailscale ip -4`, lo stampa anche il bootstrap),
attiva **Restrict to domain** e scrivi `home.ron1n.space`. Risponde lo
stack [`dns`](../infra/dns/README.md). Sui client deve essere attivo "Use
Tailscale DNS" (il default; su Linux `tailscale up --accept-dns`). Se
avevi lo split DNS su `ron1n.home`, toglilo.

**Certificati:** niente da fare. Se sul telefono c'è ancora il profilo
"Caddy Local Authority" dei nomi `ron1n.home`, si può togliere da
Impostazioni → Generali → VPN e gestione dispositivi.

**SSH:** il bootstrap attiva Tailscale SSH, quindi da qualsiasi client
SSH (anche Termius o Blink su iPhone) basta `ssh <utente>@ron1n`, senza
chiavi né password: autentica Tailscale.
