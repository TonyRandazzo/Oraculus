#!/usr/bin/env bash
# Installa il server del ramo remoto di Oraculus su una VM Ubuntu (pensato
# per Oracle Cloud "Always Free", Ampere A1). Da lanciare sulla VM, dentro
# questa cartella:
#
#   sudo ./install.sh                # host = <ip-pubblico>.sslip.io
#   sudo ./install.sh mio.dominio.it # se hai un dominio che punta alla VM
#
# Si puo' rilanciare: aggiorna script e servizio senza riscaricare il modello.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
	echo "Lancialo con sudo." >&2
	exit 1
fi
QUI="$(cd "$(dirname "$0")" && pwd)"
export DEBIAN_FRONTEND=noninteractive

# --- host pubblico --------------------------------------------------------
# sslip.io risolve 1-2-3-4.sslip.io in 1.2.3.4: un nome gratuito che punta
# alla VM, quanto basta a Let's Encrypt per rilasciare il certificato HTTPS
# (Godot su Web non puo' chiamare un http:// da una pagina https://).
HOST="${1:-}"
if [[ -z "$HOST" ]]; then
	IP="$(curl -fsS -4 https://ifconfig.me || curl -fsS -4 https://api.ipify.org)"
	HOST="${IP//./-}.sslip.io"
fi
echo "==> host pubblico: $HOST"

# --- pacchetti ------------------------------------------------------------
echo "==> pacchetti"
apt-get update -q
apt-get install -y -q python3 libgomp1 curl ca-certificates gnupg debian-keyring debian-archive-keyring \
	apt-transport-https iptables-persistent
if ! command -v caddy >/dev/null; then
	curl -1sLf https://dl.cloudsmith.io/public/caddy/stable/gpg.key \
		| gpg --dearmor --yes -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
	curl -1sLf https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt \
		> /etc/apt/sources.list.d/caddy-stable.list
	apt-get update -q
	apt-get install -y -q caddy
fi

# --- llama-server come servizio -------------------------------------------
echo "==> servizio oraculus-llm"
id oraculus >/dev/null 2>&1 || useradd --system --home /var/lib/oraculus-llm --shell /usr/sbin/nologin oraculus
install -d -o oraculus -g oraculus /var/lib/oraculus-llm
install -D -m 644 "$QUI/oraculus_llm.py" /opt/oraculus-llm/oraculus_llm.py
install -m 644 "$QUI/oraculus-llm.service" /etc/systemd/system/oraculus-llm.service
systemctl daemon-reload
systemctl enable oraculus-llm >/dev/null
systemctl restart oraculus-llm

# --- firewall della VM ----------------------------------------------------
# Le immagini Ubuntu di Oracle hanno regole iptables che rifiutano tutto
# tranne SSH: 80 (per il certificato) e 443 vanno aperte prima del REJECT.
# Serve ANCHE la regola nella Security List della VCN (vedi README).
echo "==> firewall"
for porta in 80 443; do
	if ! iptables -C INPUT -p tcp --dport "$porta" -m state --state NEW -j ACCEPT 2>/dev/null; then
		reject="$(iptables -L INPUT --line-numbers -n | awk '$2 == "REJECT" {print $1; exit}')"
		if [[ -n "$reject" ]]; then
			iptables -I INPUT "$reject" -p tcp --dport "$porta" -m state --state NEW -j ACCEPT
		else
			iptables -A INPUT -p tcp --dport "$porta" -m state --state NEW -j ACCEPT
		fi
	fi
done
netfilter-persistent save >/dev/null

# --- HTTPS ----------------------------------------------------------------
echo "==> Caddy"
sed "s/HOST_PUBBLICO/$HOST/" "$QUI/Caddyfile.template" > /etc/caddy/Caddyfile
systemctl enable caddy >/dev/null
systemctl restart caddy

# --- attesa ---------------------------------------------------------------
echo "==> attendo il modello (al primo avvio scarica ~1 GB)"
for _ in $(seq 300); do
	curl -fs http://127.0.0.1:7860/health >/dev/null && break
	sleep 3
done
if ! curl -fs http://127.0.0.1:7860/health >/dev/null; then
	echo "llama-server non risponde: journalctl -u oraculus-llm -n 50" >&2
	exit 1
fi
echo "==> llama-server pronto"

for _ in $(seq 40); do
	curl -fs "https://$HOST/health" >/dev/null && break
	sleep 3
done
if curl -fs "https://$HOST/health" >/dev/null; then
	echo
	echo "Fatto. URL per il gioco (DEFAULT_BASE_URL / ORACULUS_API_URL):"
	echo "  https://$HOST"
else
	echo "llama-server va, ma https://$HOST non risponde." >&2
	echo "Controlla la Security List della VCN (porte 80 e 443) e: journalctl -u caddy -n 50" >&2
	exit 1
fi
