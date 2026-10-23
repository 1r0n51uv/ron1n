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
