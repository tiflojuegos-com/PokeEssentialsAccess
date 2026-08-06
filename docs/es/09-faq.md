# Preguntas frecuentes

Respuestas cortas a lo que se pregunta al empezar, con enlace al documento largo cuando hace falta más. Si
vas a **añadir** algo (un perfil, un lector, un plugin), lee además [05-extender](05-extender.md), que lleva
los pasos completos; esto es el mapa para saber a cuál ir.

## Sobre los juegos y los perfiles

### ¿Qué es un "perfil" y cuándo hace falta uno?

Código específico de UN fangame, en `games/<perfil>/`, cargado después del core. Hace falta cuando el juego
tiene pantallas propias que ningún otro tiene: un minijuego, una tienda rara, un menú reescrito.

Lo que **no** justifica un perfil: que el juego traiga un plugin de terceros. Eso va a `plugins/`, porque el
mismo plugin sale en varios juegos.

### ¿Cómo añado un perfil nuevo?

1. `games/<nombre>/manifest.rb` con `{ :modules => %w[...], :plugins => %w[...] }`.
2. Un `.rb` por módulo, listado en ese manifiesto. Lo que no esté listado no se carga y nadie te avisa.
3. Una entrada en `games/catalog.json` con su `detect` (regex contra el nombre de la carpeta del juego).
   **Cuidado**: `generic` tiene que seguir siendo el ÚLTIMO, porque es el comodín; si lo adelantas, se come
   a los demás.
4. Los textos hablados nuevos, en `lang/es.txt` **y** `lang/en.txt`. Hay un test que falla si falta una
   clave en uno de los dos.

Detalle: los perfiles pueden llevar literales en español a pelo, porque los fangames que cubrimos son solo
en español. El core no.

### ¿Qué es el perfil `generic`?

La reserva para juegos sin perfil propio. No sabe en qué juego corre, así que en vez de nombrar plugins
lleva `:plugins => :auto` y **pregunta al juego** cuáles tiene, usando la tabla de detección.

### Mi juego no lee una pantalla. ¿Por dónde empiezo?

Por el diagnóstico, no por el código. **Ctrl+Alt+F9** vuelca `accessibility/data/diag.txt`; **Ctrl+Alt+F10**
lo habla. Mira, en este orden:

1. La línea `mod:` — ¿la versión instalada es la que crees? Un install desfasado es la causa nº1.
2. `engine:` — `kind`, `version`, `fork` y `caps`. Dice qué era y qué capacidades ve.
3. `plugins:` — `cargados` y `sin_declarar`. **`sin_declarar` es oro**: el juego trae un plugin que
   conocemos y su perfil no lo declara. Esa es la pantalla muda.
4. `plugins_juego:` — el registro propio del juego vía `PluginManager`. Lista también plugins que nosotros
   no conocemos, que es justo el conjunto al que suele pertenecer una pantalla sin lector.
5. `scene=` — la clase de la escena activa. Con ese nombre ya se puede buscar en los scripts del juego.

Los detalles del volcado están en [07-diagnostico](07-diagnostico.md).

### ¿Cómo veo los scripts de mi juego?

```bash
ruby tools/dump_scripts.rb "C:\ruta\al\juego"
```

Escribe `Scripts_dump/` dentro de la carpeta del juego. Funciona con las tres formas en que un juego guarda
su código —`Data/Scripts.rxdata`, un árbol suelto de ficheros, o todo empaquetado en `Game.rgssad`— y no
necesita gemas. Es la carpeta a la que se refiere el resto de la documentación cuando dice "míralo en los
scripts del juego".

## Sobre los hooks

### ¿Cómo engancho una pantalla?

Con la semi-API de `core/input/hooks.rb`, nunca parcheando la clase a mano:

```ruby
PokeAccess::Hooks.after_hook("NombreDeLaClase", :metodo) do |escena, _ret, args|
  # leer y hablar
end
```

Pasa el nombre de la clase **como String**: si esa clase no existe en ese juego, el hook simplemente no se
ata, en vez de reventar la carga.

Las variantes son `before_hook`, `around_hook`, `override` (reemplaza), `read_on_open` y `frame_hook` (una
vez por frame). Cuál usar y por qué, en [03-hooks](03-hooks.md).

### ¿Cuándo pongo `:optional => true`?

Cuando el método puede **no existir a propósito** en algunos juegos. Sin `:optional`, esa ausencia se apunta
en `Hooks.missing`, que por contrato es la lista de **typos**: llenarla de ausencias esperadas es cómo un
typo de verdad deja de notarse.

En `plugins/` es obligatorio en todos los hooks, y hay un test que lo comprueba.

### La pantalla se lee dos veces. ¿Por qué?

Porque el lector genérico de ventanas de comandos también la ve. Recláma la ventana:

```ruby
PokeAccess.dedicate(PokeAccess.sprite(scene, "commands"))
```

Ojo con la trampa que hay detrás: el lector genérico se activa con `active`, no con `visible`, y varias
ventanas de comandos nacen activas aunque estén ocultas. Que tú no la veas no significa que no se esté
leyendo ya.

Y **no** uses `@ignore_input` del motor para callarnos: algunas ventanas Selectable lo usan para su propia
navegación y le congelarías el cursor al jugador.

### El hook se ata pero no se oye nada. ¿Qué pasa?

El fallo más caro del proyecto, y no da error: la clase existe, el método existe, el hook se ata perfecto, y
el ivar que lees se llama distinto en ese juego. Lees `nil` para siempre, sin excepción y sin rastro.

Casos reales: `totalpp` frente a `total_pp`; el sprite `"fightwindow"` frente a `"fightWindow"`; `power`
frente a `base_damage`. Para eso está `PokeAccess.attr_of(obj, :nombre_a, :nombre_b)`, que pregunta por los
dos.

**Regla: un hook instalado no prueba que el dato esté donde crees.** Verifícalo contra los scripts del juego.

### El hook está bien pero solo habla al cerrar la pantalla

Has enganchado el bucle. En Essentials es normal que un método llamado `main`, `pbUpdate` o incluso el
propio `initialize` **sea** el bucle bloqueante de la pantalla: un `after` sobre él no dispara hasta que el
jugador se va. Engancha con `around` para sujetar la escena y lee desde el poll por frame.

## Sobre los plugins de terceros

### ¿Va en `core/`, en `plugins/` o en `games/`?

- **`core/`** — lo que tiene cualquier juego de Essentials. Vanilla.
- **`plugins/`** — un plugin de terceros que instalan algunos juegos.
- **`games/<perfil>/`** — código de UN fangame concreto.

Para decidir si algo es plugin: si la clase está en algún tag de Essentials upstream, es vanilla. Si no,
mira si el juego la trae en una carpeta de plugins (`_PluginScripts/` o una carpeta de addons numerada).
Muchos juegos no separan los plugins en su propia carpeta —los pegan en la lista de scripts—, así que ahí
toca mirarlo a mano.

Dos trampas: un plugin que **reabre** una clase vanilla aparece definiéndola, y el fork de La Base de Sky
mete en su motor cosas que parecen plugins.

### ¿Cómo añado un lector de plugin?

1. `plugins/<nombre-del-plugin>.rb`, con todos los hooks `:optional`.
2. Una línea en `plugins/manifest.rb`: `:<nombre> => "ClaseDelatora"`, o `"Clase#metodo"` si el plugin no
   trae clase propia y reabre una del motor. Si la clase vive dentro de un módulo, escríbela **cualificada**
   (`"Modulo::Clase"`): el censo la indexa igual por su último segmento, pero el gateo en ejecución no sabe
   resolver el nombre a secas.
3. `:plugins => %w[... <nombre>]` en cada perfil que lo trae.
4. Regenerar los censos: `ruby test/static/build_fangame_census.rb` y
   `ruby test/static/build_reader_census.rb`. El segundo es el que pregunta a los volcados si los ivars que
   lees existen en ese juego y si el método que enganchas es el bucle de la pantalla; sin regenerarlo, el
   check falla diciendo justo eso.
5. Un spec que fije **la divergencia** entre las dos copias, no lo obvio.

### ¿Por qué el fichero se llama como el plugin y no como la pantalla?

Para que dos plugins distintos no colisionen nunca. Un plugin = un fichero = una entrada en la tabla, y así
la tabla responde la pregunta correcta: *qué plugins tiene este juego*, no *qué pantallas cubrimos*.

De ahí sale la regla de reparto: **el core se queda el constructor de texto y `plugins/` solo los hooks**.
Qué decir es compartido; cuándo decirlo es del plugin. Dos lectores de la misma pantalla comparten el texto
sin copiarlo.

### ¿Y si dos plugins usan la misma clase?

Hoy no puede pasar: hay un test que falla si dos entradas comparten sonda, o si dos ficheros de `plugins/`
reclaman el mismo par (clase, método). El día que dos plugins lo necesiten de verdad, ese test lo caza, y la
salida es que cada lector **se identifique a sí mismo** —comprobar un rasgo que solo tenga su copia— antes
de hablar.

### Olvidé declarar un plugin en un perfil. ¿Se nota?

Sí, por dos vías. En el juego, el diagnóstico lo lista en `sin_declarar`. Y en el repo hay un test que cruza
cada declaración contra `test/static/plugin_census.txt`, que dice qué juego trae cada plugin: falla en los
dos sentidos, si falta y si sobra.

## Sobre los motores

### ¿Cuántas versiones de Essentials hay que tener en cuenta?

Dos divisiones reales: **gen-6** (v16-17, Ruby 1.8.7, sin `GameData`) y **moderno** (v19+, con `GameData` y
`$player`). Pero hay una franja intermedia que engaña: algunos juegos son **híbridos**, con los NOMBRES de
clase de gen-6 (`PokeBattle_Scene`, `CommandMenuDisplay`) y tripas modernas. Ahí es donde más divergencias
aparecen. Ver [02-motores](02-motores.md).

### ¿Cómo gateo por versión?

No lo hagas. Gatea por **capacidad**:

```ruby
PokeAccess::Engine.has?(:ui_rework)          # capacidad registrada
PokeAccess::Engine.has?("Battle::Scene")     # una clase
PokeAccess::Engine.has?("Battle#pbSideSize") # un metodo de una clase
```

Un número de versión miente en cuanto un fork retroporta algo. Las carpetas `v21/`, `v22/` dicen **dónde
apareció** una capacidad, no cuándo activarla.

### ¿Por qué no puedo usar sintaxis moderna de Ruby en `core/`?

Porque el mod corre bajo **Ruby 1.8.7** dentro de mkxp-z, aunque los tests usen el Ruby del sistema. Nada de
`->`, ni `Array#first(n)` (bug de Essentials 16.3: usa `[0, n]`). Hay un check estático que lo caza.

## Sobre las pruebas

### ¿Cómo corro los tests?

```bash
ruby test/run_all.rb
```

Corre las specs en los dos motores más los checks estáticos (manifiesto, paridad i18n, Ruby 1.8.7). Para
filtrar, pasa un fragmento de ruta: `ruby test/run_all.rb behavior/battle`.

### ¿Cómo sé si mi test sirve de algo?

Rómpelo a propósito. Cambia la implementación para reintroducir el bug y comprueba que el test **falla**. Un
test que pasa con y sin el arreglo no prueba nada, y este proyecto ha tenido varios: uno afirmaba
`t.index("1") && t.index("2")`, que la cadena "01234" satisface igual de bien.

Un caso peor y más frecuente: el fixture describe una forma que el juego no tiene. Entonces el test pasa,
protege una lectura equivocada, y **falla el día que la arreglas**. Si al corregir un lector se te cae un
spec, revisa primero el fixture contra el volcado antes de dar por bueno el spec.

### Instalar en los juegos

Al final de la implementación, nunca a mitad:

```bash
powershell -File installer/install.ps1 -Force
```

Reinstalar encima es actualizar: conserva `settings.ini` y las etiquetas.
