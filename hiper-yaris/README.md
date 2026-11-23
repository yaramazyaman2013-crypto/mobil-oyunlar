# Hiper Yarış

Gerçekçi grafikli 3D arcade yarış oyunu — Godot 4.3, Forward+ (telefonda Mobile renderer), Jolt Physics.

- Kanyon pisti (yokuşlar, inişler, zıplatan tepeler), 10 araç, 2 tur, nitro, drift, takedown, rakip yapay zekâsı
- **Gerçek araç fiziği** (Jolt Physics): 4 tekerlek yay+amortisörlü süspansiyon, lastik tutuşu, motor gücü eğrisi, aerodinamik bastırma, el freniyle kontrollü drift
- **Çarpışma fiziği:** sert darbelerde araçlar kontrolden çıkıp takla atar, enkaz saçılır; oyuncu kazasında ağır çekim; rakibe sert vuruş = TAKEDOWN
- PC: **W** gaz, **S** fren/geri, **A/D** direksiyon, **Boşluk** el freni (drift), **Shift** nitro, **R** piste dön, **Esc** duraklat
- **Yarış atmosferi:** tempolu müzik, basamaklı tribünler (koltuk sıraları, tek tek zıplayan seyirciler, kolonlu çatı, ışık direkleri, bayraklar) ve tezahürat, sponsor afişleri, start ışıkları, rakip motor sesleri, fren izleri, "SON TUR" duyurusu, bitişte konfeti, yüksek hızda hız çizgileri
- Telefon (yatay): ekranda ◀ ▶, GAZ, FREN, DRİFT, NİTRO butonları
- Arayüz: mini harita, ilerleme çubuğu, duraklatma menüsü, 10 araçlık sonuç tablosu, araç istatistikli garaj
- Grafik kalitesi menüden: DÜŞÜK (telefon varsayılanı) / ORTA / YÜKSEK
- Açılışta Aslan Software logosu
- **Garaj:** döner platformlu, ışıklı showroom; 10 markasız araç satın alma
- **Modifiye atölyesi** (araç başına kaydedilir): MOTOR, TURBO/NİTRO, LASTİK, SÜSPANSİYON yükseltmeleri; BOYA (12 renk), NEON alt ışık, CAM FİLMİ, NİTRO ALEVİ rengi

## Performans
- Araç parçaları malzemeye göre tek mesh'te birleştirilir, iç parçalar atılır; gövde ve tekerlekler için derlemede LOD üretilir (`assets/baked/`, `BAKE=1 godot -- --tool=bake`)
- Görüntü her zaman tam çözünürlükte (çözünürlük düşürme yok) + MSAA kenar yumuşatma; telefonda 60 FPS kilidi
- Arazi 32x32 hücrelik bölgelere ayrılır, her bölgenin 3 detay seviyesi var (uzak dağlar seyrek)
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
- Araçlar (hepsi kurgusal/markasız): *Rayback Mohawk, Patriot P10-XR, Wulf Revo, Italia Velocita, Ozutsu Daimyo* — Swiss_Fox; *Kralzfiller XSR* — Tyler_Dave; *Gourami* — ministephen; *Generic Coupe Azura* — mk2design; hepsi **CC BY 4.0** (Sketchfab). Ayrıntı: `assets/CREDITS.md`
- Bitkiler: **Poly Haven**, CC0 (oyun için `tools/optimize_env.py` ile sadeleştirildi)
- Kayalar, dokular, gökyüzü (HDRI): **Poly Haven**, CC0
- Fizik motoru: [Godot Jolt](https://github.com/godot-jolt/godot-jolt) (MIT)
- Motor/kayma/çarpma sesleri ve duman: **Kenney**, CC0
- Kısa efektler `tools/build_sounds.py`, müzik ve seyirci sesleri `tools/build_music.py`, afiş/seyirci dokuları `tools/make_deco.py`, duman dokusu `tools/make_smoke.py` ile üretilmiştir.

Varlıkları yeniden indirmek: `python3 tools/fetch_assets.py`
