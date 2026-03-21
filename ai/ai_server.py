from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import urllib.parse
import traceback
import os
from inference import NPCDialogueEngine



if os.environ.get("RENDER"):
    HOST = "0.0.0.0"
    PORT = int(os.environ.get("PORT", 10000))
    print("[ENV] Modalità Render rilevata")
else:
    HOST = "localhost"
    PORT = 5000
    print("[ENV] Modalità locale")



print("=" * 60)
print("  ORACULUS AI — Server REST per Godot")
print("=" * 60)
print()

engine = NPCDialogueEngine()   # dataset_path rimosso — non più necessario

print(f"\n[SERVER] In ascolto su http://{HOST}:{PORT}")
print("[SERVER] Premi Ctrl+C per fermare.\n")



class NPCHandler(BaseHTTPRequestHandler):

    def log_message(self, format, *args):
        print(f"  [{self.address_string()}] {format % args}")

    def send_json(self, code, data):
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def read_body(self):
        length = int(self.headers.get("Content-Length", 0))
        if length == 0:
            return {}
        raw = self.rfile.read(length)
        return json.loads(raw.decode("utf-8"))

    def do_GET(self):
        path = urllib.parse.urlparse(self.path).path

        if path == "/health":
            self.send_json(200, {
                "status": "ok",
                "engine": "llama.cpp+fallback",
                "llama":  engine.llama.available,
            })

        elif path == "/npcs":
            from inference import NPC_DATA
            self.send_json(200, {"npcs": sorted(NPC_DATA.keys())})

        elif path == "/":
            self.send_json(200, {
                "service": "Oraculus AI NPC Dialogue",
                "version": "5.0",
                "endpoints": {
                    "POST /chat":         "Genera risposta NPC",
                    "POST /reset":        "Resetta memoria NPC",
                    "POST /set_context":  "Aggiorna variabili contesto NPC",
                    "GET  /health":       "Stato server",
                    "GET  /npcs":         "Lista spiriti disponibili",
                    "GET  /history/:npc": "Storia conversazione NPC",
                }
            })

        elif path.startswith("/history/"):
            npc_name = urllib.parse.unquote(path[9:])
            history  = engine._get_memory(npc_name)
            self.send_json(200, {
                "npc_name": npc_name,
                "history":  history,
                "count":    len(history),
            })

        else:
            self.send_json(404, {"error": f"Endpoint non trovato: {path}"})

    def do_POST(self):
        path = urllib.parse.urlparse(self.path).path

        try:
            body = self.read_body()
        except (json.JSONDecodeError, ValueError) as e:
            self.send_json(400, {"error": f"JSON non valido: {e}"})
            return

        if path == "/chat":
            player_input = body.get("player_input", "").strip()
            if not player_input:
                self.send_json(400, {"error": "player_input è obbligatorio"})
                return

            npc_name     = body.get("npc_name",     "Levias")
            hostility    = int(body.get("hostility",   70))
            friendship   = int(body.get("friendship",   0))
            language     = body.get("language",      None)
            context_vars = body.get("context_vars",  {})

            hostility  = max(0, min(100, hostility))
            friendship = max(0, min(100, friendship))

            try:
                result = engine.generate_response(
                    player_input = player_input,
                    npc_name     = npc_name,
                    hostility    = hostility,
                    friendship   = friendship,
                    language     = language,
                    context_vars = context_vars,
                )

                result["history"]  = engine._get_memory(npc_name)
                result["npc_name"] = npc_name

                self.send_json(200, result)

            except Exception as e:
                traceback.print_exc()
                self.send_json(500, {"error": f"Errore interno: {e}"})

        elif path == "/reset":
            npc_name = body.get("npc_name", None)
            engine.reset_memory(npc_name)
            msg = f"Memoria di '{npc_name}' resettata" if npc_name else "Tutta la memoria resettata"
            self.send_json(200, {"status": "ok", "message": msg})

        elif path == "/set_context":
            npc_name     = body.get("npc_name", "")
            context_vars = body.get("context_vars", {})
            if not npc_name:
                self.send_json(400, {"error": "npc_name è obbligatorio"})
                return
            self.send_json(200, {
                "status":       "ok",
                "npc_name":     npc_name,
                "context_vars": context_vars,
            })

        else:
            self.send_json(404, {"error": f"Endpoint non trovato: {path}"})



if __name__ == "__main__":
    server = HTTPServer((HOST, PORT), NPCHandler)
    print("Esempio chiamata da PowerShell:")
    print(f'  Invoke-RestMethod -Uri "http://localhost:{PORT}/chat" \\')
    print(f'    -Method POST -ContentType "application/json" \\')
    print('    -Body \'{"player_input":"chi sei","npc_name":"Levias","hostility":70}\'')
    print()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[SERVER] Fermato.")
        server.server_close()