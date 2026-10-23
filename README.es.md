# PokeEssentialsAccess

**Español** · [English](README.en.md)

Mod de accesibilidad para fangames de Pokémon hechos con Pokémon Essentials. Con él, una persona ciega puede jugarlos
con su lector de pantalla.

---

## Índice

- [Qué es](#qué-es)
- [Qué hace](#qué-hace)
- [Instalación](#instalación)
- [Juegos soportados](#juegos-soportados)
- [Notas por juego](#notas-por-juego)
- [Teclas](#teclas)
- [Estructura del repositorio](#estructura-del-repositorio)
- [Documentación técnica](#documentación-técnica)
- [Licencia](#licencia)

---

## Qué es

Un mod que hace accesibles los fangames de **Pokémon Essentials** que funcionan con **mkxp-z**. Cubre desde la era
gen-6 (Essentials v16 y v17) hasta la v22 y sus variantes, incluido el motor de Reborn, Rejuvenation y Desolation.

No cambia los scripts del juego. Se carga con el `preloadScript` de mkxp-z, así que al desinstalarlo el juego queda
como estaba.

Algunos juegos siguen usando el reproductor original de RPG Maker XP, como Pokémon Insurgence y Pokémon Uranium. Al
instalar el mod, el launcher los **convierte**: deja el ejecutable original como está y añade a su lado
`<nombre del juego> (PokeAccess).exe`, una versión de mkxp-z compilada para el mod. Ese es el que hay que abrir para
jugar con accesibilidad, y el botón **Jugar** del launcher ya lo usa.

## Qué hace

### Lectura

- Lee los menús, los diálogos, los combates, las fichas de Pokémon, la Pokédex, la mochila, la tarjeta de
  entrenador y las pantallas propias de cada juego y de muchos plugins.
- Los diálogos se leen enteros o, si lo prefieres, página a página, como los muestra el juego.
- Lee también los minijuegos de serie de Essentials: Voltorb Flip, la tragaperras, la minería, el duelo y el puzle de
  piezas.
- La voz sale por **prism**, que habla con NVDA, JAWS, SAPI, UIA, ZDSR y otros lectores, y también manda el texto a
  la línea braille.

### Verbosidad

Elige cuánto se dice al moverte por los menús:

- **Breve**: lo esencial. En el equipo, el nombre, los PS y el estado; en combate, el ataque y sus PP.
- **Media**: un poco más.
- **Completa**: todo. Es el nivel de serie.

En cualquier nivel, `T` da el detalle de lo que tienes enfocado y `Ctrl` + `T` repite la fila entera, como la diría
Completa.

También puedes crear **esquemas propios**. Un esquema fija un nivel para cada tipo de lectura (equipo, movimientos,
mochila, tienda, cajas, Pokédex, posiciones, pistas de teclas, descripciones…) y otro para todo lo que no nombra, así
que sirve en cualquier juego. Los juegos y los plugins con pantallas propias añaden sus lecturas al editor, y los
esquemas se pueden compartir por archivo.

Todo está en «Personalización», en el menú del mod. La tecla para cambiar de nivel sin abrir el menú viene sin
asignar (ver [Teclas](#teclas)).

### Historial de mensajes

`Inicio` y `Fin` recorren lo último que ha dicho el mod, todo junto o por categorías: diálogos, combate, menús,
navegación, información y sistema. Guarda 300 mensajes de serie, y hasta 2000 si lo cambias en «Opciones generales».

### Navegación por sonido

- Un sonar 3D binaural (Steam Audio) sitúa a tu alrededor personas, objetos, puertas, teletransportes, agua y
  paredes.
- El **radar de proximidad** da un pitido corto cuando tienes justo delante algo con lo que puedes interactuar.
- En «Sonidos activados» puedes apagar cada sonido por separado.
- El **glosario de sonidos**, en el menú del mod, te deja escuchar cada sonido y leer qué significa.

### Objetivos y rutas

- El **localizador** recorre por categorías lo que hay en el mapa: personas, objetos, salidas y más.
- Eliges un objetivo y el mod calcula la ruta y te guía hasta él con un sonido o paso a paso.
- La ruta cuenta con lo que hace el juego: hielo, saltos, suelos de flechas, escaleras laterales, corrientes,
  cascadas, teletransportes dentro del mapa y puentes.
- Si no hay camino a pie, te dice qué hacer para pasar: surfear, usar una MO, empujar una roca, pulsar Acción ante una
  pared que se escala o bajarte de la bici.

En «Opciones de navegación y del buscador de rutas» decides cómo funciona la lista de objetivos:

- **Ocultar objetivos**: ninguno, los que no tienen ruta, o además los de otras salas cuando un mapa junta varias.
- **Ocultar objetos no interactuables**: deja fuera los objetos de decorado con los que no se puede hacer nada.
- **Orden de los objetivos**: por distancia directa, por distancia a pie o fijo.
- **Numeración de objetivos**: desactivada (se dice el puesto en la lista), dinámica (cada objetivo conserva su
  número mientras sigues en el mapa) o estática (cuenta también los ocultos, así que puede saltarse números).
- Si se nombran los **objetos que se pueden recoger**, los **entrenadores** sin nombre por su clase y diciendo si ya
  los venciste, los **Pokémon** del mapa por su especie y los **carteles** por lo que dice su texto.
- **Avisos de superficie**: dice el terreno que pisas cuando cambia.

### Etiquetas, marcadores y nombres de mapa

- Puedes poner nombre a un objetivo con `Shift` + `K` y al mapa con `Shift` + `M`.
- `Ctrl` + `K` abre el menú del objetivo: renombrarlo, quitarle el nombre, cambiarlo de categoría u ocultarlo.
- `Ctrl` + `G` pone un **marcador** en la casilla donde estás. Los marcadores tienen su propia categoría en el
  localizador y se siguen con las mismas guías.
- En «Personalización» están las listas **Etiquetas de objetos**, **Marcadores** y **Nombres de mapa**. Desde ellas
  puedes renombrar o borrar cada entrada y volver a mostrar un objeto que ocultaste.
- Cada lista se importa y se exporta por separado. Cada archivo lleva el juego al que pertenece, para que no se
  mezclen.

### Puzles

- La ruta cuenta con las mecánicas de serie, como las rocas que se empujan con Fuerza, en cualquier juego.
- Los puzles propios de un juego se preparan uno a uno. De momento hay soporte en Pokémon Z y Pokémon Ópalo. Dentro de
  un puzle, `T` dice su estado.
- La opción «Ayuda en puzles», apagada de serie, da las pistas y las rutas que los resuelven.

### Otras herramientas

- **Remapeo de teclas**: en «Reasignar los controles del juego» cambias las teclas del juego y las del mod.
- **Grabador de sesiones**: «Grabar sesión», en «Depuración», guarda en un archivo lo que el mod vio y dijo, para
  adjuntarlo cuando informes de un fallo.

## Instalación

El mod funciona en los juegos cuyo **mkxp-z** admite `preloadScript`. El launcher lo comprueba antes de instalar y te
avisa si el juego no lo admite.

- Si el juego usa el reproductor original de RPG Maker XP y está en el catálogo, el launcher lo convierte como se
  explica arriba. Al desinstalar, borra el ejecutable añadido y deja la carpeta como estaba.
- Si no está en el catálogo, puedes probar una conversión experimental. El launcher te avisa de que el juego puede no
  arrancar o fallar en algo, y te pide confirmación.

Pon el juego en una carpeta de ruta corta, por ejemplo `C:\Juegos\Pokemon Insurgence`. Windows limita la longitud de
las rutas, y el launcher avisa cuando la del juego es demasiado larga: desde 200 caracteres en un juego convertido, y
desde 126 en los juegos que traen un mkxp-z antiguo, que con una ruta así arrancan sin cargar el mod.

### Con el launcher (recomendado)

Descarga `pokeessentialsaccess-launcher.exe` de la
[página de releases](https://github.com/tiflojuegos-com/PokeEssentialsAccess/releases). También viene en la raíz del
zip de cada versión. Al abrirlo verás una ventana con controles nativos de Windows, que se maneja con lector de
pantalla y guarda la lista de tus juegos:

| Acción | Atajo |
|--------|-------|
| Añadir un juego (el perfil se detecta solo) | `Ctrl` + `A` |
| Comprobar si un juego admite el mod, sin cambiar nada: el seleccionado u otra carpeta | `Ctrl` + `K` |
| Instalar o actualizar el juego seleccionado | `Ctrl` + `I` |
| Actualizar todos los juegos de la lista | `Ctrl` + `U` |
| Jugar al juego seleccionado | `Ctrl` + `J` |
| Editar un juego: nombre, carpeta, perfil y ejecutable | `Ctrl` + `P` |
| Desinstalar el mod de un juego | `Ctrl` + `D` |
| Exportar tus datos a un .zip: ajustes, esquemas de verbosidad, etiquetas, marcadores y nombres de mapa | `Ctrl` + `E` |
| Importar esos datos de un .zip; las etiquetas, los marcadores y los nombres de mapa, solo del mismo juego | `Ctrl` + `M` |
| Quitar un juego de la lista | `Ctrl` + `Q` |
| Opciones del launcher | `Ctrl` + `O` |
| Buscar una versión nueva del propio launcher | `Ctrl` + `B` |

Si arrastras la carpeta de un juego sobre el exe, la ventana se abre en «Añadir juego» con esa carpeta ya elegida.

**Jugar** abre el ejecutable guardado para ese juego. Si en la carpeta hay varios y ninguno es claramente el del
juego, te pregunta cuál usar y puedes marcar que lo recuerde; para olvidarlo, usa «Preguntar al jugar» en **Editar**.
En un juego convertido, Jugar abre siempre el ejecutable accesible.

Al actualizar, el launcher descarga solo los archivos que han cambiado y conserva todo lo que hay en
`accessibility\data`: tus ajustes, tus esquemas de verbosidad, tus etiquetas, marcadores y nombres de mapa, y tus
grabaciones.

### Desde la consola

El mismo exe acepta órdenes. En una consola abierta en su carpeta (cmd, PowerShell o Windows Terminal):

```
.\pokeessentialsaccess-launcher check "D:\Juegos\Pokemon Z"
.\pokeessentialsaccess-launcher install "D:\Juegos\Pokemon Z"
.\pokeessentialsaccess-launcher uninstall "D:\Juegos\Pokemon Z"
```

Sin carpeta, abren un selector. Con `local` delante (`local install`, `local check`…), el mod sale del zip
`PokeEssentialsAccess_<versión>.zip` descomprimido en lugar de internet. Todas las órdenes, sus opciones y los códigos
de salida están en `commands.txt`, en la raíz del zip.

## Juegos soportados

Cada juego tiene su perfil en `games/`. La lista con la que el launcher reconoce los juegos es
[`games/catalog.json`](games/catalog.json).

- **Era gen-6** (Essentials v16 y v17): Pokémon Z, Pokémon Ópalo, Pokémon Reminiscencia, Pokémon Armonía, Pokémon
  Realidea, Pokémon Africanus, Pokémon Awakening, Pokémon Soulstones y Pokémon HGSS: Sevii Islands, además de los que
  se convierten al instalar: Pokémon Insurgence y Pokémon Uranium.
- **Motor de Reborn** (basado en Essentials v16, con Ruby 3): Pokémon Reborn, Pokémon Rejuvenation y Pokémon
  Desolation.
- **Era GameData** (Essentials v18 en adelante): Pokémon Añil, Pokémon Royal, Pokémon Relict, Pokémon Eternal
  Emerald, Pokémon Grueling Gold, Pokémon Infinite Fusion, Pokémon Infinite Fusion 2 Hoenn, Pokémon Fire Ash y
  Pokémon Soulstones 2.

Para cualquier otro fangame de Essentials hay un **perfil genérico**. Da toda la accesibilidad común (menús,
diálogos, combate, navegación y rutas), pero sin los lectores hechos para un juego concreto.

## Notas por juego

### Pokémon Insurgence

Insurgence usa de serie tres letras que también son del mod, y una pulsación hace las dos cosas:

| Tecla | En el juego | En el mod |
|-------|-------------|-----------|
| `T` | Objeto registrado n.º 4 | Detalle de lo enfocado |
| `M` | Acelerar el juego | Coordenadas |
| `O` | Quitar al Pokémon que te sigue | Menú del mod |

Para separarlas, pasa esas acciones del juego a otras teclas en su pantalla de controles («Controls», en el menú del
título, que el mod lee), o mueve las del mod en «Reasignar los controles del juego».

### Pokémon HGSS: Sevii Islands

En Sevii, `Shift` es a la vez el acelerador del juego y el modificador del mod. Cada combinación con `Shift`
(`Shift` + `T`, `Shift` + `H`…) acelera el juego un instante, y el mod dice «Velocidad rápida» y «Velocidad normal»,
cortando lo que estaba diciendo. Para evitarlo, mueve el «Modificador mayúsculas» del mod a otra tecla en
«Reasignar los controles del juego».

## Teclas

> **Recomendación:** las teclas de serie de algunos juegos quedan lejos. Puedes cambiarlas desde el menú del mod
> (tecla `O`). Una distribución cómoda es el **movimiento** en `W`, `A`, `S` y `D`, **Aceptar** en `E` y **Cancelar**
> en `Q`. Si lo haces, pasa también a otras teclas los botones del juego que viven en esas letras: de serie, `A`, `S`,
> `D`, `Q` y `W` son los botones X, Y, Z, L y R. Una dirección reasignada se suma a la tecla que ya tenía y no la
> anula, así que, mientras esos botones sigan en su sitio, la misma pulsación hace las dos cosas. Por ejemplo, en el
> menú de pausa de Pokémon Z, bajar con `S` abriría el PokeRider.

### Teclas del mod

| Tecla | Qué hace |
|-------|----------|
| `J` | Objetivo anterior de la lista |
| `L` | Objetivo siguiente de la lista |
| `K` | Dice el objetivo seleccionado: su nombre, su número, la dirección y los pasos que hay |
| `I` | Calcula la ruta hasta el objetivo y la dice |
| `T` | Detalle de lo enfocado: movimiento, objeto, Pokémon, entrenador… En un puzle, su estado. En un terreno que te mueve, como el hielo o las flechas, ese movimiento y adónde lleva cada dirección |
| `H` | En combate, los PS de tu equipo, y en la Zona Safari, las Safari Balls que quedan. Fuera de combate, cada Pokémon del equipo con sus PS y su estado |
| `G` | En combate, el campo, el clima, el terreno y las condiciones de cada lado. Fuera de combate, el clima, la hora del juego y el momento del día |
| `M` | El mapa y tus coordenadas |
| `O` | Abre el menú del mod |
| `Inicio` | Mensaje anterior del historial. La primera vez en cada vista lee el último; después recuerda dónde te quedaste, aunque lleguen mensajes nuevos |
| `Fin` | Mensaje siguiente del historial |

### Con modificadores

| Combinación | Qué hace |
|-------------|----------|
| `Shift` + `J` / `L` | Cambia de categoría de objetivos, dice cuántos tiene y selecciona el primero |
| `Shift` + `K` | Pone nombre al objetivo. Escape o un nombre en blanco cancelan |
| `Ctrl` + `K` | Abre el menú del objetivo: renombrar, quitar el nombre, cambiar de categoría u ocultar. Sobre un marcador, abre el del marcador |
| `Shift` + `I` | Enciende o apaga la guía sonora hacia el objetivo |
| `Ctrl` + `I` | Enciende o apaga la guía paso a paso, que dice el tramo actual («6 arriba») y el siguiente cuando lo completas |
| `Shift` + `T` | Repite el último diálogo |
| `Ctrl` + `T` | Repite entera la fila enfocada, como la diría el nivel Completa |
| `Shift` + `H` | Los PS del equipo rival |
| `Shift` + `M` | Pone nombre al mapa actual |
| `Ctrl` + `M` | Cambia qué objetivos se ocultan: ninguno, los que no tienen ruta, o además los de otras salas |
| `Ctrl` + `G` | Pone un marcador donde estás y te pide su nombre. Escape o un nombre en blanco cancelan. Se borra desde `Ctrl` + `K` o desde la lista de marcadores |
| `Ctrl` + `Inicio` / `Fin` | Primer o último mensaje del historial |
| `Shift` + `Inicio` / `Fin` | Cambia la categoría del historial: todo, diálogos, combate, menús, navegación, información o sistema |

La tecla para **cambiar la verbosidad** (Breve, Media, Completa y tus esquemas) viene sin asignar, porque todas las
letras las usa algún juego. Asígnala en «Reasignar los controles del juego», como cualquier otra tecla del mod.

Para seguir las guías: al cambiar de dirección, o al soltar la tecla y volver a pulsarla, la primera pulsación breve
solo gira al personaje. Mantén la tecla un instante para dar el paso.

### En el mapa de la región

Con el mapa de la región abierto, `J`, `L`, `I` y `K` llevan el cursor al punto de vuelo más cercano hacia la
izquierda, la derecha, arriba y abajo. En Pokémon Royal estos saltos están desactivados.

### En el menú del mod

El menú se maneja con las flechas y con Aceptar y Cancelar del juego. Izquierda y Derecha cambian el valor de la
fila. Además:

- `T` dice la ayuda de la fila.
- `Ctrl` + `T` dice la fila, su valor y su ayuda.

### Atajos globales

| Combinación | Qué hace |
|-------------|----------|
| `Ctrl` + `Alt` + `F8` | Enciende o apaga el mod. Apagado, también calla el sonar; al encenderlo, lo rehace y vuelve a conectar con el lector |
| `Ctrl` + `Alt` + `F9` | Guarda un diagnóstico en un archivo, útil si encuentras una pantalla, un puzle o un mapa que no es accesible |
| `Ctrl` + `Alt` + `F10` | Diagnóstico hablado rápido, útil si algo se queda en silencio |

## Estructura del repositorio

| Carpeta | Contenido |
|---------|-----------|
| `core/` | El núcleo común a todos los juegos, por módulos. Algunos tienen una subcarpeta por versión de Essentials (`gen6`, `v21`, `v22`) |
| `games/` | Un perfil por juego, con sus lectores y su configuración |
| `plugins/` | Los lectores de plugins de terceros que usan varios fangames |
| `lang/` | Los textos que dice el mod, en seis idiomas (`es`, `en`, `fr`, `pt`, `de`, `pl`). El idioma se elige solo (el del sistema, si no el del juego, si no el inglés) y se puede fijar en el menú |
| `loader/` | El preload, que espera al juego, y el arranque, que carga el mod en orden |
| `native/` | El código C del audio 3D, del que sale `PA3D_steam.dll` |
| `bridge/` | El código C del puente con prism, que habla con el lector de pantalla |
| `assets/` | Los sonidos del mod, las bibliotecas nativas por arquitectura (`x86`, `x64`) y el mkxp-z de los juegos convertidos |
| `test/` | Los tests del mod y sus utilidades |
| `tools/` | Utilidades sueltas, como el extractor de scripts |
| `docs/` | La documentación técnica |

Los módulos de `core/` son `foundation/` (base y ajustes), `util/`, `data/` (datos del juego), `speech/` (voz,
historial y verbosidad), `input/` (teclas y ganchos), `menus/`, `battle/`, `party/`, `dialogue/`, `field/`, `world/`
(terreno, pasabilidad y eventos), `routes/` (el planificador de rutas), `nav/` (localizador y guías), `sound/` (audio
3D y sonidos) y `puzzles/`.

El launcher, la ventana y la consola que meten el mod en un juego y lo quitan, tiene su propio repositorio:
[PokeEssentialsAccessInstaller](https://github.com/tiflojuegos-com/PokeEssentialsAccessInstaller). Cada release del
mod lleva su exe.

## Documentación técnica

La documentación técnica está en inglés, en **[`docs/`](docs/README.md)**:

- [docs/README.md](docs/README.md): el índice, con la arquitectura, las guías paso a paso y la referencia.
- [docs/architecture/overview.md](docs/architecture/overview.md): qué hay y cómo arranca.

Antes de tocar el código, lee las [reglas de diseño](docs/architecture/overview.md#design-rules) de esa visión
general. Entre otras cosas, el código que carga un juego con Ruby 1.8.7 tiene que seguir Ruby 1.8.7, y eso limita la
sintaxis que puedes usar.

Para leer los scripts de tu propio juego, `ruby tools/dump_scripts.rb "<carpeta del juego>"` los extrae a archivos
`.rb` legibles.

## Licencia

Este proyecto es software libre con licencia **[MIT](LICENSE)**: puedes usarlo, modificarlo y redistribuirlo
siempre que mantengas el aviso de copyright.

Las bibliotecas nativas de terceros que hay en `assets/` conservan sus propias licencias.

El motor de `assets/engine/` es mkxp-z 1.3.0 compilado para el mod (32 bits, Ruby 1.8.7), con la **GPL** de mkxp-z.
Su código fuente, los parches y los scripts para recompilarlo están en la rama `pokeaccess-1.3` de
[tiflojuegos-com/mkxp-z-legacy](https://github.com/tiflojuegos-com/mkxp-z-legacy/tree/pokeaccess-1.3), y las fuentes
de sus dependencias, en la release `pokeaccess-1.3.0` de ese repositorio. Las licencias de todo lo que incluye están
en `assets/engine/mkxp-z-1.3.0-x86/LICENSES.txt`.
