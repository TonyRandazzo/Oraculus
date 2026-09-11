"""Stub di huggingface_hub: permette di importare inference.py senza le dipendenze
di rete/ML, per usarne solo le funzioni pure (generazione dati e dump di parita')."""
import sys, types, os


def install():
    if "huggingface_hub" not in sys.modules:
        m = types.ModuleType("huggingface_hub")

        class InferenceClient:  # pragma: no cover - mai usato nei tool
            def __init__(self, *a, **k):
                raise RuntimeError("stub")

        m.InferenceClient = InferenceClient
        sys.modules["huggingface_hub"] = m
    ai_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "ai")
    ai_dir = os.path.normpath(ai_dir)
    if ai_dir not in sys.path:
        sys.path.insert(0, ai_dir)
