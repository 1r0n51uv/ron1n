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

Prima di cominciare chiede cosa configurare, una voce alla volta
(SETUP-013): aggiornamenti automatici, Docker, gruppi dell'utente,
Tailscale, regole SSH, firewall, repo, `.env` e avvio degli stack. Senza
domande, con le opzioni (`--help` le elenca tutte):

```sh
# tutto tranne Tailscale e SSH
curl -fsSL https://raw.githubusercontent.com/1r0n51uv/ron1n/main/scripts/bootstrap.sh | sh -s -- --skip tailscale,ssh
# solo aggiornare il repo e riavviare gli stack
sudo sh /opt/ron1n/scripts/bootstrap.sh --only repo,stack
```

Su Debian in WSL Tailscale, SSH e firewall sono spenti di default; senza
systemd Docker parte con `service docker start` e Tailscale si salta.

Per usare i servizi dai client vedi [Accesso da fuori con Cloudflare](#accesso-da-fuori-con-cloudflare).

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
8. **Repo:** `sudo install -d -o "$USER" /opt/ron1n`, poi
   `git clone https://github.com/1r0n51uv/ron1n /opt/ron1n`: il repo è tuo e
   git non chiede sudo (SETUP-012).
9. **Stack:** `cd /opt/ron1n && ./infra.sh up` crea `.env`, reti e
   cartelle e avvia tutto; `./infra.sh down` spegne. Il tuo utente deve essere nel gruppo
   `docker` (vale dal login successivo). Dettagli in
   [`infra/README.md`](../infra/README.md).

## Repo senza sudo

Il repo `/opt/ron1n` è dell'utente amministratore (SETUP-012): `git pull`
e `./infra.sh` si lanciano senza sudo, e così anche Claude dal server può
applicare le PR e riavviare gli stack. Sudo resta per il sistema: apt,
systemctl, Tailscale, fstab. Su un server installato prima, una volta sola
(oppure rilancia il bootstrap):

```sh
sudo chown -R "$USER": /opt/ron1n
sudo git config --global --unset-all safe.directory || true
cd /opt/ron1n && git status && ./infra.sh status
```

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
cd /opt/ron1n && ./infra.sh up
```

Riavvia una volta; se dopo il riavvio è tutto su,
`sudo rm -rf /var/lib/docker.old /var/lib/containerd.old`. Per tornare
indietro: togli le due righe da `/etc/fstab`, riavvia e rinomina le
cartelle `.old`.

## Accesso da fuori con Cloudflare

I siti si aprono da ogni rete su `https://<nome>.ron1n.space`
(`home.ron1n.space` è la dashboard): li porta il Cloudflare Tunnel dello
stack [`tunnel`](../infra/tunnel/README.md) e li protegge Cloudflare Access
(SETUP-008). Niente VPN né certificati da installare. Il dominio è
registrato su Namecheap con i nameserver di Cloudflare. Tutto sul piano
gratuito.

**Con lo script** (SETUP-010), con il dominio già "Active":

1. In Zero Trust scegli un team name e il piano Free: va fatto una volta
   dalla dashboard, l'API non lo attiva.
2. **My Profile → API Tokens → Create Token → Custom token**, con solo
   questi permessi e una scadenza breve:
   - Account › Cloudflare Tunnel › Edit
   - Account › Access: Apps and Policies › Edit
   - Account › Access: Service Tokens › Edit
   - Zone › DNS › Edit, solo sulla zona del dominio
3. Sul server, in `~/.cf-home/.env` con permessi 600:

   ```sh
   CLOUDFLARE_API_TOKEN=...
   CLOUDFLARE_ACCOUNT_ID=...   # nella pagina Overview del dominio
   ACCESS_EMAIL=...            # chi entra dal browser
   ```

4. Lancia, prima in prova:

   ```sh
   cd /opt/ron1n
   scripts/cloudflare.sh --dry-run
   scripts/cloudflare.sh
   sudo sed -i "s|^TUNNEL_TOKEN=.*|TUNNEL_TOKEN=$(cat ~/.cf-home/tunnel-token)|" infra/tunnel/.env
   ./infra.sh up tunnel
   ```

5. Lo script apre anche, e solo, `ios.DOMINIO/sidestore`: la source di
   SideStore con le sue IPA (SETUP-011).
6. Le credenziali dell'app iOS sono in `~/.cf-home/ron1nos-ios.json`:
   copiale dal telefono, mai in una chat. Per cambiarle,
   `scripts/cloudflare.sh --ruota`. Alla fine cancella l'API token.

**A mano**, nella dashboard di Cloudflare:

1. **Tunnel:** Zero Trust → Networks → Tunnels → Create a tunnel →
   Cloudflared, nome `ron1n`. Nella pagina "Install connector" copia il
   token (la stringa dopo `--token`) in `TUNNEL_TOKEN` di
   `infra/tunnel/.env` e lancia `./infra.sh up tunnel`: il connettore
   diventa "Healthy".
2. **Hostname:** nel tunnel, Public Hostname → Add: sottodominio `*`,
   dominio `ron1n.space`, servizio `HTTP` `caddy:80`. Cloudflare crea da
   solo il record DNS wildcard. Il sito giusto per ogni nome lo sceglie
   Caddy.
3. **Access:** Zero Trust → Access → Applications → Add → Self-hosted,
   dominio `*.ron1n.space`, durata della sessione 1 mese. Policy "Allow"
   con Include → Emails → la tua email. In Settings → Authentication puoi
   aggiungere Google accanto al codice via mail (One-time PIN).
4. **Service token per l'app iOS:** Zero Trust → Access → Service
   Auth → Create service token, nome `ron1nos-ios`. Copia subito Client ID
   e Client Secret (il secret si vede una volta sola); nell'applicazione
   del punto 3 aggiungi una policy "Service Auth" con Include → Service
   Token → `ron1nos-ios`.

Dal browser, al primo accesso Access chiede il codice via mail (o Google)
e poi ricorda il dispositivo per un mese, per tutti i nomi. Il piano
gratuito accetta richieste fino a 100 MB.

**SSH:** il bootstrap attiva Tailscale SSH, quindi da qualsiasi client
SSH (anche Termius o Blink su iPhone) basta `ssh <utente>@ron1n`, senza
chiavi né password: autentica Tailscale.
Tailscale serve solo a questo: siti, API e app passano da Cloudflare.

**Da un server con lo stack `dns`** (SETUP-005, tolto con SETUP-009):
prima di aggiornare il repo spegnilo, poi togli la cartella rimasta con il
suo `.env` e, nella [console Tailscale](https://login.tailscale.com/admin/dns),
il nameserver custom per `ron1n.home` (**DNS → Nameservers**).

```sh
cd /opt/ron1n
./infra.sh down dns
git pull --ff-only
rm -rf infra/dns
```
