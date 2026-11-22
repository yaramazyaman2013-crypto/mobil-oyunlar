# Hiper Yarış

Gerçekçi grafikli 3D arcade yarış oyunu — Godot 4.3, Forward+ (telefonda Mobile renderer), Jolt Physics.

- Kanyon pisti (yokuşlar, inişler, zıplatan tepeler), 10 araç, 2 tur, nitro, drift, takedown, rakip yapay zekâsı
- **Gerçek araç fiziği** (Jolt Physics): 4 tekerlek yay+amortisörlü süspansiyon, lastik tutuşu, motor gücü eğrisi, aerodinamik bastırma, el freniyle kontrollü drift
- **Çarpışma fiziği:** sert darbelerde araçlar kontrolden çıkıp takla atar, enkaz saçılır; oyuncu kazasında ağır çekim; rakibe sert vuruş = TAKEDOWN
- PC: **W** gaz, **S** fren/geri, **A/D** direksiyon, **Boşluk** el freni (drift), **Shift** nitro, **R** piste dön, **Esc** duraklat
- Telefon (yatay): ekranda ◀ ▶, GAZ, FREN, DRİFT, NİTRO butonları
- Arayüz: mini harita, ilerleme çubuğu, duraklatma menüsü, 10 araçlık sonuç tablosu, araç istatistikli garaj
- Grafik kalitesi menüden: DÜŞÜK (telefon varsayılanı) / ORTA / YÜKSEK
- Garaj: araç/renk satın alma, motor ve nitro yükseltmeleri

## Performans
- Araç parçaları malzemeye göre tek mesh'te birleştirilir, iç parçalar gizlenir
- Kaya/bitkiler sadeleştirilmiş ve bölgesel MultiMesh ile çizilir
- Tüm dokular GPU sıkıştırmalı (ETC2/ASTC/S3TC) ve mipmap'li
- Açılışta shader ısıtma (yarışta ilk kez görülen malzeme takılması olmaz)

## PC'de çalıştırma
1. [Godot 4.3](https://godotengine.org/download/archive/4.3-stable/) indir.
2. Bu klasördeki `project.godot` dosyasını Godot ile aç, **F5** ile oynat.

## Varlıklar ve lisanslar
- Araç: *CarConcept* — Eric Chadwick / Darmstadt Graphics Group, **CC BY 4.0** (Khronos glTF Sample Assets)
- Araç: *Fictional supercar – V12 Goblin* — Olli Teittinen (ollitei), **CC BY 4.0** (Sketchfab)
- Araç: *Generic Sport Car Low Poly* ve *Sport Car Low Poly* — Han66st, **CC BY 4.0** (Sketchfab)
- Araç: *Saba V12 '95*, *Cheetah '84*, *Exterminator '00* — Daniel Zhabotinsky, **CC BY 4.0** (Sketchfab)
- Bitkiler: **Poly Haven**, CC0 (oyun için `tools/optimize_env.py` ile sadeleştirildi)
- Kayalar, dokular, gökyüzü (HDRI): **Poly Haven**, CC0
- Fizik motoru: [Godot Jolt](https://github.com/godot-jolt/godot-jolt) (MIT)
- Motor/kayma/çarpma sesleri ve duman: **Kenney**, CC0
- Diğer kısa efektler `tools/build_sounds.py` ile üretilmiştir.

Varlıkları yeniden indirmek: `python3 tools/fetch_assets.py`
