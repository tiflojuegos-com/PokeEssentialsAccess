# PokeEssentialsAccess

**Español** · [English](README.en.md)

Mod de accesibilidad para fangames de Pokémon. Permite que una persona ciega pueda jugarlos con lector de pantalla.

---

## Índice

- [¿Qué es esto?](#qué-es-esto)
- [¿Qué añade?](#qué-añade)
- [Instalación](#instalación)
- [Juegos soportados](#juegos-soportados)
- [Teclas del mod](#teclas-del-mod)
- [Estructura del mod](#estructura-del-mod)
- [Documentación](#documentación)
- [Cambios](#cambios)
- [Licencia](#licencia)

---

## ¿Qué es esto?

Un mod que accesibiliza fangames hechos sobre **Pokémon Essentials** y ejecutados con **mkxp-z**, desde la era gen-6 (Essentials v16-v17) hasta v22 y sus forks.

No modifica los scripts del juego: se carga con el `preloadScript` de mkxp-z, así que se puede desinstalar y el juego queda como estaba.

## ¿Qué añade?

- **Lectura de textos**: menús, diálogos, combate, fichas de Pokémon, Pokédex, mochila, tarjeta de entrenador... La voz sale por **prism**, que habla con NVDA, JAWS, SAPI, UIA, ZDSR y otros lectores, y también envía a la línea braille.
- **Navegación sonora**: sonar 3D binaural (Steam Audio) que sitúa a tu alrededor personas, objetos, puertas, teletransportes, agua y paredes.
- **Búsqueda de rutas**: eliges un objetivo del mapa y el mod calcula la ruta y te guía hasta él con un sonido.
- **Glosario de sonidos**: recorre desde el menú del mod cada señal que oirás, escúchala y lee qué significa.
- **Grabador de sesiones**: guarda en un archivo lo que el mod vio y dijo, para adjuntarlo al reportar un fallo.
- **Remapeo de teclas** de los juegos, desde el menú del mod.
- **Accesibilización de puzzles**. Esto hay que hacerlo juego a juego; de momento hay soporte en:
  - Pokémon Z
  - Pokémon Ópalo

## Instalación

El mod solo funciona sobre juegos con **mkxp-z** compilado con soporte de `preloadScript`. Las dos vías lo comprueban antes de instalar y avisan si el juego no lo acepta.

### Con el instalador gráfico (recomendado)

Descarga `pokeessentialsaccess-launcher.exe` de la [página de releases](https://github.com/tiflojuegos-com/PokeEssentialsAccess/releases) y ábrelo. Es una ventana con controles nativos de Windows, manejable con lector de pantalla, que mantiene una lista de tus juegos:

| Acción | Atajo |
|--------|-------|
| Añadir un juego (el perfil se detecta solo) | `Ctrl` + `A` |
| Instalar o actualizar el juego seleccionado | `Ctrl` + `I` |
| Actualizar todos los juegos de la lista | `Ctrl` + `U` |
| Cambiar el perfil de un juego | `Ctrl` + `P` |
| Desinstalar el mod de un juego | `Ctrl` + `D` |
| Buscar una versión nueva del propio instalador | `Ctrl` + `B` |

Al actualizar descarga solo los archivos que hayan cambiado y conserva **todo lo que hay en
`accessibility\data`**: tu configuración, tus etiquetas de objetos, los nombres de mapa que te hayas
puesto a mano y tus grabaciones.

### A mano, con los scripts

Descarga el zip `PokeEssentialsAccess_<versión>.zip` de esa misma página, descomprímelo y usa los archivos de `installer/`. Cada uno abre un selector de carpetas (o puedes arrastrar la carpeta del juego encima):

- **`Comprobar compatibilidad.bat`** — dice si el juego acepta el mod, sin instalar nada.
- **`Instalar mod.bat`** — instala el mod y registra el cargador.
- **`Desinstalar mod.bat`** — lo quita.

## Juegos soportados

Hay un perfil por juego en `games/`; la lista que usan el instalador y el launcher para reconocer un juego es [`games/catalog.json`](games/catalog.json).

**Era gen-6** (Essentials v16-v17): Pokémon Z, Pokémon Ópalo, Pokémon Reminiscencia, Pokémon Armonía, Pokémon Realidea, Pokémon Africanus, Pokémon Awakening.

**Era GameData** (Essentials v18 en adelante): Pokémon Añil, Pokémon Royal, Pokémon Relict, Pokémon Eternal Emerald, Pokémon Infinite Fusion, Pokémon Infinite Fusion 2 Hoenn.

Y un **perfil genérico** para cualquier otro fangame sobre Essentials: da toda la accesibilidad común (lectura de menús, diálogos y combate, navegación y rutas) sin los lectores propios de un juego concreto.

## Teclas del mod

> **Recomendación:** las teclas de serie de algunos juegos son incómodas de alcanzar. Desde el menú del mod (tecla `O`) puedes reasignarlas; una configuración cómoda es el **movimiento** en `W`, `A`, `S`, `D`, **confirmar** en `E` y **cancelar** en `Q`.

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

### Modificadores

Combinados con las teclas de arriba amplían su función:

| Combinación | Acción |
|-------------|--------|
| `Shift` + `J` / `L` | Cambiar de categoría de objetivos (personas, objetos, salidas, etc.) |
| `Shift` + `K` | Renombrar el objetivo seleccionado |
| `Ctrl` + `K` | Abrir el menú de etiquetas del objetivo |
| `Shift` + `I` | Activar/desactivar la guía sonora hacia el objetivo |
| `Shift` + `T` | Repetir el último diálogo leído |
| `Shift` + `H` | Leer los PS del equipo rival |
| `Shift` + `M` | Renombrar el mapa actual |
| `Ctrl` + `M` | Mostrar/ocultar los objetivos a los que no puedes llegar |

### Atajos globales

| Combinación | Acción |
|-------------|--------|
| `Ctrl` + `Alt` + `F8` | Activar / desactivar el mod (y reintentar la conexión con el lector) |
| `Ctrl` + `Alt` + `F9` | Volcar un diagnóstico a un archivo (útil por si se encuentran pantallas, puzzles o mapas inaccesibles) |
| `Ctrl` + `Alt` + `F10` | Diagnóstico hablado rápido (útil si algo se queda en silencio) |

## Estructura del mod

Estas son las carpetas principales del repositorio y qué contienen:

| Carpeta | Contenido |
|---------|-----------|
| `core/` | El motor compartido del mod, agnóstico al juego. Se organiza por módulos, y dentro por versión de Essentials (`gen6`, `v21`, `v22`) cuando hace falta. |
| `games/` | Un perfil por juego: sus lectores específicos y su configuración. Cada carpeta es un fangame soportado (`pokemon_z`, `opalo`, `anil`, `relict`, etc.). |
| `plugins/` | Lectores de plugins de terceros que instalan varios fangames. |
| `lang/` | Los textos que habla el mod, traducidos a seis idiomas (`es`, `en`, `fr`, `pt`, `de`, `pl`). |
| `loader/` | El preload que espera al juego y el boot que carga el mod en orden. |
| `native/` | Código C del backend de audio 3D (`pa3d_steam.c` → `PA3D_steam.dll`). |
| `bridge/` | Código C del puente con prism, el que habla con el lector de pantalla. |
| `installer/` | Los scripts que copian el mod dentro de un juego y lo quitan. |
| `assets/` | Los sonidos del mod y las bibliotecas nativas por arquitectura (`x86`, `x64`). |
| `test/` | La batería de tests del mod y sus utilidades. |
| `docs/` | La documentación técnica completa (ver abajo). |

Dentro de `core/`, cada módulo agrupa una responsabilidad: `foundation/` (base y configuración), `input/` (teclas y enganches), `speech/` (voz), `data/` (datos del juego), `nav/` (navegación y rutas), `audio/` (sonido 3D), `menus/`, `battle/`, `party/`, `field/`, `dialogue/`, `puzzles/` y `util/`.

## Documentación

La documentación técnica está en **[`docs/`](docs/)**, completa en español y en inglés.

Buenos puntos de entrada:

- **[docs/es/01-vision-general.md](docs/es/01-vision-general.md)** — qué hay y cómo arranca.
- **[docs/es/09-faq.md](docs/es/09-faq.md)** — las preguntas que salen al empezar.
- **[docs/README.md](docs/README.md)** — índice de los dos idiomas.

Si vas a tocar el código, lee antes las **invariantes** de la visión general: entre otras cosas, `core/` corre bajo Ruby 1.8.7 y eso limita qué sintaxis puedes escribir.

Para leer los scripts de tu propio juego, `ruby tools/dump_scripts.rb "<carpeta del juego>"` los extrae a ficheros `.rb` legibles.

## Cambios

Las descargas de cada versión están en la [página de releases](https://github.com/tiflojuegos-com/PokeEssentialsAccess/releases). Aquí se anotan las novedades, la versión más reciente primero, con este formato:

<!--
### 0.0.0

- Añadido: ...
- Corregido: ...
- Eliminado: ...
-->

## Licencia

Este proyecto es software libre bajo la licencia **[MIT](LICENSE)**: puedes usarlo, modificarlo y redistribuirlo libremente manteniendo el aviso de copyright.

Las bibliotecas nativas de terceros incluidas en `assets/` conservan sus propias licencias.
