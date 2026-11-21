# Hiper Yarış

Gerçekçi grafikli, gündelik (casual) kontrollü 3D arcade yarış oyunu — Godot 4.3, Forward+.

- Kanyon pisti, 4 araç, 2 tur, nitro, drift, takedown, rakip yapay zekâsı
- Serbest sürüş fiziği: ağırlık aktarımı, kayma, frenle drift, duvardan sekme
- Gaz otomatik; **A/D** veya **←/→** direksiyon, **S** fren (direksiyonla birlikte drift), **Boşluk** nitro, **R** piste dön, **Esc** menü
- Telefonda ekran butonlarıyla oynanır (yatay ekran)
- Garaj: araç/renk satın alma, motor ve nitro yükseltmeleri

## PC'de çalıştırma
1. [Godot 4.3](https://godotengine.org/download/archive/4.3-stable/) indir.
2. Bu klasördeki `project.godot` dosyasını Godot ile aç, **F5** ile oynat.

## Varlıklar ve lisanslar
- Araç: *CarConcept* — Eric Chadwick / Darmstadt Graphics Group, **CC BY 4.0** (Khronos glTF Sample Assets)
- Araç: *Fictional supercar – V12 Goblin* — Olli Teittinen (ollitei), **CC BY 4.0** (Sketchfab)
- Araç: *Rayback Mohawk* — Swiss_Fox, **CC BY 4.0** (Sketchfab)
- Araç: *Generic Sport Car Low Poly* — Han66st, **CC BY 4.0** (Sketchfab)
- Bitkiler: **Poly Haven**, CC0
- Kayalar, dokular, gökyüzü (HDRI): **Poly Haven**, CC0
- Motor/kayma/çarpma sesleri ve duman: **Kenney**, CC0
- Diğer kısa efektler `tools/build_sounds.py` ile üretilmiştir.

Varlıkları yeniden indirmek: `python3 tools/fetch_assets.py`
