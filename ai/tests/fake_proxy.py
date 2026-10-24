"""Proxy finto compatibile OpenAI per failover_check: risponde subito a
POST /v1/chat/completions finche' e' "vivo". POST /muto lo fa rispondere 500
da li' in poi, POST /vivo lo rimette in servizio.

  python3 ai/tests/fake_proxy.py 8765
"""
import json
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

STATO = {"vivo": True}


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def _json(self, code, obj):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        self._json(200, {"status": "ok", "llama": STATO["vivo"]})

    def do_POST(self):
        self.rfile.read(int(self.headers.get("Content-Length", 0)))
        if self.path in ("/muto", "/vivo"):
            STATO["vivo"] = self.path == "/vivo"
            return self._json(200, {"vivo": STATO["vivo"]})
        if not STATO["vivo"]:
            return self._json(500, {"error": "proxy muto"})
        testo = "RIDDLE: I have keys but open no doors.\nANSWER: piano"
        self._json(200, {"choices": [{"message": {"role": "assistant",
                    "content": "The shadows remember you, knight. " + testo}}]})


ThreadingHTTPServer(("127.0.0.1", int(sys.argv[1])), Handler).serve_forever()
