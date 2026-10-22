#!/usr/bin/env python3
"""Decodifica con OpenCV los PNG de qr_export.gd y compara con el texto original.
Uso: python3 qr_check.py <carpeta>   (sale con 1 si algún QR no se lee igual)"""
import json, os, sys
import cv2

d = sys.argv[1]
items = json.load(open(os.path.join(d, 'manifest.json'), encoding='utf-8'))
det = cv2.QRCodeDetector()
bad = 0
for it in items:
    img = cv2.imread(os.path.join(d, it['file']))
    text, pts, _ = det.detectAndDecode(img)
    ok = text == it['text']
    bad += 0 if ok else 1
    print(f"{'OK   ' if ok else 'FALLA'} v{it['version']:<2} máscara {it['mask']}  {it['text'][:60]!r}" + ('' if ok else f'  → leído {text!r}'))
print(f"{len(items) - bad}/{len(items)} QR decodificados por OpenCV {cv2.__version__}")
sys.exit(1 if bad else 0)
