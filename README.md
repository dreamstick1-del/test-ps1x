# Skalitz 1403 — Diorama PS1 en primera persona (Godot 4.3+)

RPG medieval en primera persona al estilo **King's Field** (PS1) que se juega **dentro de
una maqueta**: el menú muestra el diorama de Skalitz girando sobre una mesa y, al empezar,
la cámara se mete en los ojos de Henry. Se renderiza a 320x240 con temblor de vértices,
texturas afines, color de 15 bits con dithering y marco de televisor CRT.

Abre la carpeta con Godot 4.3 o superior y pulsa F5. No hacen falta plugins.

## Controles

| Acción | Teclado / ratón | Mando |
|---|---|---|
| Mirar | Ratón (←/→ girar, RePág/AvPág) | Stick derecho |
| Moverse (con inercia) | WASD / ↑↓ | Stick izquierdo |
| Correr | Shift | L3 |
| Saltar | Espacio | A / Cruz |
| Agacharse (sigilo) | Ctrl, C | B / Círculo |
| Esquivar (rodar, invulnerable) | Alt, V | R3 |
| Atacar (combo) | Clic izquierdo / J | RB / R1 |
| Ataque cargado | Mantener clic izquierdo / J | Mantener RB |
| Bloquear / parada | Clic derecho / K | LB / L1 |
| Cambiar de arma | Q / rueda ↓, Z / rueda ↑ | D-pad ↓ |
| Habilidades activas | 1, 2, 3 | D-pad ←↑→ |
| Hablar / comerciar / picar | E, F | X / Cuadrado |
| Menú de habilidades | Tab | Back / Select |
| Diario (inventario, sociedad, mercado) | I, L | — |
| Pausa | Esc, P | Start |

### Movimiento y armas

- **Salto** (~1 m, con margen de borde y búfer de pulsación), daño por caída alta.
- **Agachado**: cápsula baja, ojos a 1 m, 1.5 m/s; bandidos y animales te detectan mucho más tarde.
  Un golpe agachado a un enemigo desprevenido hace **x2.5** (sigilo).
- **Correr** 5.8 m/s gastando aguante; ataque en carrera con embestida; ataque en el aire al caer.
- **Esquiva** (~2.7 m) con 0.3 s de invulnerabilidad.
- **Armas** (forja de Martin): espada, espada de acero, hacha, maza, lanza y daga, cada una con su
  combo, alcance, velocidad y aturdimiento. Hacha y maza rompen la guardia de los bandidos.
  **Escudo**: bloquea más daño, más ángulo y menos aguante. Definidas en `scripts/combat/weapons.gd`.

### Bandidos y aldeanos

- **Bandidos**: te provocan al verte, te rodean de lado mientras recuperan el aliento, retroceden si
  te pegas a ellos y alternan tres ataques con destello de aviso: tajo, estocada (con paso adelante,
  más alcance) y golpe pesado por encima de la cabeza (destello rojo; bloquearlo gasta casi el doble
  de aguante, mejor esquivarlo o pararlo). Los de hacha y martillo prefieren el pesado; los de espada,
  la estocada. Al morir caen de rodillas y de espaldas.
- **Aldeanos**: trabajan según su oficio (el herrero y el minero martillean, los campesinos cavan,
  el cura reza, la mercadera pregona, los guardias montan guardia), miran alrededor, se giran y te
  saludan al acercarte, se encogen de miedo durante el asalto y lo celebran al acabar.
- Las animaciones (`scripts/ps1_rigged_character.gd`) se generan por código sobre el rig Mixamo:
  poses clave muestreadas a 15 fps y reproducidas a saltos (NEAREST) como en PS1. La cadera se
  ajusta sola en cada fotograma para que los pies pisen el suelo; andar, correr y rodear van al
  ritmo de la velocidad real (sin patinar). `tools/anim_frame_sheets.gd` genera hojas de
  fotogramas (perfil y frente) con medidas para revisarlas.

### Cielo, niebla y nubes

`scripts/world/atmosphere.gd` (en primera persona):

- **Cielo** (`shaders/ps1_sky.gdshader`): degradado en bandas, nubes en dos capas que se mueven
  con el viento (cuatro tonos, sin degradados suaves), sol que sale por el este y se pone por el
  oeste, luna y estrellas de noche. La nubosidad cambia de un día a otro.
- **Niebla** según la hora: espesa al amanecer, ligera a mediodía, más densa en los valles y el
  río (niebla de altura). **Bancos de niebla baja** (`shaders/ps1_mist.gdshader`) sobre el río,
  los bosques y los prados, sobre todo por la mañana.
- **Horizonte** (`shaders/ps1_horizon.gdshader`): siluetas de montes y bosque lejanos alrededor de
  la cámara, para que más allá de la maqueta no se vea el vacío.

### Imagen nítida

Opción del menú (activada por defecto): el 3D se dibuja a 480x360 en vez de 320x240, el temblor
de vértices es la mitad de fuerte y las scanlines, la viñeta y el tramado son más suaves. Al
desactivarla vuelve el look PS1 clásico a 320x240. La interfaz siempre va a 320x240.

## El mapa (96x96 m)

```
  BOSQUE DE LOS LOBOS     CASTILLO DE SKALITZ (colina)        BOSQUE (ciervos)
  MINA DE PLATA (colina)  [ SKALITZ amurallado ]  campos de trigo | RÍO | PASTOS
                          [ forja, iglesia, plaza ]   puente ----- | ~~~ | MOLINO
  CARBONERAS     GRANJA (cerdos, gallinas)     camino del sur
```

El pueblo (forja, iglesia, mercado, pozo, casas de entramado) está en el centro. El campo lo
genera `scripts/world/countryside.gd`: terreno con colinas, cauce del río y caminos (con
colisión), puente, molino con rueda hidráulica, trigales (MultiMesh), pastos vallados,
castillo con torre y muralla, mina con vagoneta y vetas de plata, granja y carboneras con humo.

Hay **ciclo de día y noche** (1 hora de juego = 15 s): el sol, la luz y el cielo cambian, y
las tiendas cierran por la noche.

## Combate (`scripts/combat/`)

- **Combo ligero**: tajo derecha → tajo izquierda → estocada (más daño y alcance).
- **Bloqueo**: absorbe gran parte del daño gastando aguante. Si te quedas sin aguante, te rompen la guardia.
- **Parada**: si levantas la guardia justo antes del golpe, no recibes daño y el enemigo queda aturdido.
- Los bandidos avisan de su ataque (brazo arriba y destello amarillo) y golpean a los 0,5 s.
- Hit-stop, temblor de cámara, partículas y destello rojo al recibir daño.
- La espada en primera persona se anima con poses a 15 fps, entrecortada como en PS1.

## Habilidades (`autoload/skills.gd`, Tab)

Experiencia por combatir, cazar y hacer paradas; cada nivel da un punto.

| Pasivas (3 rangos) | Activas |
|---|---|
| Fuerza: +15% daño | [1] Golpe Poderoso: daño x2,5 y derriba |
| Vitalidad: +25 vida | [2] Torbellino: giro de 360° (requiere Fuerza 1) |
| Aguante: +20 aguante y más recuperación | [3] Oración: +40 vida (requiere Vitalidad 1) |
| Defensa: mejor bloqueo y paradas más fáciles | |

## Economía y sociedad (`autoload/economy.gd`)

- **Mercado de oferta y demanda**: 12 bienes (trigo, harina, pan, carne, huevos, leche,
  cerveza, lana, pieles, carbón, plata, herramientas). Su precio sube o baja según las existencias.
- **Cadenas de producción**: trigo → harina (molino) → pan (panadero); trigo → cerveza;
  carbón → herramientas (herrería). Sin herramientas, todo el pueblo trabaja peor.
- **Sociedad**: unos 80 habitantes en 19 hogares, cada uno con oficio, clase social
  (siervos, mineros, artesanos, burgueses, clero, guardia), riqueza y satisfacción.
  Cada día producen, venden y compran lo que necesitan. Si no les llega, pasan hambre.
- **Impuestos**: cada 7 días se paga un 10% a Sir Radzig y un 5% de diezmo a la iglesia.
- **Sucesos**: buenas y malas cosechas, vetas de plata, lobos, mercaderes de Praga y el
  asalto de los bandidos (que vacía las despensas y dispara los precios).
- **Henry**: tiene groschen, inventario, equipo (espada de acero, gambesón) y reputación,
  que mejora los precios. Matar ganado ajeno baja la reputación.
- **Tiendas**: Ludmila (mercado), Martin (herrería y equipo) y Pešek (molino).
- **Ganarse la vida**: picar plata en la mina, cazar ciervos y conejos (carne y pieles) y venderlo.
- Los aldeanos comentan lo que pasa en el pueblo: precios, hambre, seguridad o tu reputación.
- **Diario (I)**: inventario (comer y beber cura), sociedad por clases, tabla de precios
  con tendencias, y crónica de sucesos.

## Animales (`scripts/world/animal.gd`)

Gallinas, cerdos, ovejas, vacas, perros (te siguen), ciervos y conejos (huyen; se cazan) y
lobos (atacan). Pastan, deambulan y animan las patas a saltos.

## Misión de introducción

Habla con Martin → entrena con el muñeco de paja → aprende una habilidad → habla con el
guardia → dos oleadas de bandidos, con cabecilla incluido. Después, el mundo queda libre. Si
mueres, vuelves a intentarlo sin perder ni el nivel ni el dinero.

## Personajes y texturas

`assets/characters/Character_01..05.fbx` son personajes PSX con rig Mixamo, animados por
código (idle, walk, run, talk, attack, hit) con interpolación NEAREST.
`tools/repaint_characters.gd` genera las texturas de cada atuendo (Henry, herrero, cura,
guardia, campesino, bandido, cabecilla, molinero, minero, pastor):

```bash
godot --headless --path . -s tools/repaint_characters.gd
```

**Para conservar las caras originales**, copia las texturas originales `Character_0X.png`
junto a los FBX (`assets/characters/`) y vuelve a ejecutar la herramienta. Mantiene la
cabeza original y solo re-tiñe la ropa con los colores medievales, conservando los pliegues
de la tela. Sin esos PNG, las caras se pintan proceduralmente.

## Estructura

| Archivo | Qué hace |
|---|---|
| `autoload/game_manager.gd` | Estados (MENU, PLAYING, DIALOG, CUTSCENE, PAUSED, SKILLS, TRADE, JOURNAL, DEAD), input, señales |
| `autoload/skills.gd` | Experiencia, niveles y árbol de habilidades |
| `autoload/economy.gd` | Reloj, mercado, hogares, impuestos, sucesos, inventario de Henry |
| `scripts/main_diorama.gd` | Flujo menú → intro → primera persona, reintentar |
| `scripts/diorama_world.gd` | Pueblo, aldeanos, animales, día/noche |
| `scripts/world/countryside.gd` | Terreno, río, molino, campos, castillo, mina, bosques |
| `scripts/player_henry.gd` | Controlador en primera persona |
| `scripts/combat/*` | Combate, espada en primera persona, bandidos, muñeco, efectos |
| `scripts/ui/*` | HUD, minimapa, menús (habilidades, comercio, diario, pausa) |
| `shaders/*` | PS1 (jitter + afín + vertex color), viewmodel, post-proceso 15 bits, CRT |
