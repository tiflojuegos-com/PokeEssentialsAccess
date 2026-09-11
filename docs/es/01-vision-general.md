# Visión general

Mod de accesibilidad para fangames de Pokémon Essentials sobre mkxp-z: lee la pantalla con un lector de
pantalla, añade navegación por sonido y búsqueda de rutas.

No modifica los scripts del juego. Se inyecta con el `preloadScript` de mkxp-z; desinstalarlo deja el juego
como estaba.

## Cifras

| | |
|---|---|
| Módulos de core | 133, en `core/manifest.rb` |
| Perfiles de juego | 16, en `games/` |
| Lectores de plugin | 49, en `plugins/` |
| Idiomas | 6 (`es`, `en`, `fr`, `pt`, `de`, `pl`), en `lang/` |
| Suite | 2599 (gen-6, estáticos incluidos) + 409 (gamedata) |
| Ruby | 1.8.7 en el juego; el del sistema en los tests |

## Capas

| Capa | Contenido | Regla |
|---|---|---|
| `core/` | Lo que tiene cualquier juego de Essentials | No conoce plugins ni juegos concretos |
| `plugins/` | Lectores de plugins de terceros | Un plugin = un fichero; hooks `:optional` |
| `games/<perfil>/` | Código de un fangame concreto | No referencia otros perfiles |

Dentro de `core/` el layout es **módulo primero**: `core/<módulo>/` con los lectores agnósticos y subcarpetas
`gen6/`, `v21/`, `v22/` solo para lo que difiere por era. Lo compartido por varias eras va a la
raíz del módulo.

Módulos: `audio`, `battle`, `data`, `dialogue`, `field`, `foundation`, `input`, `menus`, `nav`, `party`,
`puzzles`, `speech`, `util`.

## Arranque

`preloadScript` corre **antes** que `Scripts.rxdata`, cuando ninguna clase del juego existe. Por eso
`loader/preload_access.rb` difiere la carga: envuelve `Graphics.update` y evalúa `accessibility/boot.rb`
cuando el bucle principal ya corre (`$scene` asignado, o —de reserva— 120 frames **y** la lista de scripts
terminada, que se sabe porque `Main` ya definió `pbCallTitle`).

Consecuencia: al cargar el mod, las clases del juego y `PluginManager` ya existen.

### Lo que eso cuesta en la primerísima partida

Cuatro juegos (Africanvs, Realidea, Reminiscencia y la build inglesa de Pokémon Z) llaman a
`pbSetUpSystem` a nivel superior, a dos tercios de su lista de scripts, y sin partida guardada esa llamada
**se para ahí a preguntar el idioma**. El mod todavía no está cargado, así que esa lista no se lee.

Es a propósito. Cargar antes significa cargar con el resto de la lista sin leer: medido en Pokémon Z 2.13,
el aviso sale en el script 152 de 235 y **once clases enganchadas aún no existen**, el menú de pausa entre
ellas — mudo el resto de la sesión, que es como se reportó el fallo. Se cambió una pantalla de dos o tres
opciones, una vez por instalación y reversible desde las opciones del mod, por un menú de pausa que sí
habla siempre.

Al jugador: en esa primera pantalla, pulsa Intro para aceptar la opción por defecto; el idioma del mod se
cambia después desde su menú de configuración.

## Orden de carga

```
loader/boot.rb
  1. core/manifest.rb           lista ordenada de módulos, sin .rb
  2. plugins/ declarados        los que el perfil nombra, o :auto
  3. games/<perfil>/manifest.rb
```

Los tres manifiestos son literales Ruby; `read_manifest` los evalúa, porque RGSS no trae parser JSON.

Formato del manifiesto de perfil, dos formas admitidas:

```ruby
%w[modulo_a modulo_b]                                   # solo módulos

{ :modules => %w[modulo_a], :plugins => %w[tip_cards] }  # módulos + plugins declarados
{ :modules => %w[modulo_a], :plugins => :auto }          # solo el perfil generic
```

Un módulo que no esté en el manifiesto **no se carga** y nada avisa. Un plugin declarado que no exista se
apunta en el log y se salta: una instalación a medias cuesta una pantalla, no el mod entero.

## Dónde está cada cosa

| Necesitas | Fichero | Documento |
|---|---|---|
| Enganchar un método del juego | `core/input/hooks.rb` | [03-hooks](03-hooks.md) |
| Hablar texto | `core/speech/speech.rb` | [04-lectores](04-lectores.md) |
| Leer datos sin saber la era | `core/data/data.rb` | [04-lectores](04-lectores.md) |
| Saber qué motor corre | `core/foundation/engine.rb` | [02-motores](02-motores.md) |
| Introspección defensiva | `core/foundation/const.rb` | [08-referencia](08-referencia.md) |
| Evitar lecturas repetidas | `core/menus/cursor.rb` | [04-lectores](04-lectores.md) |
| Texto hablado | los seis `lang/*.txt` | [05-extender](05-extender.md) |
| Rutas y sonar | `core/nav/`, `core/audio/` | [06-navegacion](06-navegacion.md) |
| Diagnosticar un fallo | `core/input/diag.rb` | [07-diagnostico](07-diagnostico.md) |

## Invariantes

1. **La accesibilidad manda.** Ante la duda, hablar de más antes que callar.
2. **Nada rompe el juego.** Todo lector va bajo `rescue`; un fallo cuesta una línea no hablada, no el frame.
3. **Gate por capacidad, no por versión.** Ver [02-motores](02-motores.md).
4. **El texto hablado va a `lang/`.** Excepción: los perfiles de `games/`, de fangames solo en español, que
   admiten literales.
5. **Ruby 1.8.7 en `core/`.** Hay un check estático que lo verifica.

## Tests

```bash
ruby test/run_all.rb                    # los dos motores + checks estáticos
ruby test/run_all.rb behavior/battle    # filtra por fragmento de ruta
```

Los checks estáticos cubren integridad del manifiesto, paridad de claves entre los seis ficheros de
`lang/`, compatibilidad con Ruby 1.8.7, acoplamiento entre capas, consistencia de `plugins/` y dos censos
construidos desde los juegos decompilados: la aridad y los nombres de parámetro de cada método enganchado
(bucles incluidos) y la cobertura por era de cada nombre de la API de Essentials que llama el core compartido.

## Instalar

Al final de la implementación, no a mitad:

```bash
powershell -File installer/install.ps1 -Force
```

Reinstalar encima actualiza y conserva `settings.ini` y las etiquetas.
