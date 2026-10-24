# Server del ramo remoto (Oracle Cloud Always Free)

`llama-server` (llama.cpp) con `Llama-3.2-1B-Instruct-Q6_K_L.gguf` su una VM
ARM gratuita di Oracle, dietro Caddy in HTTPS. Nessuna API di inferenza di
terzi, nessun token, nessun credito.

| File | Ruolo |
| --- | --- |
| `oraculus_llm.py` | Scarica `llama-server` (arm64 o x64) e il `.gguf`, poi lo avvia su `127.0.0.1:7860`. |
| `oraculus-llm.service` | Servizio systemd: parte all'avvio della VM, si riavvia se cade. |
| `Caddyfile.template` | HTTPS con certificato Let's Encrypt automatico, streaming senza buffer. |
| `install.sh` | Installa tutto, apre il firewall della VM, stampa l'URL per il gioco. |

## 1. Account

1. Registrati su <https://www.oracle.com/cloud/free/> ("Start for free").
2. **Home region**: non si cambia piu', e le risorse gratuite esistono solo
   li'. Scegline una vicina ai giocatori (es. Milan, Frankfurt, Paris,
   Madrid); se poi la VM non si crea per mancanza di capacita', e' quasi
   sempre colpa della region.
3. La carta serve solo alla verifica d'identita' (un'autorizzazione
   temporanea, poi stornata). Resta sul piano **Free Tier**: senza passare a
   "Pay As You Go" Oracle non puo' addebitare nulla.

## 2. Chiave SSH (sul tuo PC)

```
ssh-keygen -t ed25519 -f ~/.ssh/oracle_oraculus
```

## 3. La VM

Menu ☰ → **Compute → Instances → Create instance**:

- **Name**: `oraculus-llm`
- **Image**: *Canonical Ubuntu 24.04* (Change image → Ubuntu)
- **Shape**: Change shape → **Ampere** → `VM.Standard.A1.Flex`,
  **2 OCPU, 12 GB** (deve comparire l'etichetta *Always Free-eligible*)
- **Networking**: crea una nuova VCN con subnet **pubblica**, e lascia
  attivo *Assign a public IPv4 address*
- **Add SSH keys**: *Paste public key* → il contenuto di
  `~/.ssh/oracle_oraculus.pub`
- **Boot volume**: lascia il default (50 GB, gratuito fino a 200 GB)

Se compare **"Out of host capacity"**: riprova piu' tardi, o cambia
*Availability domain* nella stessa schermata. E' frequente con le Ampere
gratuite; a volte servono alcuni tentativi in orari diversi.

Annota l'**IP pubblico** dalla pagina dell'istanza.

## 4. Porte 80 e 443 nella rete Oracle

Dalla pagina dell'istanza: **Subnet** → **Security Lists** →
*Default Security List* → **Add Ingress Rules**:

- Source CIDR `0.0.0.0/0`, IP Protocol **TCP**, Destination Port Range
  **`80,443`**

(La 80 serve solo a Let's Encrypt per rilasciare il certificato.)
Il firewall *dentro* la VM lo apre `install.sh`.

## 5. Installazione

Dalla cartella del progetto, sul tuo PC:

```
scp -i ~/.ssh/oracle_oraculus -r server ubuntu@<IP>:~/
ssh -i ~/.ssh/oracle_oraculus ubuntu@<IP>
cd server && sudo ./install.sh
```

Al primo avvio scarica ~1 GB, poi stampa l'URL da dare al gioco, del tipo
`https://1-2-3-4.sslip.io` ([sslip.io](https://sslip.io) e' un nome gratuito
che punta al tuo IP: serve per avere un certificato HTTPS senza comprare un
dominio). Se hai un dominio tuo: `sudo ./install.sh oraculus.miodominio.it`.

Prova dal tuo PC:

```
curl https://<host>/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"messages":[{"role":"user","content":"Hi"}],"max_tokens":8}'
ORACULUS_API_URL=https://<host> godot --headless --path . res://ai/tests/remote_check.tscn
```

## Manutenzione

- Log: `journalctl -u oraculus-llm -f` e `journalctl -u caddy -f`
- Aggiornare script o versione di llama.cpp: ricopia la cartella e rilancia
  `sudo ./install.sh` (il modello non viene riscaricato).
- Altro modello: `MODEL_URL=...` in `/etc/oraculus-llm.env`, poi
  `sudo systemctl restart oraculus-llm`.

## Limiti da conoscere

- **Recupero delle istanze inattive**: Oracle puo' spegnere e recuperare una
  VM Always Free se per 7 giorni resta quasi inattiva (CPU, rete e memoria
  sotto il 20%). Un server di dialoghi con pochi giocatori puo' rientrarci.
  Se succede, si rifanno i passi 3-5. Intanto il gioco non se ne accorge: il
  remoto non risponde alla gara e vince il locale.
- **Endpoint pubblico senza chiave**: chi conosce l'URL puo' usarlo. Non
  costa nulla, al massimo rallenta le risposte.
- Su 2 core una battuta arriva in ~2-9 s (STORY_CONTEXT resta in cache:
  vedi `ai/README.md`).
