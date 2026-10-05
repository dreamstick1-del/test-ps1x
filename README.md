# Skalitz 1403 — Diorama PS1 (Godot 4.3+)

Aventura low-poly estilo PlayStation 1 que se juega **dentro de una maqueta**: el pueblo
bohemio de Skalitz montado sobre una peana de madera, renderizado a 320x240 con jitter
de vértices, texturas afines, color de 15 bits con dithering y marco de televisor CRT.

Abre la carpeta con Godot 4.3 o superior y pulsa F5. No hacen falta plugins.

## Controles

| Acción | Teclado | Mando |
|---|---|---|
| Avanzar / retroceder | W / S, ↑ / ↓ | Cruceta / stick |
| Girar (control tanque) | A / D, ← / → | Cruceta / stick |
| Correr | Shift | B / Círculo |
| Hablar / avanzar diálogo / saltar intro | E, Espacio | A / Cruz |
| Pausa | Esc, P | Start |

## Flujo del juego

`MENU` (el diorama gira, "PULSA START") → **Juego Nuevo** → `CUTSCENE` (intro con
subtítulos; se puede saltar) → `PLAYING` (planos fijos por zona) ⇄ `DIALOG` (aldeanos) ⇄ `PAUSED`.

El autoload `GameManager` guarda el estado y hace de bus de señales entre el mundo 3D
y la interfaz, que viven en SubViewports separados.

## Estructura

```
MainDioramaScene (scenes/main_diorama.tscn)
├─ GameView  SubViewportContainer (shrink 3 → 320x240, shader ps1_post: 15 bits + Bayer)
│  └─ SubViewport
│     └─ DioramaWorld   scripts/diorama_world.gd (pueblo generado por código)
│        ├─ Camera3D    scripts/diorama_camera.gd (órbita / cinemática / planos fijos + DOF miniatura)
│        └─ Player_Henry scenes/player_henry.tscn (control tanque, estamina)
├─ UIView    SubViewportContainer (320x240, process ALWAYS)
│  └─ UIRoot: HUD_Overlay (vida, aguante, minimapa, subtítulos), DialogBox, MainMenu, PauseMenu, Fade
└─ CRTOverlay (scanlines, viñeta, esquinas, a resolución nativa)
```

| Archivo | Qué hace |
|---|---|
| `autoload/game_manager.gd` | Estados, Input Map (se registra solo), diálogos, opciones gráficas |
| `shaders/ps1_spatial.gdshader` | Vertex snapping, mapeado afín, Nearest, UV en espacio mundo |
| `shaders/ps1_post.gdshader` | Reducción a 15 bits con dithering Bayer 4x4 |
| `shaders/crt_overlay.gdshader` | Marco de televisor |
| `scripts/ps1_assets.gd` | Texturas procedurales 32x32 y materiales PS1 |
| `scripts/camera_zone.gd` | Zonas de cámara fija (corte seco al entrar) |
| `scripts/villager.gd` | Aldeanos con diálogo |
| `scripts/ps1_rigged_character.gd` | Personajes FBX (rig Mixamo) con animaciones PS1 |
| `scripts/ps1_character.gd` | Personaje de cajas (fallback sin modelo) |
| `scripts/character_repaint.gd` | Repintado medieval automático de texturas |

Las opciones del menú permiten activar/desactivar CRT, dithering, temblor de vértices y
texturas afines (usan los uniformes globales `ps1_vertex_snap` y `ps1_affine`).

## Personajes y repintado medieval

`assets/characters/Character_01..05.fbx` son modelos PSX con rig Mixamo. Traen solo una
pose, así que las animaciones (`idle`, `walk`, `run`, `talk`) se generan por código sobre
los huesos con interpolación **NEAREST**: el movimiento salta de pose en pose, como en PS1.

| Modelo | Personaje | Atuendo |
|---|---|---|
| Character_01 | Henry (jugador) | `henry`: túnica roja, camisa de lino, calzas, botas |
| Character_02 | Martin, el herrero | `herrero`: delantal de cuero, barba |
| Character_03 | Padre Ondřej | `cura`: hábito negro con capucha |
| Character_04 | Guardia de la puerta | `guardia`: cota de malla, tabardo con cruz |
| Character_05 | Kuneš, campesino | `campesino`: túnica verde y capucha |

`CharacterRepaint` rasteriza cada triángulo en el espacio UV y pinta cada píxel según la
región del cuerpo (hueso dominante) y su posición 3D: cinturón, bajo de la túnica, escote,
puños, ojos, pelo, capucha, cruz del tabardo... El resultado es una textura de 128x128 con
color de 15 bits.

Para regenerar las texturas:

```bash
godot --headless --path . -s tools/repaint_characters.gd
```

**Con las texturas originales:** copia `Character_0X.png` junto a los FBX
(`assets/characters/`) y vuelve a ejecutar la herramienta. Así se conservan las caras
originales y la ropa se re-tiñe con su luminancia, de modo que se mantienen los pliegues
de la tela. Para retocar a mano, edita los PNG de `assets/characters/textures/`. Los
atuendos (colores, `robe`, `mail`, `tabard`, `apron`, `hood`, `beard`) se definen en
`CharacterRepaint.OUTFITS`.

## Siguientes pasos sugeridos

- Sonido: ambiente del pueblo, martillo de la forja, pasos con pitch aleatorio.
- Misiones simples (recoger carbón para Martin) usando el mismo sistema de diálogos.
- La cutscene del ataque a Skalitz: humo, fuego y cámara temblando sobre el diorama.
