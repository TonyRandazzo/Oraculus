# Backup camera — 27/08/2026

Stato dei file PRIMA della correzione del bug "zoom/dezoom continuo" in Astri/CameraDistance2.

## Contenuto
- `astri_camera.gd.bak`      -> `oraculus/astri_camera.gd`
- `camera_distance.gd.bak`   -> `oraculus/camera_distance.gd`
- `camera_distance2.gd.bak`  -> `oraculus/camera_distance2.gd`
- `camera_distance_3.gd.bak` -> `oraculus/camera_distance_3.gd`
- `main.tscn.bak`            -> `oraculus/main.tscn`
- `GIT_HEAD.txt`             -> commit su cui si basava il backup

## Come ripristinare tutto
Dalla root del progetto:

    cp backup_camera_2026-08-27/astri_camera.gd.bak      oraculus/astri_camera.gd
    cp backup_camera_2026-08-27/camera_distance.gd.bak   oraculus/camera_distance.gd
    cp backup_camera_2026-08-27/camera_distance2.gd.bak  oraculus/camera_distance2.gd
    cp backup_camera_2026-08-27/camera_distance_3.gd.bak oraculus/camera_distance_3.gd
    cp backup_camera_2026-08-27/main.tscn.bak            oraculus/main.tscn

(chiudere Godot prima di ripristinare main.tscn, poi riaprire)

## Cosa e' stato cambiato (per confronto)
1. Tutti e 4 gli script camera ora pilotano il Camera2D **solo se il player e'
   dentro la loro area** (prima lo facevano sempre, ogni frame, tutti insieme).
2. Aggiunto un "proprietario" della camera (meta `cam_zoom_owner` sul Camera2D):
   una sola zona alla volta puo' comandare lo zoom.
3. All'uscita la zona riporta zoom/offset ai valori iniziali e molla il controllo.
4. Lo zoom viene clampato a un minimo di 0.05 (0 e negativi rompono il Camera2D).
5. `Astri/CameraDistance2` -> `fixed_zoom` da `Vector2(-4, -4)` a `Vector2(1, 1)`.
6. `max_zoom` di default da `Vector2(0, 0)` a `Vector2(1, 1)` in
   `astri_camera.gd` e `camera_distance.gd`.
7. Il passaggio a `top_level` non fa piu' saltare la camera.
8. Il calcolo di `t` usa lo spazio locale del CollisionShape2D (prima usava
   quello dell'Area2D, ignorando l'offset della shape).

## Modifica successiva — CameraDistance4 (Covo Orchi)
- `camera_distance_3.gd`: aggiunti gli export `offset_at_center` / `offset_at_edge`
  (default `Vector2(0,0)`, quindi le due zone `CameraDistance3` non cambiano
  comportamento). La logica dello zoom NON e' stata toccata: resta quella
  proporzionale alla distanza dal centro, non quella a camera fissa di Astri.
  Stato precedente in `camera_distance_3.gd.pre-offset.bak`.
- `main.tscn`, nodo `Covo Orchi/CameraDistance4`:
    max_zoom         = Vector2(0.8, 0.8)   (prima ereditava 1.0)
    offset_at_center = Vector2(0, -200)    (camera alzata al centro dell'area)
