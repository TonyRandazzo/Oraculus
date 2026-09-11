# Motore di dialogo Oraculus — da Python a GDScript

Il motore di dialogo degli NPC girava in un processo Python separato
(`ai/inference.py` + `ai/ai_server.py`, server HTTP su `localhost:5000`). Ora
vive dentro il gioco, in GDScript. Il codice Python resta nel repo perche'
serve ancora al proxy su Render.

## Cos'e' sparito

- il `venv` creato a runtime e il `pip install` all'avvio;
- `OS.create_process` per lanciare il server;
- il `taskkill` / `fuser -k` sulla porta 5000;
- i 90 secondi di `MAX_STARTUP_WAIT` prima di poter parlare;
- la dipendenza da Python installato sulla macchina del giocatore;
- gli `HTTPClient` aperti a mano dentro un `Thread` in ogni NPC.

## I file

| File | Ruolo |
| --- | --- |
| `oraculus_data.gd` | **Generato.** Costanti: `STORY_CONTEXT`, `NPC_DATA`, `INTENT_KW`, `FALLBACK`, `RIDDLE_FALLBACKS`, `DEFAULT_RIDDLE_THEMES`. |
| `oraculus_logic.gd` | Funzioni pure, porting 1:1 di `inference.py`: `detect_language`, `classify_intent`, `hostility_tier`, `adjust_hostility`, `pulisci`, `build_prompt`, `build_system_msg`, `enforce_army_name`, `parse_riddle_response`. |
| `oraculus_engine.gd` | `NPCDialogueEngine`: memoria per NPC, scelta del backend, fallback, sblocco di Malakai, indovinelli. |
| `oraculus_backend_local.gd` | Inferenza locale via NobodyWho (llama.cpp). Sostituisce `llama_cpp.Llama`. |
| `oraculus_backend_remote.gd` | Inferenza remota via `HTTPRequest`. Sostituisce `InferenceClient.chat_completion`. |
| `../AIServerManager.gd` | Facciata sottile. Firma pubblica invariata: `make_request`, `is_server_ready`, `is_using_remote`, `server_started`, `server_failed`. |
| `inference.py`, `ai_server.py` | Restano per il proxy su Render, piu' l'endpoint `POST /v1/chat/completions`. |

`oraculus_data.gd` **non va modificato a mano**: si rigenera da `inference.py` con

```
python3 tools/gen_oraculus_data.py
```

Le stringhe sono emesse come literal GDScript byte-per-byte identici a quelli
Python, e l'ordine delle chiavi dei dizionari e' preservato — conta, perche'
`classify_intent` restituisce il *primo* intent che matcha e `detect_language`
prende il *primo* massimo.

## Verificare che la logica sia identica, non solo simile

```
python3 tools/parity_dump.py                                   # genera i casi
godot --headless --path . res://ai/tests/parity_check.tscn      # confronta
```

`parity_dump.py` importa `inference.py`, genera qualche migliaio di casi
(frasi in 5 lingue × NPC × ostilita'/amicizia × storico × context_vars) e
salva gli output attesi in `ai/tests/parity_cases.json`. La scena Godot
rilegge quel file e confronta stringa per stringa; per i prompt completi, che
contengono i 9 KB di `STORY_CONTEXT`, il confronto e' su lunghezza + sha256.
Esce con codice 0 se tutto combacia, 1 altrimenti.

Stato attuale: **3877/3877 confronti superati**, inclusi 1012 `build_prompt` e
1012 `build_system_msg`. Se `build_prompt` combacia, il modello riceve lo
stesso input di prima.

Il cablaggio (facciata → motore → backend) e' coperto da uno smoke test
separato, che verifica forma delle risposte, accumulo e reset della memoria,
la regola speciale di Rigon, lo sblocco di Malakai e che gli indovinelli
tornino sempre completi anche quando il backend non risponde:

```
godot --headless --path . res://ai/tests/smoke_check.tscn
```

Stato attuale: **33/33 controlli superati**.

Il terzo test e' l'unico che carica davvero il `.gguf` e genera: dimostra che
i nomi di proprieta', metodi e segnali dell'addon sono quelli che
`oraculus_backend_local.gd` si aspetta, che il system prompt viene davvero
sostituito a ogni richiesta e che la catena di sampling viene accettata.

```
godot --headless --path . res://ai/tests/local_check.tscn
```

Stato attuale: **16/16 controlli superati** (~1 minuto su CPU: carica un
modello da 1 GB e fa sei generazioni vere). Senza addon o senza modello si
dichiara saltato invece di fallire.

Per controllare che tutti gli script del progetto compilino:

```
python3 tools/check_scripts.py /percorso/di/godot
```

Nota: `--check-only --script` da solo non registra gli autoload, quindi
segnala come errore ogni riferimento a `FeedbackPopup`, `GameState` o
`AIServerManager`. `check_scripts.py` filtra esattamente quel rumore.

## Inferenza locale: NobodyWho

L'addon e' gia' in `addons/nobodywho/` (**v11.0.0**), ma **non e' nel git**:
sono binari da 262 MB, e `.gitignore` li esclude. Su una macchina nuova si
reinstalla da AssetLib (cerca "NobodyWho") oppure scaricando la release:

```
curl -L -o nobodywho.zip \
  https://github.com/nobodywho-ooo/nobodywho/releases/download/nobodywho-godot-v11.0.0/nobodywho-godot-nobodywho-godot-v11.0.0.zip
unzip -j nobodywho.zip 'bin/addons/nobodywho/*' -d addons/nobodywho/
```

Qui dentro ci sono solo i binari **Linux x86_64 e Windows x86_64**: lo zip
della release contiene anche macOS, iOS e Android (arm64), che vanno estratti
a parte se ti servono — la preset di export Android li richiede.

Senza l'addon il progetto compila e gira comunque: il backend locale si
dichiara non disponibile e il motore passa al ramo remoto. I nomi delle
proprieta' di NobodyWho sono cambiati tra le versioni, quindi
`oraculus_backend_local.gd` accede all'addon per riflessione con una lista di
candidati per ogni proprieta', invece di riferirsi ai tipi per nome.

### Cosa e' cambiato in v11 (verificato, non dedotto)

Sono le tre cose che facevano fallire il ramo locale in silenzio:

- la proprieta' che collega il modello alla chat si chiama **`model_node`**,
  non `model`. Con il nome sbagliato `start_worker()` stampa
  `Model node was not set` e il worker muore, ma niente solleva un errore:
  ora se la proprieta' non esiste `setup()` fallisce e si passa al remoto;
- **`NobodyWhoSampler` non esiste piu'**. La catena di sampling
  (`penalties` → `top_k` → `top_p` → `temperature` → `dist`, gli stessi
  valori che `inference.py` passava a `llama_cpp`) si costruisce con
  `NobodyWhoSamplerBuilder` e si passa a `set_sampler_config()`;
- il sampler va configurato **dopo** `start_worker()`: a worker fermo l'addon
  lo scarta con un warning e usa i suoi default. `_apply_sampler()` adesso si
  rifiuta di girare prima dell'avvio, cosi' un riordino futuro rompe il test
  invece delle risposte.

In piu' `say()` e' deprecato in favore di `ask()` (proviamo prima `ask`), e
`setup()` aspetta il segnale `worker_started`: il `.gguf` viene caricato in un
thread dell'addon, quindi senza quell'attesa dichiareremmo il backend pronto
mentre llama.cpp sta ancora leggendo — o ha gia' fallito.

### Dov'e' il modello

`llama.cpp` vuole un file vero sul filesystem: **un `.gguf` dentro il `.pck`
non e' leggibile**. `_resolve_model_path()` cerca, in ordine:

1. `$ORACULUS_MODEL_PATH`;
2. `user://models/<nome>.gguf` (copia gia' estratta);
3. `<cartella dell'eseguibile>/models/<nome>.gguf`, oppure la cartella di
   progetto quando si gira dall'editor;
4. `res://models/<nome>.gguf` dentro il `.pck` — in questo caso viene copiato
   una volta in `user://models/` e si usa quello.

Oggi in `models/` c'e' `Llama-3.2-1B-Instruct-Q6_K_L.gguf` (1,08 GB), che e'
il percorso 3 quando si gira dall'editor: la cartella e' in `.gitignore`, va
copiata a mano su una macchina nuova.

Il percorso 4 funziona ma costa 1 GB nel `.pck` **piu'** 1 GB in `user://`.
Per gli export conviene togliere `models/*.gguf` da `include_filter` in
`export_presets.cfg` e spedire il `.gguf` accanto all'eseguibile (percorso 3).
`ai/*.py` e' gia' stato tolto dal filtro: il gioco non lancia piu' Python.

## Inferenza remota

`oraculus_backend_remote.gd` fa un POST su
`https://oraculus-ai-api.onrender.com/v1/chat/completions` (sovrascrivibile
con la variabile d'ambiente `ORACULUS_API_URL`). E' un endpoint compatibile
OpenAI, senza logica di gioco: prompt, memoria, intent e pulizia sono tutti
lato Godot.

**Il proxy va ridistribuito** perche' quell'endpoint esista: e' stato aggiunto
in `ai_server.py` in questo cambiamento. Le rotte vecchie (`/chat`, `/riddle`,
`/reset`, `/set_context`, `/health`) sono intatte, quindi il deploy attuale
continua a funzionare per qualunque client vecchio.

Il proxy serve anche a qualcosa che non e' pigrizia: tiene `HF_TOKEN` lato
server. Messo nel client sarebbe estraibile dal `.pck`.

## Export Web

Le GDExtension native non girano in wasm, quindi su Web il ramo locale non
esiste e resta necessario quello remoto. `oraculus_backend_remote.gd` su Web
passa da `fetch()` via `JavaScriptBridge` invece di `HTTPRequest`, per via del
CORS. In pratica: nativo su desktop, remoto su web.

## Differenze deliberate rispetto a `inference.py`

Sono due, entrambe documentate anche nel codice.

**`hash()`.** In Python l'hash delle stringhe e' randomizzato a ogni processo,
quindi lo stesso `door_id` dava un indovinello di riserva diverso a ogni
riavvio. `String.hash()` in Godot e' deterministico. Per non perdere la
varieta' la chiave e' `door_id + session_id`: `GameState.session_id` cambia a
ogni partita, quindi gli indovinelli variano come prima, ma in modo
riproducibile a sessione fissa. Lo stesso vale per la scelta del tema, dove
Python usava `hash(door_id)` da solo.

**Il template del prompt locale.** NobodyWho applica da se' il template della
chat del modello e non permette di iniettare turni dell'assistente, quindi il
ramo locale usa `build_system_msg()` piu' il blocco di storico e lascia i
token all'addon, invece del prompt grezzo `<|start_header_id|>...` costruito a
mano da `build_prompt()`. Il modello e' lo stesso (Llama-3.2-1B-Instruct) e il
template che NobodyWho applica e' quello, ma i token non sono garantiti
identici byte per byte. `build_prompt()` resta portato e verificato, pronto se
un giorno il backend esporra' il completamento grezzo.

## Cosa e' rimasto indietro, di proposito

- `python_venv/` (1007 file, 159 MB) e' stato tolto dall'indice git
  (`git rm -r --cached`) e aggiunto al `.gitignore`: i file restano sul disco,
  ma dal prossimo commit il repo non li porta piu'. Cancellarli e' sicuro.
- `ai/tinyllama-v0.q2_k.gguf` (5 MB) non e' usato da nessuno.
- `door2.gd`, `door3.gd`, `door4.gd` non compilano: fanno riferimento a un tipo
  `Player2AINPC` che non esiste in nessun file. E' cosi' dal primo commit e non
  ha niente a che vedere con questo cambiamento.
