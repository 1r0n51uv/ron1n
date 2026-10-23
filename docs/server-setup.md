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
fermano qualche minuto e ripartono da soli):

```sh
docker builder prune -af
sudo systemctl stop docker docker.socket containerd
sudo rsync -aHAX /var/lib/docker/ /srv/docker/
sudo rsync -aHAX /var/lib/containerd/ /srv/containerd/
sudo mv /var/lib/docker /var/lib/docker.old
sudo mv /var/lib/containerd /var/lib/containerd.old
sudo mkdir /var/lib/docker /var/lib/containerd
echo '/srv/docker /var/lib/docker none bind,x-systemd.requires-mounts-for=/srv 0 0' | sudo tee -a /etc/fstab
echo '/srv/containerd /var/lib/containerd none bind,x-systemd.requires-mounts-for=/srv 0 0' | sudo tee -a /etc/fstab
sudo systemctl daemon-reload && sudo mount -a
findmnt /var/lib/docker /var/lib/containerd
sudo systemctl start containerd docker
cd /opt/ron1n && sudo ./infra.sh status
```

Riavvia una volta; se dopo il riavvio è tutto su,
`sudo rm -rf /var/lib/docker.old /var/lib/containerd.old`. Per tornare
indietro: togli le due righe da `/etc/fstab`, riavvia e rinomina le
cartelle `.old`.

## Accesso dai client

I siti del server (`https://ron1n.home`, `https://torrent.ron1n.home`…)
si aprono dai dispositivi nella tailnet. Una volta per tutta la tailnet,
poi una volta per dispositivo.

**Nomi, nella [console Tailscale](https://login.tailscale.com/admin/dns)
(una volta):** DNS → Nameservers → Add nameserver → Custom, indirizzo =
IP Tailscale del server (`tailscale ip -4`, lo stampa anche il bootstrap),
attiva **Restrict to domain** e scrivi `ron1n.home`. Risponde lo stack
[`dns`](../infra/dns/README.md). Sui client deve essere attivo "Use
Tailscale DNS" (il default; su Linux `tailscale up --accept-dns`).

**Certificato, su ogni dispositivo:** Caddy firma i siti con una sua CA,
che va installata come attendibile. Da un dispositivo nella tailnet apri
`http://ca.ron1n.home` (in HTTP: l'HTTPS diventa valido dopo). Se il
browser passa da solo a https, accetta l'avviso sul certificato: la pagina
c'è anche lì.

- **iPhone/iPad:** apri il link in Safari (all'avviso "connessione non
  privata": Mostra dettagli → Visita questo sito web) e consenti il
  download del profilo. Impostazioni → Profilo scaricato → Installa. Poi Impostazioni →
  Generali → Info → Impostazioni certificati attendibili e attiva la
  fiducia completa per "Caddy Local Authority".
- **macOS:** apri il file scaricato, finisce in Accesso Portachiavi; doppio
  clic sul certificato → Fidati → Quando usi questo certificato: Fidati
  sempre.
- **Windows:** doppio clic sul file → Installa certificato → Computer
  locale → Autorità di certificazione radice attendibili.

Se lo stack proxy riparte da volumi nuovi la CA cambia: va reinstallata.

**SSH:** il bootstrap attiva Tailscale SSH, quindi da qualsiasi client
SSH (anche Termius o Blink su iPhone) basta `ssh <utente>@ron1n`, senza
chiavi né password: autentica Tailscale.
