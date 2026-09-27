# PokeEssentialsAccess

**Español** · [English](README.en.md)

Mod de accesibilidad para fangames de Pokémon. Permite que una persona ciega pueda jugarlos con lector de pantalla.

---

## Índice

- [¿Qué es esto?](#qué-es-esto)
- [¿Qué añade?](#qué-añade)
- [Instalación](#instalación)
- [Juegos soportados](#juegos-soportados)
- [Notas por juego](#notas-por-juego)
- [Teclas del mod](#teclas-del-mod)
- [Estructura del mod](#estructura-del-mod)
- [Documentación](#documentación)
- [Licencia](#licencia)

---

## ¿Qué es esto?

Un mod que accesibiliza fangames hechos sobre **Pokémon Essentials** y ejecutados con **mkxp-z**, desde la era gen-6 (Essentials v16-v17) hasta v22 y sus forks, incluido el motor propio de Reborn, Rejuvenation y Desolation.

No modifica los scripts del juego: se carga con el `preloadScript` de mkxp-z, así que se puede desinstalar y el juego queda como estaba.

Los juegos que todavía usan el reproductor original de RPG Maker XP, como Pokémon Insurgence y Pokémon Uranium, se **convierten** al instalar: junto al ejecutable original, que no se toca, se añade `<nombre del juego> (PokeAccess).exe`, una versión de mkxp-z compilada para el mod. Es el que hay que abrir para jugar con accesibilidad; el botón **Jugar** del launcher ya lo usa solo.

## ¿Qué añade?

- **Lectura de textos**: menús, diálogos (enteros o, si lo prefieres, página a página como los muestra el juego), combate, fichas de Pokémon, Pokédex, mochila, tarjeta de entrenador... La voz sale por **prism**, que habla con NVDA, JAWS, SAPI, UIA, ZDSR y otros lectores, y también envía a la línea braille.
- **Navegación sonora**: sonar 3D binaural (Steam Audio) que sitúa a tu alrededor personas, objetos, puertas, teletransportes, agua y paredes.
- **Búsqueda de rutas**: eliges un objetivo del mapa y el mod calcula la ruta y te guía hasta él con un sonido (sostenido donde hay que mantener la tecla pulsada) o paso a paso. Cuenta con lo que hace el propio juego (hielo, saltos, suelos de flechas, escaleras laterales, corrientes, cascadas, teletransportes dentro del mapa, puentes) y, si no hay camino andando, te dice qué hacer para pasar: surfear, usar una MO, empujar una roca, pulsar acción ante una pared que se escala o bajarte de la bici.
- **Glosario de sonidos**: recorre desde el menú del mod cada señal que oirás, escúchala y lee qué significa.
- **Grabador de sesiones**: guarda en un archivo lo que el mod vio y dijo, para adjuntarlo al reportar un fallo.
- **Marcadores**: marca cualquier casilla con `Ctrl` + `G` y vuelve a ella con el localizador y las guías. Etiquetas, marcadores y nombres de mapa se importan y exportan por separado desde «Personalización», en el menú del mod, y cada fichero lleva el juego al que pertenece para que no se mezclen.
- **Verbosidad**: cuánto se dice al moverse por los menús. **Breve** dice lo esencial (en el equipo, el nombre, los PS y el estado; en combate, el ataque y sus PP), **Media** un poco más y **Completa** todo, como siempre, que es el nivel de serie. La tecla `T` dice lo mismo que siempre en cualquier nivel, y `Ctrl` + `T` repite la fila enfocada entera, tal como la dice Completa. Además puedes crear **esquemas propios** que fijan un nivel para cada tipo de lectura (equipo, movimientos, marcas de la caja de combate, mochila, tienda, cajas, Pokédex y sus fichas, cintas, posiciones, pistas de teclas y descripciones, como las de las opciones o el detalle de un lugar del mapa de región) y compartirlos por archivo; los juegos y plugins con pantallas propias añaden sus lecturas al editor, y cada esquema fija también un nivel para las lecturas que no nombra, así que sirve en cualquier juego. Todo está en «Personalización», en el menú del mod, y hay una tecla para cambiar de nivel sin abrirlo (sin asignar de serie).
- **Historial de mensajes**: `Inicio` y `Fin` recorren lo último que ha dicho el mod, todo junto o por categorías: diálogos, combate, menús, navegación, información y sistema. Cuántos mensajes guarda (300 de serie, hasta 2000) se ajusta en las opciones generales.
- **Remapeo de teclas** de los juegos, desde el menú del mod.
- **Accesibilización de puzzles**. Esto hay que hacerlo juego a juego; de momento hay soporte en:
  - Pokémon Z
  - Pokémon Ópalo

## Instalación

El mod funciona sobre juegos con **mkxp-z** compilado con soporte de `preloadScript`. El launcher lo comprueba antes de instalar y avisa si el juego no lo acepta. Si el juego usa el reproductor original de RPG Maker XP y está en el catálogo, lo convierte como se explica arriba; la desinstalación borra el ejecutable añadido y deja la carpeta como estaba. Si no está en el catálogo, se puede intentar una conversión experimental: el launcher avisa de que el juego puede no arrancar o fallar en algo y pide confirmación.

Conviene que la carpeta del juego tenga una ruta corta, por ejemplo `C:\Juegos\Pokemon Insurgence`. Windows limita la longitud de las rutas, y el launcher avisa si la del juego es demasiado larga: a partir de 200 caracteres en un juego convertido, y a partir de 126 en los que traen su propio mkxp-z antiguo, que con una ruta así arrancan sin cargar el mod.

### Con el instalador gráfico (recomendado)

Descarga `pokeessentialsaccess-launcher.exe` de la [página de releases](https://github.com/tiflojuegos-com/PokeEssentialsAccess/releases); también viene en la raíz del zip de cada versión. Con doble clic se abre una ventana con controles nativos de Windows, manejable con lector de pantalla, que mantiene una lista de tus juegos:

| Acción | Atajo |
|--------|-------|
| Añadir un juego (el perfil se detecta solo) | `Ctrl` + `A` |
| Comprobar si un juego acepta el mod, sin cambiar nada: el seleccionado u otra carpeta | `Ctrl` + `K` |
| Instalar o actualizar el juego seleccionado | `Ctrl` + `I` |
| Actualizar todos los juegos de la lista | `Ctrl` + `U` |
| Jugar al juego seleccionado | `Ctrl` + `J` |
| Editar un juego: nombre, carpeta, perfil y ejecutable | `Ctrl` + `P` |
| Desinstalar el mod de un juego | `Ctrl` + `D` |
| Exportar los datos del jugador a un .zip: ajustes, esquemas de verbosidad, etiquetas, marcadores y nombres de mapa | `Ctrl` + `E` |
| Importar esos datos de un .zip; etiquetas, marcadores y nombres de mapa, solo del mismo juego | `Ctrl` + `M` |
| Quitar un juego de la lista | `Ctrl` + `Q` |
| Opciones del launcher | `Ctrl` + `O` |
| Buscar una versión nueva del propio instalador | `Ctrl` + `B` |

Si arrastras la carpeta de un juego sobre el exe, la ventana se abre en «Añadir juego» con esa carpeta ya elegida.

**Jugar** abre el ejecutable guardado para ese juego. Si la carpeta tiene varios y ninguno es claramente el del juego, pregunta cuál usar, con una casilla para recordarlo; en **Editar**, la opción «Preguntar al jugar» borra lo recordado. En un juego convertido, Jugar usa siempre el ejecutable accesible.

Al actualizar descarga solo los archivos que hayan cambiado y conserva **todo lo que hay en
`accessibility\data`**: tu configuración, tus etiquetas de objetos, los nombres de mapa que te hayas
puesto a mano y tus grabaciones.

### Desde la consola

El mismo exe acepta órdenes. En una consola abierta en su carpeta (cmd, PowerShell o Windows Terminal):

```
.\pokeessentialsaccess-launcher check "D:\Juegos\Pokemon Z"
.\pokeessentialsaccess-launcher install "D:\Juegos\Pokemon Z"
.\pokeessentialsaccess-launcher uninstall "D:\Juegos\Pokemon Z"
```

Sin carpeta, abren un selector. Con `local` delante (`local install`, `local check`…), el mod sale del zip `PokeEssentialsAccess_<versión>.zip` descomprimido en vez de internet. Todas las órdenes, sus opciones y los códigos de salida están en `commands.txt`, en la raíz del zip.

## Juegos soportados

Hay un perfil por juego en `games/`; la lista que usa el launcher para reconocer un juego es [`games/catalog.json`](games/catalog.json).

**Era gen-6** (Essentials v16-v17): Pokémon Z, Pokémon Ópalo, Pokémon Reminiscencia, Pokémon Armonía, Pokémon Realidea, Pokémon Africanus, Pokémon Awakening, Pokémon Soulstones, y los que se convierten al instalar: Pokémon Insurgence y Pokémon Uranium.

**Motor de Reborn** (basado en Essentials v16, con Ruby 3): Pokémon Reborn, Pokémon Rejuvenation y Pokémon Desolation.

**Era GameData** (Essentials v18 en adelante): Pokémon Añil, Pokémon Royal, Pokémon Relict, Pokémon Eternal Emerald, Pokémon Infinite Fusion, Pokémon Infinite Fusion 2 Hoenn, Pokémon Fire Ash, Pokémon Soulstones 2.

Y un **perfil genérico** para cualquier otro fangame sobre Essentials: da toda la accesibilidad común (lectura de menús, diálogos y combate, navegación y rutas) sin los lectores propios de un juego concreto.

## Notas por juego

### Pokémon Insurgence

Insurgence usa de serie tres letras que también son del mod, y una pulsación hace las dos cosas:

| Tecla | En el juego | En el mod |
|-------|-------------|-----------|
| `T` | objeto registrado n.º 4 | información de lo enfocado |
| `M` | acelerar el juego | coordenadas |
| `O` | quitar al Pokémon que te sigue | menú del mod |

Para separarlas, cambia esas acciones del juego a otras teclas en su propia pantalla de controles («Controls», en el menú del título; el mod la lee), o mueve las del mod en su menú, en «Reasignar los controles del juego».

## Teclas del mod

> **Recomendación:** las teclas de serie de algunos juegos son incómodas de alcanzar. Desde el menú del mod (tecla `O`) puedes reasignarlas; una configuración cómoda es el **movimiento** en `W`, `A`, `S`, `D`, **confirmar** en `E` y **cancelar** en `Q`. Mueve también a otras teclas los botones del juego que viven en esas letras: de serie, `A`, `S`, `D`, `Q` y `W` son los botones X, Y, Z, L y R. Una dirección reasignada se suma a la tecla que ya tenía y no silencia nada, así que mientras esos botones sigan en su sitio la misma pulsación hace las dos cosas (en el menú de pausa de Pokémon Z, bajar con `S` abriría el PokeRider).

Estas son las teclas por defecto que añade el mod:

| Tecla | Acción |
|-------|--------|
| `I` | Calcular la ruta hacia el objetivo seleccionado |
| `J` | Objetivo anterior de la lista |
| `L` | Objetivo siguiente de la lista |
| `K` | Anunciar el objetivo seleccionado |
| `T` | Leer la información de lo que tengas enfocado (movimiento, objeto, Pokémon, entrenador...); dentro de un puzzle, su estado |
| `H` | Leer los PS (puntos de salud) de tu equipo en combate |
| `G` | Leer las condiciones del terreno en combate; fuera de combate, el clima y la hora |
| `M` | Leer las coordenadas actuales |
| `O` | Abrir el menú de configuración del mod |
| `Inicio` | Mensaje anterior del historial. La primera vez en cada vista lee el último; después recuerda dónde te quedaste, aunque lleguen mensajes nuevos |
| `Fin` | Mensaje siguiente del historial |

### Modificadores

Combinados con las teclas de arriba amplían su función:

| Combinación | Acción |
|-------------|--------|
| `Shift` + `J` / `L` | Cambiar de categoría de objetivos (personas, objetos, salidas, etc.) |
| `Shift` + `K` | Renombrar el objetivo seleccionado |
| `Ctrl` + `K` | Abrir el menú de etiquetas del objetivo |
| `Shift` + `I` | Activar/desactivar la guía sonora hacia el objetivo |
| `Ctrl` + `I` | Activar/desactivar la guía paso a paso: te va diciendo el tramo actual ("6 arriba") y el siguiente cuando lo completas |
| `Shift` + `T` | Repetir el último diálogo leído |
| `Ctrl` + `T` | Repetir la fila enfocada entera, tal como la dice el nivel Completa, aunque uses otro |
| `Shift` + `H` | Leer los PS del equipo rival |
| `Shift` + `M` | Renombrar el mapa actual |
| `Ctrl` + `M` | Mostrar/ocultar los objetivos a los que no puedes llegar |
| `Ctrl` + `G` | Poner un marcador en la casilla donde estás: te pide el nombre, y en blanco lo borra. Los marcadores tienen su propia categoría en el localizador |
| `Ctrl` + `Inicio` / `Fin` | Ir al primer o al último mensaje del historial |
| `Shift` + `Inicio` / `Fin` | Cambiar de categoría en el historial: todo, diálogos, combate, menús, navegación, información o sistema |

La tecla para **cambiar la verbosidad** (Breve, Media, Completa y tus esquemas) viene sin asignar, porque todas las letras son de algún juego: asígnala en el menú del mod, en «Reasignar los controles del juego», como cualquier otra tecla del mod.

Consejo para seguir las guías: al cambiar de dirección, o al soltar la tecla y volver a pulsarla, la primera pulsación breve solo gira al personaje sin moverlo. Mantén la tecla un instante y darás el paso.

### Atajos globales

| Combinación | Acción |
|-------------|--------|
| `Ctrl` + `Alt` + `F8` | Activar / desactivar el mod (apagado también calla el sonar; al encenderlo se rehace y se reintenta la conexión con el lector) |
| `Ctrl` + `Alt` + `F9` | Volcar un diagnóstico a un archivo (útil por si se encuentran pantallas, puzzles o mapas inaccesibles) |
| `Ctrl` + `Alt` + `F10` | Diagnóstico hablado rápido (útil si algo se queda en silencio) |

## Estructura del mod

Estas son las carpetas principales del repositorio y qué contienen:

| Carpeta | Contenido |
|---------|-----------|
| `core/` | El motor compartido del mod, agnóstico al juego. Se organiza por módulos, y dentro por versión de Essentials (`gen6`, `v21`, `v22`) cuando hace falta. |
| `games/` | Un perfil por juego: sus lectores específicos y su configuración. Cada carpeta es un fangame soportado (`pokemon_z`, `opalo`, `anil`, `relict`, etc.). |
| `plugins/` | Lectores de plugins de terceros que instalan varios fangames. |
| `lang/` | Los textos que habla el mod, traducidos a seis idiomas (`es`, `en`, `fr`, `pt`, `de`, `pl`). El idioma se elige solo (el del sistema, si no el del juego, si no inglés) y se puede fijar desde el menú. |
| `loader/` | El preload que espera al juego y el boot que carga el mod en orden. |
| `native/` | Código C del backend de audio 3D (`pa3d_steam.c` → `PA3D_steam.dll`). |
| `bridge/` | Código C del puente con prism, el que habla con el lector de pantalla. |
| `assets/` | Los sonidos del mod y las bibliotecas nativas por arquitectura (`x86`, `x64`). |
| `test/` | La batería de tests del mod y sus utilidades. |
| `tools/` | Utilidades sueltas, entre ellas el extractor de scripts. |
| `docs/` | La documentación técnica completa (ver abajo). |

El launcher, la ventana y la consola que copian el mod dentro de un juego y lo quitan, tiene su propio repositorio:
[PokeEssentialsAccessInstaller](https://github.com/tiflojuegos-com/PokeEssentialsAccessInstaller). Cada release del mod
lleva su exe.

Dentro de `core/`, cada módulo agrupa una responsabilidad: `foundation/` (base y configuración), `input/` (teclas y enganches), `speech/` (voz, historial de mensajes y verbosidad), `data/` (datos del juego), `nav/` (navegación y rutas), `audio/` (sonido 3D), `menus/`, `battle/`, `party/`, `field/`, `dialogue/`, `puzzles/` y `util/`.

## Documentación

La documentación técnica está en **[`docs/`](docs/)**, completa en español y en inglés.

Buenos puntos de entrada:

- **[docs/es/01-vision-general.md](docs/es/01-vision-general.md)** — qué hay y cómo arranca.
- **[docs/es/09-faq.md](docs/es/09-faq.md)** — las preguntas que salen al empezar.
- **[docs/README.md](docs/README.md)** — índice de los dos idiomas.

Si vas a tocar el código, lee antes las **invariantes** de la visión general: entre otras cosas, `core/` corre bajo Ruby 1.8.7 y eso limita qué sintaxis puedes escribir.

Para leer los scripts de tu propio juego, `ruby tools/dump_scripts.rb "<carpeta del juego>"` los extrae a ficheros `.rb` legibles.

## Licencia

Este proyecto es software libre bajo la licencia **[MIT](LICENSE)**: puedes usarlo, modificarlo y redistribuirlo libremente manteniendo el aviso de copyright.

Las bibliotecas nativas de terceros incluidas en `assets/` conservan sus propias licencias.

El motor de `assets/engine/` es mkxp-z 1.3.0 compilado para el mod (32 bits, Ruby 1.8.7), bajo la **GPL** de mkxp-z. Su código fuente, los parches y los scripts para recompilarlo están en la rama `pokeaccess-1.3` de [tiflojuegos-com/mkxp-z-legacy](https://github.com/tiflojuegos-com/mkxp-z-legacy/tree/pokeaccess-1.3), y las fuentes de sus dependencias, en la release `pokeaccess-1.3.0` de ese mismo repositorio. Las licencias de todo lo que incluye están en `assets/engine/mkxp-z-1.3.0-x86/LICENSES.txt`.
