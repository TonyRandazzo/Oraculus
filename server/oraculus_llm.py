"""Server del ramo remoto di Oraculus, per una VM Oracle Cloud "Always Free"
(Ampere A1, ARM): llama-server di llama.cpp con il modello degli NPC.

Niente API di inferenza di terzi, niente token, niente crediti: il modello
gira sulla VM. Lo script scarica il binario ufficiale di llama-server per
l'architettura della macchina (arm64 su Ampere, x64 altrove) e il .gguf, poi
diventa llama-server su 127.0.0.1:7860. Davanti c'e' Caddy, che aggiunge
l'HTTPS (vedi install.sh e Caddyfile).

Il gioco chiama https://<host>/v1/chat/completions, un endpoint compatibile
OpenAI che oraculus_backend_remote.gd sa gia' usare (anche in streaming SSE,
e su Web: llama-server risponde con CORS aperto).

Tutto e' sovrascrivibile da /etc/oraculus-llm.env (vedi oraculus-llm.service).
"""
import os
import platform
import shutil
import tarfile
import urllib.request

# Versione fissata: una build nuova di llama.cpp puo' cambiare le opzioni.
LLAMA_VERSION = os.environ.get("LLAMA_VERSION", "b11869")
ARCH = "arm64" if platform.machine().lower() in ("aarch64", "arm64") else "x64"
LLAMA_URL = ("https://github.com/ggml-org/llama.cpp/releases/download/"
             f"{LLAMA_VERSION}/llama-{LLAMA_VERSION}-bin-ubuntu-{ARCH}.tar.gz")
# Un semplice download HTTPS di un file pubblico, non un'API di inferenza.
MODEL_URL = os.environ.get(
    "MODEL_URL",
    "https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/"
    "Llama-3.2-1B-Instruct-Q6_K_L.gguf")

DATI = os.environ.get("ORACULUS_DATA", "/var/lib/oraculus-llm")
BIN_DIR = os.path.join(DATI, f"llama-{LLAMA_VERSION}")
MODEL = os.path.join(DATI, os.path.basename(MODEL_URL.split("?")[0]))


def scarica(url: str, dest: str) -> None:
    """Scarica in un .part e rinomina: un riavvio a meta' download non lascia
    un file troncato che sembra buono."""
    print(f"[oraculus] scarico {url}", flush=True)
    parziale = dest + ".part"
    with urllib.request.urlopen(url, timeout=60) as r, open(parziale, "wb") as f:
        shutil.copyfileobj(r, f, 4 * 1024 * 1024)
    os.replace(parziale, dest)


def prepara() -> str:
    os.makedirs(DATI, exist_ok=True)
    server = os.path.join(BIN_DIR, "llama-server")
    if not os.path.exists(server):
        archivio = os.path.join(DATI, "llama.tar.gz")
        scarica(LLAMA_URL, archivio)
        with tarfile.open(archivio) as t:
            try:
                t.extractall(DATI, filter="tar")
            except TypeError:  # Python senza il parametro filter
                t.extractall(DATI)
        os.remove(archivio)
    if not os.path.exists(MODEL):
        scarica(MODEL_URL, MODEL)
    return server


def main() -> None:
    server = prepara()
    env = dict(os.environ)
    env["LD_LIBRARY_PATH"] = BIN_DIR + os.pathsep + env.get("LD_LIBRARY_PATH", "")
    args = [
        server, "-m", MODEL,
        # Solo in locale: da fuori si passa da Caddy, in HTTPS.
        "--host", os.environ.get("HOST", "127.0.0.1"),
        "--port", os.environ.get("PORT", "7860"),
        # Un thread per core: la VM gratuita ne ha 2.
        "-t", os.environ.get("THREADS", str(os.cpu_count() or 2)),
        # Uno slot solo, con il contesto di N_CTX del ramo locale. Ogni system
        # prompt comincia con STORY_CONTEXT (~2000 token, ~15 s su 2 core);
        # llama-server tiene in cache il prefisso dello slot, e con uno slot
        # solo ogni richiesta lo ritrova e paga solo la coda (~300-500 token).
        # Il gioco lo mette in cache appena il remoto vince la gara
        # (OraculusRemoteBackend.scalda()).
        "-np", "1", "-c", "4096",
        # Tetto di sicurezza: il gioco chiede gia' 80 token (150 per gli
        # indovinelli) con max_tokens.
        "-n", "256",
        # Applica il template di chat contenuto nel .gguf (Llama 3.2).
        "--jinja", "--alias", "oraculus",
    ]
    print("[oraculus] avvio:", " ".join(args), flush=True)
    os.execve(server, args, env)


if __name__ == "__main__":
    main()
