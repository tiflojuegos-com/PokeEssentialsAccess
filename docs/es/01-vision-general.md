# Visión general

Mod de accesibilidad para fangames de Pokémon Essentials sobre mkxp-z: lee la pantalla con un lector de
pantalla, añade navegación por sonido y búsqueda de rutas.

No modifica los scripts del juego. Se inyecta con el `preloadScript` de mkxp-z; desinstalarlo deja el juego
como estaba.

## Cifras

| | |
|---|---|
| Módulos de core | 129, en `core/manifest.rb` |
| Perfiles de juego | 14, en `games/` |
| Lectores de plugin | 29, en `plugins/` |
| Idiomas | `lang/es.txt`, `lang/en.txt` |
| Suite | 1600 (gen-6, estáticos incluidos) + 137 (gamedata) |
| Ruby | 1.8.7 en el juego; el del sistema en los tests |

## Capas

| Capa | Contenido | Regla |
|---|---|---|
| `core/` | Lo que tiene cualquier juego de Essentials | No conoce plugins ni juegos concretos |
| `plugins/` | Lectores de plugins de terceros | Un plugin = un fichero; hooks `:optional` |
| `games/<perfil>/` | Código de un fangame concreto | No referencia otros perfiles |

Dentro de `core/` el layout es **módulo primero**: `core/<módulo>/` con los lectores agnósticos y subcarpetas
`gen6/`, `v21/`, `v22/`, `skyflyer/` solo para lo que difiere por era. Lo compartido por varias eras va a la
raíz del módulo.

Módulos: `audio`, `battle`, `data`, `dialogue`, `field`, `foundation`, `input`, `menus`, `nav`, `party`,
`puzzles`, `speech`, `util`.

## Arranque

`preloadScript` corre **antes** que `Scripts.rxdata`, cuando ninguna clase del juego existe. Por eso
`loader/preload_access.rb` difiere la carga: envuelve `Graphics.update` y evalúa `accessibility/boot.rb`
cuando el bucle principal ya corre (`$scene` asignado, o 120 frames de reserva).

Consecuencia: al cargar el mod, las clases del juego y `PluginManager` ya existen.

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
| Texto hablado | `lang/es.txt`, `lang/en.txt` | [05-extender](05-extender.md) |
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

Los checks estáticos cubren integridad del manifiesto, paridad de claves entre `lang/es.txt` y
`lang/en.txt`, compatibilidad con Ruby 1.8.7, acoplamiento entre capas y consistencia de `plugins/`.

## Instalar

Al final de la implementación, no a mitad:

```bash
powershell -File installer/install.ps1 -Force
```

Reinstalar encima actualiza y conserva `settings.ini` y las etiquetas.
