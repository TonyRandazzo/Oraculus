# Oraculus su Steam

## Stato del pacchetto

I preset `Steam Windows` e `Steam Linux` generano eseguibili x86_64 separati. La stessa build Linux e' quella da provare su Steam Deck. I preset impostano la feature `steam_release`: dialoghi e indovinelli usano i fallback gia' inclusi nel progetto. Durante la partita non vengono avviati Python, NobodyWho o un modello locale e non viene interrogato il proxy remoto. Il `.gguf` e i binari dell'addon non fanno parte dei depot Steam.

Questa scelta permette di testare e distribuire una build offline, ma riduce la varieta' dei dialoghi. Per reintrodurre dialoghi generati in una build pubblica servono controlli effettivi sugli output e la dichiarazione di AI generativa live nel Content Survey di Steamworks.

## Build

Servono Godot 4.7.x e i template di export della stessa versione:

```sh
python3 tools/build_steam.py --godot /percorso/Godot_v4.7.x-stable_linux.x86_64
```

I risultati sono in `export/steam/windows/` e `export/steam/linux/`; i log sono in `export/steam/logs/`, fuori dai depot. Caricare ogni cartella di piattaforma intera: eseguibile, `.pck` e `licenses/`. Il bit eseguibile del file Linux viene impostato dallo script. Nessun `steam_appid.txt` va incluso nel depot pubblico.

In Steamworks configurare due depot con vincolo di sistema operativo Windows e Linux, rispettivamente. Impostare come opzioni di avvio `Oraculus.exe` su Windows e `Oraculus.x86_64` su Linux. Pubblicare le modifiche di configurazione dei depot prima di testare l'installazione con un account che possiede l'app.

## Prima della pubblicazione

- **Diritti:** verificare provenienza, licenza commerciale e attribuzioni di ogni sprite, texture, font, suono e brano. I due pacchetti Kenney hanno file di licenza nel progetto; gli altri asset, soprattutto la musica e il pacchetto `Medieval_Castle_Asset_Pack`, richiedono una verifica documentale. Un nome file che dice "no copyright" non e' una licenza.
- **Content Survey:** dichiarare eventuali immagini, audio, testi o localizzazioni creati con strumenti AI durante lo sviluppo, anche se la build Steam non genera contenuti live. Compilare anche le sezioni relative ai contenuti maturi e assicurare che la pagina del negozio rappresenti la build effettiva.
- **Deck:** giocare dall'inizio alla fine a 1280x800 con il solo controller, senza tastiera o touchscreen; verificare leggibilita' dei testi, mappatura dei pulsanti, menu, campo dialogo, minigiochi, pausa, ritorno al menu e almeno 30 fps stabili. Il controller e la tastiera integrata sono stati implementati, ma non sostituiscono questo collaudo.
- **Desktop:** testare l'eseguibile Windows su Windows e quello Linux su una distribuzione supportata; il collaudo headless non verifica audio, grafica o input reali.
- **Steamworks:** completare onboarding, pagina negozio, prezzo, questionnaire, review del build e configurazione delle opzioni di avvio. Non dichiarare Steam Deck Verified o supporto completo del controller prima della verifica effettiva.

Le impostazioni persistenti sono in `user://settings.cfg`; se si attiva Steam Cloud, non sincronizzare quel file fra computer con schermi o impostazioni audio diverse senza separare prima le preferenze per dispositivo.
