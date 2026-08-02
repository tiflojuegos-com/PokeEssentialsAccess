# Audio3D - Navegación por Sonido Posicional

## Concepto

El paisaje sonoro binaural coloca cada emisor (una persona, una puerta, una pared) en un punto alrededor
del jugador. El cerebro localiza el sonido por las diferencias de tiempo y volumen entre oídos, y la HRTF
(Head-Related Transfer Function) las simula: con auriculares, "a la derecha" se oye a la derecha. Es
panorámica **2D**: no hay altura.

`core/audio/audio3d.rb` es el ÚNICO motor de audio del mod: por él pasan también los pasos y los choques.

## El backend: PA3D_steam.dll

Envoltorio Win32 sobre Steam Audio (HRTF) + miniaudio. Necesita `phonon.dll` de la misma arquitectura en
`accessibility/lib`.

```ruby
module PokeAccess::Audio3D
  DLL = "PA3D_steam.dll"

  # Cada punto de entrada va rescatado: si la dll falta, queda nil y available? lo detecta.
  INIT = (Win32API.new(DLL, "PA3D_Init",     [],                        "i") rescue nil)
  CHAN = (Win32API.new(DLL, "PA3D_Channel",  ["p", "i"],                "i") rescue nil)
  LIS  = (Win32API.new(DLL, "PA3D_Listener", ["i", "i"],                "v") rescue nil)
  SET  = (Win32API.new(DLL, "PA3D_Set",      ["i", "i", "i", "i", "i"], "v") rescue nil)
  MAST = (Win32API.new(DLL, "PA3D_Master",   ["i"],                     "v") rescue nil)
  # Opcionales, igual de rescatados: RATE_FN (tasa nativa en Hz), LAT_FN (latencia de salida en ms),
  # OCCL (oclusión por canal) y AIR (absorción del aire).

  # True si la dll está y resolvieron sus entradas obligatorias.
  def self.available?; INIT && CHAN && LIS && SET && MAST; end
end
```

`boot` se ejecuta **una sola vez** (un fallo no debe reintentarse cada frame): comprueba `available?`,
exige `INIT.call == 1`, lee tasa y latencia del dispositivo y carga los canales. Cada fallo se registra.

### Posicionar

```ruby
# Las coordenadas de casilla se escalan a unidades del motor (TILE_UNITS = 100).
# PA3D_Set NO tiene eje Z. Su firma es (canal, x, y, VOLUMEN, on):
#   4º arg = volumen 0-100 (no una altura)   5º arg = 1 reproduce/posiciona, 0 silencia
SET.call(channel, tx * TILE_UNITS, ty * TILE_UNITS, vol, 1)

# El oyente se coloca sobre el jugador cada frame; todo lo demás suena relativo a él.
LIS.call(px * TILE_UNITS, py * TILE_UNITS)
```

Las rutas de los `.wav` se pasan terminadas en `"\0"` porque C espera cadenas null-terminated.

## `CHANNEL_FILES`: qué wav suena para cada cosa

Una tabla, no una tanda de llamadas sueltas, porque es además la **respuesta a "qué archivo suena para
esto"**: el glosario de sonidos previsualiza estos mismos ficheros y un test cruza ambas listas, así que
renombrar un wav aquí no puede dejar al glosario enseñando un sonido que el motor ya no toca.

```ruby
# [símbolo, archivo, 1 si es bucle]
CHANNEL_FILES = [
  [:npc, "pa3d_npc.wav", 0], [:object, "pa3d_object.wav", 0], [:door, "pa3d_door.wav", 0],
  [:teleporter, "pa3d_teleporter.wav", 0], [:hazard, "pa3d_hazard.wav", 0],
  [:wall, "pa3d_wall.wav", 0], [:interact, "pa3d_interact.wav", 0],
  [:control, "pa3d_control.wav", 0], [:trap, "pa3d_boop.wav", 0], [:push, "pa3d_boing.wav", 0],
  [:water, "pa3d_water.wav", 1], [:wind_w, "pa3d_wind_w.wav", 1], [:wind_e, "pa3d_wind_e.wav", 1],
  [:wind_n, "pa3d_wind_n.wav", 1], [:wind_s, "pa3d_wind_s.wav", 1],
  [:step, "pa_step.wav", 0], [:grass, "pa_grass.wav", 0], [:fstep_water, "pa_water.wav", 0],
  [:guide, "pa_guide_c.wav", 0]
]

# boot la recorre entera: CHANNEL_FILES.each { |sym, file, loop| @ch[sym] = load_ch(file, loop) }
```

| Canal | Qué es |
|---|---|
| `:npc` / `:object` / `:door` / `:teleporter` | pings de personas, objetos examinables, salidas, portales |
| `:control` / `:push` / `:trap` / `:hazard` | puzles: palancas, bloques empujables, obstáculos móviles, peligros |
| `:water` / `:wind_*` | bucles: agua cercana y un viento por cada lado con pared |
| `:wall` / `:interact` | choque contra terreno / contra algo interactuable |
| `:step` / `:grass` / `:fstep_water` | pasos: suelo normal, hierba, nadando |
| `:guide` | el chime de la guía hacia el siguiente paso de la ruta |

## Los tres modos de `sound_nav`

| Modo | Qué suena |
|---|---|
| `:full` | Todo el paisaje: pings de emisores, bucle de agua, un viento por pared, pasos y choques. |
| `:basic` | **Solo** pasos y choques, y siguen paneados. El motor está vivo; `silence_emitters` para cada frame los pings y los bucles. |
| `:off` | **Nada**: `tick` silencia todos los canales y sale ANTES de `boot`, así que el motor ni se arranca. `Spatial` tampoco toca sus pasos ni sus choques planos. |

```ruby
def self.nav_full?; (PokeAccess::Config.sound_nav rescue :full) == :full; end
def self.nav_off?;  (PokeAccess::Config.sound_nav rescue :full) == :off;  end
```

`:basic` NO es `:off`: es el modo de quien quiere silenciar el sonar sin perder los pasos.

## El frame: `tick`

Lo llama un `frame_hook` sobre `Game_Player#update`. Esquema del cuerpo:

```ruby
def self.tick
  gate(:total)
  # Sin mapa, o con sound_nav :off: silenciar todo y no arrancar nada.
  return silence_all if nav_off?
  return unless boot
  # Abrir el dispositivo enmudece el BGM del juego: el primer frame tras un boot correcto lo re-lanza.
  busy = PokeAccess::Spatial.busy_reason
  if busy                       # mensaje, menú, combate, escena... : callar y olvidar dónde se escaneó
    gate(busy)
    (silence_all; @scan_pos = nil) if @active
    return
  end
  @active = true
  MAST.call(v) if (v = Config.audio3d_volume) != @master_sent    # maestro y aire solo si cambiaron
  LIS.call(px * TILE_UNITS, py * TILE_UNITS)                     # oyente sobre el jugador
  return silence_emitters unless nav_full?                       # modo :basic
  if @scan_pos != [px, py, $game_map.map_id]                     # sondear es caro: solo al cambiar de casilla
    step3d(:rescan) { rescan(px, py) }
    step3d(:walls)  { update_walls(px, py) }
    step3d(:winds)  { set_winds(px, py) }
    step3d(:water)  { set_loop(:water, @near[:water], type_vol(:water)) }
  elsif PokeAccess::Puzzles.has_movers? && ...  # cada MOVER_SECONDS, solo si el puzle declara movedores
    step3d(:movers) { refresh_movers(px, py) }
  end
  step3d(:ping) { ping_types }                                   # como mucho UN ping por llamada
end
```

Cada paso corre aislado en `step3d`: si uno falla, se registra una vez (`log3d`) y los demás siguen
funcionando. `gate(motivo)` cuenta por qué un frame calló, y `gate_report` lo resume para el diagnóstico
("`playing 41/120 by=message:60 in_menu:19`") — clave porque el paisaje está hecho de BUCLES que solo se
reposicionan al cambiar de casilla.

## Emisores discretos

`type_of(ev)` clasifica un evento en un canal. Es una **proyección** de la clasificación del Locator
(`transfer_event?`, `hazard?`, `push_tile?`, `teleporter_event?`, `event_category`, más las etiquetas del
jugador) sobre el vocabulario de sonidos: aquí no se re-deduce qué es un evento, solo a qué canal va. Solo
suenan como `:npc`/`:object` los eventos **interactuables** (un gráfico suelto no basta, o los sprites
decorativos pingarían como personas fantasma).

```ruby
# Emisor -> la clave de configuración que marca su cadencia.
PING_DEFS = { :npc => :audio3d_freq_npc, :object => :audio3d_freq_object, :door => :audio3d_freq_door,
              :hazard => :audio3d_freq_object, :trap => :audio3d_freq_object, :control => :audio3d_freq_object,
              :push => :audio3d_freq_object, :teleporter => :audio3d_freq_door }
```

### Que no se solapen

```ruby
NEAR_MAX = 3      # cuántos emisores más cercanos se guardan de cada tipo
PING_GAP = 0.25   # ventana (s) tras un ping durante la que se retienen los cercanos
```

1. `rescan` se queda solo con los `NEAR_MAX` más cercanos de cada tipo.
2. `cluster` fusiona casillas que se tocan (8-conectadas) **y comparten sprite** en un único emisor, el más
   próximo: una puerta ancha o un mostrador largo pingan una vez, pero dos personas juntas siguen separadas.
3. `ping_types` dispara **como mucho un emisor por llamada**. Dentro de `PING_GAP` tras un ping solo se
   retienen los candidatos a `alt_dist` casillas o menos de ese ping; uno más lejos SÍ puede sonar (la HRTF
   ya los separa). Entre los tipos cuyo temporizador vence, dispara el **más atrasado** (así un tipo de
   frecuencia alta no monopoliza los turnos); dentro de un tipo, recorre sus cercanos en round-robin.

```ruby
def self.alt_dist; (PokeAccess::Config.audio3d_alt_dist rescue 5).to_i; end
```

### Movedores

Algunos obstáculos de puzle se mueven mientras el jugador está quieto, así que sus casillas cacheadas se
quedan viejas entre escaneos. `refresh_movers` re-lee **solo** los eventos `:trap` cercanos cada
`MOVER_SECONDS` (1,0 s), y únicamente en mapas cuyo puzle declara movedores.

## Paredes, oclusión y viento

`line_clear?` es un raycast directo y barato (avanza una casilla hacia el objetivo por el eje con más
distancia pendiente, comprobando cada paso con el `passable?` del juego, con un tope de 48 pasos). No es un
flood: se puede pagar por emisor y por frame. Ante un error responde "despejado".

| Modo (`audio3d_occlusion`) | Efecto |
|---|---|
| `:hear` | se oye todo igual, las paredes no cuentan |
| `:occlude` (defecto) | un emisor tras pared se atenúa `OCCLUDE_AMOUNT` (80 de 100) |
| `:hide` | un emisor tras pared ni entra en la lista (se filtra ya en `rescan`) |

En modo `:hide` un mostrador de servicio (enfermera, tienda, PC) quedaría oculto tras su propio mostrador;
`desk_bypass?` lo mantiene audible dentro de `audio3d_desk_range` casillas (0 lo desactiva).

El viento marca las paredes largas: `update_walls` lanza un rayo a cada lado (hasta `wall_range`) y
`set_winds` coloca el bucle de ese lado a la distancia encontrada, con caída configurable:

```ruby
v = vol / dist ** (audio3d_wall_falloff / 50.0)
```

Así una pared pegada domina y un hueco de una casilla (que aleja la pared) baja el nivel, haciendo audibles
las aberturas estrechas. Hay **un bucle por lado** (`wind_w/e/n/s`, cuatro grabaciones distintas) para que
dos paredes a la vez no se confundan en una sola masa de ruido.

## Pasos, choques y guía

Tres cues que sobreviven al modo `:basic`. Cada uno se coloca en la casilla que SIGNIFICA, que es lo que le
da lado a la HRTF, y devuelve si lo ha atendido; cuando dicen que no, `Spatial` cae a un cue plano
pre-paneado.

- `footstep(kind, vol)` — el paso, centrado en el jugador; `kind` es `:step`, `:grass` o `:fstep_water`.
- `bump(dir, interact = false)` — suena en la casilla contra la que chocaste, así que la HRTF la panea a ese
  lado: canal `:wall` para el terreno, `:interact` cuando lo golpeado es una persona u objeto ("no puedes
  pasar" frente a "aquí hay algo"). Con el motor inactivo declina.
- `guide(dir, vol)` — coloca el chime `guide_distance` casillas hacia el siguiente paso de la ruta (mínimo
  1, nunca sobre el jugador). Responde en cualquier modo de `sound_nav`: la guía es navegación explícita.
  Solo lo usa el chime de **izquierda/derecha**; arriba y abajo (delante/detrás, que la HRTF no sabe
  colocar) suenan siempre con el cue plano y el tono como pista: agudo = arriba, grave = abajo.

## Earcons no posicionales

Los avisos que NO tienen un punto en el mapa viven en un vocabulario aparte, en `core/audio/spatial.rb`, para
que un sonido signifique siempre lo mismo:

```ruby
# símbolo => [archivo, pitch por defecto]. Se tocan con earcon(name, volume, pitch = nil),
# donde pitch anula el de la tabla (el tic de minijuego mapea la cercanía a tono).
EARCONS = {
  :minigame_tick => ["pa_mg_tick", 100],
  :radar_blip    => ["pa_guide_c", 150]
}
```

Los cues 3D/paneados (pared, guía, tonos de puzle) se quedan **fuera** de esta tabla a propósito: ya
significan "pared", "persona" o "control", y reutilizar uno aquí sonaría a que el sonar dispara en mitad de
un minijuego.

## Glosario de sonidos

**Archivo**: `core/audio/glossary.rb`

La mitad de lo que el mod le dice al jugador no son palabras sino SEÑALES. Aprenderlas encontrándoselas en
el campo es lento y ambiguo (dos pings con un segundo de diferencia: ¿cuál era la puerta?), así que el menú
del mod trae un catálogo navegable: **mover = oyes su nombre, tecla de ayuda = dónde suena, confirmar = lo
reproduce**.

```ruby
# [id, archivo (sin extensión), clave del nombre, clave de la ayuda, pitch]
ENTRIES = [
  [:npc,      "pa3d_npc",    :snd_npc,    :snd_npc_help,    100],
  [:wind_n,   "pa3d_wind_n", :snd_wind_n, :snd_wind_help,   100],
  [:radar,    "pa_guide_c",  :snd_radar,  :snd_radar_help,  150],
  # ... una entrada por señal
]

# play(entry) detiene la previsualización anterior con Audio.se_stop (agua y viento son bucles de varios
# segundos: pasar rápido por la lista los apilaría) y toca la muestra con Spatial.cue(archivo, 100, pitch).
```

Las previsualizaciones son **planas**: centradas, a volumen 100 y por el canal SE normal, porque el objetivo
es memorizar el TIMBRE; el paneo y los volúmenes por categoría son cosa del campo, no de la lista.

Los cuatro vientos tienen una entrada CADA UNO porque son cuatro grabaciones distintas; en cambio los cues
pre-paneados (choque, guía) tienen una sola entrada con el fichero centrado, y su ayuda explica que el lado
lo da el paneo. Un test cruza el catálogo contra `CHANNEL_FILES` y contra `Spatial::EARCONS` en ambas
direcciones: ninguna entrada puede nombrar un fichero que el motor ya no toca, y ningún canal o earcon puede
escaparse del catálogo.

## Tasas de muestreo

El motor abre el dispositivo a su tasa nativa, así que los assets se cargan ya en esa tasa y se evita
remuestrear en tiempo real: 44100 en `accessibility/sounds/`, 48000 en `accessibility/sounds/48000/`.
`wav(name)` devuelve la copia de 48000 cuando el dispositivo va a 48000 **y existe**, si no la de 44100.

## Configuración

```ruby
# core/foundation/config.rb
[:sound_nav,            :full,    :navmode, :audio, ...]          # :off / :basic / :full
[:audio3d_volume,       80,       :vol,  :audio, ...]             # volumen maestro

# Volúmenes por tipo (sub-categoría audio3d_vol)
[:audio3d_npc, 85], [:audio3d_object, 85], [:audio3d_door, 85], [:audio3d_teleporter, 90],
[:audio3d_water, 70], [:audio3d_wind, 55],
[:footstep_volume, 80], [:wall_volume, 80], [:event_volume, 70]

# Cadencia de pings (sub-categoría audio3d_freq)
[:audio3d_freq_npc, 70], [:audio3d_freq_object, 70], [:audio3d_freq_door, 70], [:guide_freq, 55]

# Paredes y oclusión (sub-categoría audio3d_walls)
[:audio3d_occlusion,    :occlude, :occ,   ...]  # :hear / :occlude / :hide
[:audio3d_air,          false,    :flag,  ...]  # absorción del aire
[:audio3d_wall_range,   3,        :tiles, ...]  # alcance de detección de paredes
[:audio3d_wall_falloff, 50,       :vol,   ...]  # pendiente de la caída del viento
[:audio3d_desk_range,   2,        :desk,  ...]  # mostradores audibles en modo :hide (0 lo apaga)

# Avanzado (sub-categoría audio3d_adv)
[:audio3d_range,    12, :tiles, ...]  # alcance del sonar (RANGE por defecto)
[:audio3d_alt_dist,  5, :tiles, ...]  # a qué distancia dos emisores alternan en vez de sonar juntos
```

Los tipos de puzle (`:hazard`, `:trap`, `:control`, `:push`) toman el volumen y la frecuencia de
`audio3d_object`; no tienen ajuste propio.

## Diagnóstico

Los fallos de arranque y de cada paso del escaneo (rescan, walls, winds, water, movers, ping) se escriben
deduplicados en `accessibility/data/hook_loaded.txt`:

```
audio3d boot: native PA3D dll unavailable (arch mismatch or missing native/)
audio3d rescan: NoMethodError: ... @ ...
```

El bloque `diag_audio3d` (Ctrl+Alt+F9, o "Diagnóstico: audio 3D" en el menú de Depuración) añade el estado
vivo: `available?`/`ready`/`active`, tasa y latencia del dispositivo, la configuración, los canales
cargados, los emisores cacheados y el recuento de `gate_report`.

## Referencias

- [Audio3D](../core/audio/audio3d.rb) - el motor posicional
- [Spatial](../core/audio/spatial.rb) - pasos, choques, radar y earcons
- [SoundGlossary](../core/audio/glossary.rb) - el catálogo de señales
- [PA3D_steam](../native/_backend.md) - compilación de la dll

## Próximo

- [Ruby Fundamentals](08_RUBY_FUNDAMENTALS.md)
- [Loading System](09_LOADING_SYSTEM.md)
