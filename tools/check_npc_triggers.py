#!/usr/bin/env python3
"""Verifica che gli NPC interpellino il modello solo nei tre momenti previsti.

Gli NPC devono generare dialoghi SOLO:
  1. al caricamento della scena   -> say_launch_message / _on_server_started
  2. quando vengono colpiti       -> take_damage -> _react_to_hit
  3. quando il giocatore scrive   -> receive_player_answer

Entrare nell'area (_on_body_entered) e il ciclo periodico
(execute_ai_decision, chiamato da _process) non devono generare: erano una
richiesta ogni pochi secondi per ogni NPC a portata del giocatore.

Il controllo e' per RAGGIUNGIBILITA', non per contenuto: costruisce il grafo
delle chiamate di ogni file e verifica che da _on_body_entered e dal ciclo
periodico non si arrivi a una generazione, per nessun cammino. Cosi' una
funzione che contiene ancora i prompt ma non e' collegata a niente (com'e'
ask_riddle) non conta come violazione, mentre una riconnessa domani viene
segnalata subito.

E' statico: legge i .gd, non serve Godot.

Uso:  python3 tools/check_npc_triggers.py
"""
import glob
import io
import os
import re
import sys

RADICE = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
NPC = os.path.join(RADICE, "oraculus", "NPC", "*.gd")

VIETATI = ["_on_body_entered", "execute_ai_decision", "_process", "_physics_process"]
ATTESI = {
    "caricamento": ["say_launch_message", "_on_server_started"],
    "colpito":     ["take_damage"],
    "interpellato": ["receive_player_answer"],
}

GENERA = re.compile(r"_send_to_ai_server\(|make_request\(\s*[\"']chat[\"']")
DEF_FUNZIONE = re.compile(r"^func\s+([A-Za-z_][A-Za-z0-9_]*)")
CHIAMATA = re.compile(r"\b([A-Za-z_][A-Za-z0-9_]*)\s*\(")


def analizza(percorso):
    """{nome funzione: (genera, {funzioni chiamate})} per un file."""
    righe = io.open(percorso, encoding="utf-8").read().splitlines()
    funzioni, corrente = {}, None
    for riga in righe:
        m = DEF_FUNZIONE.match(riga)
        if m:
            corrente = m.group(1)
            funzioni[corrente] = [False, set()]
            continue
        if corrente is None or riga.lstrip().startswith("#"):
            continue
        if GENERA.search(riga):
            funzioni[corrente][0] = True
        for c in CHIAMATA.findall(riga):
            funzioni[corrente][1].add(c)
    return funzioni


def cammino_verso_generazione(funzioni, partenza):
    """Cammino partenza -> ... -> funzione che genera, oppure None."""
    pila = [(partenza, [partenza])]
    visti = set()
    while pila:
        nome, cammino = pila.pop()
        if nome in visti or nome not in funzioni:
            continue
        visti.add(nome)
        genera, chiamate = funzioni[nome]
        if genera:
            return cammino
        for c in sorted(chiamate):
            if c in funzioni and c not in visti:
                pila.append((c, cammino + [c]))
    return None


def main():
    violazioni, mancanti, esaminati = [], [], 0

    for percorso in sorted(glob.glob(NPC)):
        nome = os.path.basename(percorso)
        funzioni = analizza(percorso)
        if not any(g for g, _ in funzioni.values()):
            continue          # NPC senza dialoghi generati: niente da dire
        esaminati += 1

        for radice in VIETATI:
            if radice not in funzioni:
                continue
            cammino = cammino_verso_generazione(funzioni, radice)
            if cammino:
                violazioni.append("%s: %s" % (nome, " -> ".join(cammino)))

        for etichetta, radici in ATTESI.items():
            presenti = [r for r in radici if r in funzioni]
            if not presenti:
                continue
            if not any(cammino_verso_generazione(funzioni, r) for r in presenti):
                mancanti.append("%s: %s non genera (%s)" % (nome, etichetta, "/".join(presenti)))

    print("=" * 68)
    print("  INNESCHI DEI DIALOGHI NEGLI NPC")
    print("=" * 68)
    print("  %d script con dialoghi generati" % esaminati)

    if violazioni:
        print("\n  GENERAZIONE RAGGIUNGIBILE DA UN INNESCO VIETATO (%d):" % len(violazioni))
        for v in violazioni:
            print("    - " + v)
    if mancanti:
        print("\n  INNESCO PREVISTO CHE NON GENERA (%d):" % len(mancanti))
        for m in mancanti:
            print("    - " + m)

    if violazioni or mancanti:
        print("=" * 68)
        return 1

    print("  ok: solo caricamento, colpo e messaggio del giocatore.")
    print("=" * 68)
    return 0


if __name__ == "__main__":
    sys.exit(main())
