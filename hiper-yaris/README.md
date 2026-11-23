# Hiper Yarış

Gerçekçi grafikli 3D arcade yarış oyunu — Godot 4.3, Forward+ (telefonda Mobile renderer), Jolt Physics.

- Kanyon pisti (yokuşlar, inişler, zıplatan tepeler), 10 araç, 2 tur, nitro, drift, takedown, rakip yapay zekâsı
- **Gerçek araç fiziği** (Jolt Physics): 4 tekerlek yay+amortisörlü süspansiyon, lastik tutuşu, motor gücü eğrisi, aerodinamik bastırma, el freniyle kontrollü drift
- **Çarpışma fiziği:** sert darbelerde araçlar kontrolden çıkıp takla atar, enkaz saçılır; oyuncu kazasında ağır çekim; rakibe sert vuruş = TAKEDOWN
- PC: **W** gaz, **S** fren/geri, **A/D** direksiyon, **Boşluk** el freni (drift), **Shift** nitro, **R** piste dön, **Esc** duraklat
- **Yarış atmosferi:** tempolu müzik, seyirci tribünleri ve tezahürat, sponsor afişleri, start ışıkları, rakip motor sesleri, fren izleri, "SON TUR" duyurusu, bitişte konfeti, yüksek hızda hız çizgileri
- Telefon (yatay): ekranda ◀ ▶, GAZ, FREN, DRİFT, NİTRO butonları
- Arayüz: mini harita, ilerleme çubuğu, duraklatma menüsü, 10 araçlık sonuç tablosu, araç istatistikli garaj
- Grafik kalitesi menüden: DÜŞÜK (telefon varsayılanı) / ORTA / YÜKSEK
- Garaj: 10 araç satın alma
- **Modifiye atölyesi** (araç başına kaydedilir): MOTOR, TURBO/NİTRO, LASTİK, SÜSPANSİYON yükseltmeleri; BOYA (12 renk), NEON alt ışık, CAM FİLMİ, NİTRO ALEVİ rengi

## Performans
- Araç parçaları malzemeye göre tek mesh'te birleştirilir, iç parçalar atılır; gövde ve tekerlekler için derlemede LOD üretilir (`assets/baked/`, `BAKE=1 godot -- --tool=bake`)
- Dinamik çözünürlük: kare süresine göre 3B çözünürlük ayarlanır (60 FPS hedefi); telefonda 60 FPS kilidi
- Gölgede araçların kaba LOD'u kullanılır
- Kaya/bitkiler sadeleştirilmiş ve bölgesel MultiMesh ile çizilir
- Tüm dokular GPU sıkıştırmalı (ETC2/ASTC/S3TC) ve mipmap'li
- Açılışta shader ısıtma (yarışta ilk kez görülen malzeme takılması olmaz)

## PC'de çalıştırma
1. [Godot 4.3](https://godotengine.org/download/archive/4.3-stable/) indir.
2. Bu klasördeki `project.godot` dosyasını Godot ile aç, **F5** ile oynat.

## Varlıklar ve lisanslar
- Araç: *CarConcept* — Eric Chadwick / Darmstadt Graphics Group, **CC BY 4.0** (Khronos glTF Sample Assets)
- Araç: *Fictional supercar – V12 Goblin* — Olli Teittinen (ollitei), **CC BY 4.0** (Sketchfab)
- Araçlar: *Aspark Owl 2020, Jaguar XJ220 1991, A110 GT4, Mitsubishi Lancer Evolution 6, Deus Vayanne Concept 2022, Italdesign Zerouno 2017, BMW M8 GTE, Porsche 919 Hybrid Evo* — vecarz (heynic), **CC BY 4.0** (Sketchfab; oyunda kurgusal adlarla). Gerçek marka tasarımlarıdır: mağazada yayından önce bkz. `assets/CREDITS.md`
- Bitkiler: **Poly Haven**, CC0 (oyun için `tools/optimize_env.py` ile sadeleştirildi)
- Kayalar, dokular, gökyüzü (HDRI): **Poly Haven**, CC0
- Fizik motoru: [Godot Jolt](https://github.com/godot-jolt/godot-jolt) (MIT)
- Motor/kayma/çarpma sesleri ve duman: **Kenney**, CC0
- Kısa efektler `tools/build_sounds.py`, müzik ve seyirci sesleri `tools/build_music.py`, afiş/seyirci dokuları `tools/make_deco.py`, duman dokusu `tools/make_smoke.py` ile üretilmiştir.

Varlıkları yeniden indirmek: `python3 tools/fetch_assets.py`
