# Fundamentos de Ruby

El Ruby que hace falta para leer y escribir código de PokeEssentialsAccess. Empieza por la sección 1: es una restricción dura del proyecto y la causa número uno de que a un colaborador nuevo se le rompa un juego entero.

## 1. La restricción: Ruby 1.8.7

Los fangames de la era gen-6 corren sobre **Ruby 1.8.7**. Los modernos, sobre Ruby 3.x. Y `core/` se carga en los dos.

Eso divide el árbol en dos clases de archivo:

| Archivos | Ruby | Qué puedes escribir |
|----------|------|---------------------|
| `core/*/v21/`, `core/*/v22/`, `core/*/skyflyer/` y los perfiles modernos: `anil`, `royal`, `relict`, `infinitefusion`, `infinitefusion_hoenn` | 3.x | Ruby moderno, sin límites |
| **Todo lo demás**: el resto de `core/`, `loader/*.rb` y el resto de perfiles de `games/` | 1.8.7 | Solo sintaxis y métodos de 1.8.7 |

La primera fila solo se carga en juegos modernos, así que ahí no hay problema. La segunda es el **código dual**, y en él una construcción de Ruby 1.9+ no da un aviso: da un `SyntaxError` que **aborta el archivo entero**. Y como el boot anota el error y sigue cargando el resto, el síntoma no es un cierre del juego sino un silencio: un módulo que desaparece y se lleva por delante funciones que parecían no tener nada que ver con él.

La lista exacta de lo que se salta la comprobación es la constante `MODERN`, y está en los dos verificadores (`test/check187.py` y `test/check187_real.rb`): si añades una carpeta que solo cargan los juegos modernos, tiene que entrar en las dos.

### Prohibido en código dual

| No escribas | Escribe |
|-------------|---------|
| `lista.map(&:name)` | `lista.map { \|x\| x.name }` |
| `->(x) { ... }` | `lambda { \|x\| ... }` |
| `obj&.metodo` | `(obj.metodo rescue nil)`, o comprueba antes |
| `n.clamp(0, 100)` | `[[n, 0].max, 100].min` |
| `h.dig(:a, :b)` | `(h[:a] && h[:a][:b])` |
| `v.round(2)` | `(v * 100).round / 100.0` |
| `lista.each_with_object({}) { ... }` | `h = {}; lista.each { ... }; h` |
| `<<~TEXTO` | Concatenar cadenas |
| `%i[a b]` | `[:a, :b]` |
| `h.transform_values`, `.then`, `.tally`, `.filter_map` | Un `each` o un `map` a mano |

### Tres trampas de sintaxis

**1. El punto al principio de línea.** En 1.8.7 el punto tiene que ir al final de la línea anterior:

```ruby
# SyntaxError en 1.8.7
lista.select { |x| x.vivo? }
     .map    { |x| x.nombre }

# Correcto
lista.select { |x| x.vivo? }.
      map    { |x| x.nombre }
```

Esto ya pasó: una constante encadenada así mató `config_menu.rb`, y con el módulo ausente el poll del mapa reventaba en cada frame — sin pasos, sin guía y sin teclas del locator en todos los juegos gen-6.

**2. `rescue` dentro de un bloque.** En 1.8.7 un `rescue` solo puede colgar de `begin`, `def`, `class` o `module`, nunca de un `do`/`{`:

```ruby
# SyntaxError en 1.8.7
lista.each do |x|
  algo(x)
rescue StandardError
  nil
end

# Correcto
lista.each do |x|
  begin
    algo(x)
  rescue StandardError
    nil
  end
end
```

**3. `return` dentro de `define_method`.** El cuerpo es un bloque, y en 1.8.7 un `return` ahí sale del método que lo definió. Se usa `next`:

```ruby
# core/menus/scene_watcher.rb
meta.send(:define_method, :poll) do
  s = @scene
  next unless s          # next, no return
  ...
end
```

### La red que lo verifica

Dos comprobaciones, no una:

1. **`test/check187.py`** — recorre los archivos duales buscando los patrones de arriba (encadenado con punto inicial, `rescue` de bloque, y una lista curada de métodos que no existen en 1.8.7). Rápido, y no necesita nada instalado.
2. **`test/check187_real.rb`** — **parsea** cada archivo dual con un intérprete de Ruby 1.8.7 de verdad (sin ejecutarlo). El verificador de patrones solo reconoce lo que se le ha enseñado; el parser conoce toda la sintaxis del lenguaje. Lo lanza `check187.py` cuando encuentra el intérprete: en `tools/ruby-1.8.7-*/bin/ruby.exe` al lado del repositorio, o donde apunte la variable de entorno `RUBY187`. Si no lo encuentra, lo dice y se queda solo con los patrones.

Las dos van dentro de la batería de tests:

```bash
ruby test/run_all.rb              # tests de los dos motores + comprobaciones estáticas
python test/check187.py           # solo el chequeo 1.8.7, sobre todo el árbol
python test/check187.py core/nav/locator.rb   # o sobre los archivos que has tocado
```

---

Con eso claro, el resto es Ruby normal. Los ejemplos son código real del proyecto.

## 2. Módulos

Casi todo el mod son módulos con métodos de módulo: no hay instancias que crear ni estado que pasar de mano en mano.

```ruby
module PokeAccess
  module Engine
    def self.kind          # se llama PokeAccess::Engine.kind
      gamedata? ? :gamedata : :gen6
    end
  end
end
```

`self.` delante del nombre es lo que lo convierte en método del módulo. Un módulo se puede **reabrir** en otro archivo para añadirle métodos; el mod lo usa para partir un módulo grande en varios archivos: `core/input/input.rb` define `PokeAccess::Keys` y `core/input/diag.rb` reabre el mismo módulo para añadirle la parte de diagnóstico.

## 3. Variables de instancia y memoización

Dentro de un módulo, `@algo` es estado privado del módulo:

```ruby
# core/data/data.rb
def self.active_entry
  @active_entry ||= @providers.max_by { |pr| pr[0] }
end
```

`||=` es "si es `nil`, calcula y guarda; si no, devuelve lo que hay". Es el patrón de caché por defecto del proyecto. Ojo con él si el valor legítimo puede ser `false`: entonces se recalcularía cada vez.

## 4. `attr_accessor` y `class << self`

`attr_accessor :x` crea el getter `x` y el setter `x=`. Para que sean métodos **del módulo** hay que declararlos dentro de `class << self`:

```ruby
# core/foundation/config.rb -- una opción nueva es una fila en SCHEMA, y ya
class << self
  attr_accessor(*(SCHEMA.map { |row| row[0] } + OTHER))
end

SCHEMA.each { |row| send("#{row[0]}=", row[1]) }   # aplica los valores por defecto
```

```ruby
PokeAccess::Config.language = :es
PokeAccess::Config.language        # => :es
```

## 5. Bloques

Un bloque es código que se pasa a un método, entre `{ }` o entre `do ... end`. El mod los usa para registrar cosas: enganches, suscriptores de eventos, invalidadores de caché.

```ruby
# core/battle/gen6/battle_g6.rb -- el bloque corre después del método original
PokeAccess::Hooks.after_hook("PokeBattle_Scene", :pbHPChanged) do |scene, resultado, args|
  # ...
end

# core/nav/locator.rb -- el bloque corre cuando alguien emite el evento
PokeAccess::Events.on(:tags_changed) { (PokeAccess::Locator.rebuild_targets rescue nil) }

# core/foundation/caches.rb -- el bloque corre al invalidar las cachés
PokeAccess::Events.on(:map_changed) { PokeAccess::Caches.reset_all }
```

Quien recibe el bloque lo llama con `yield` o lo captura con `&block` y hace `block.call`:

```ruby
# core/foundation/events.rb
def self.on(name, &block)
  (@handlers[name] ||= []).push(block)
end
```

Los argumentos que recibe cada bloque los fija quien lo llama; los de los enganches están en [04_PATCHING_AND_HOOKS](04_PATCHING_AND_HOOKS.md).

## 6. Procs y lambdas

Un `lambda` es un bloque guardado en una variable. Sirve para decidir una vez algo que se usará muchas veces:

```ruby
# core/nav/pathfinder.rb -- se elige montículo o cola ANTES del bucle de búsqueda,
# para no repetir la misma condición en cada empuje
push  = heaped ? lambda { |item| heap_push(heap, item) } : lambda { |item| queue.push(item) }
empty = heaped ? lambda { heap.empty? }                  : lambda { queue.empty? }

push.call([hw * ((px - tx).abs + (py - ty).abs), 0, px, py, 0])
until empty.call
  # ...
end
```

En 1.8.7 se escribe `lambda { |x| ... }`; la flecha `->` no existe.

## 7. Hash, Array y símbolos

Un símbolo (`:nombre`) es una cadena inmutable y única: se usa como clave, como identificador de tipo y como nombre de método. En código dual, un hash se escribe siempre con la flecha `=>`, no con `clave:` (esa sintaxis es de 1.9+):

```ruby
# core/foundation/config.rb -- acción => código de tecla virtual de Windows
self.keys = {
  :next => 0x4C, :prev => 0x4A, :where => 0x4B, :route => 0x49,
  :info => 0x54, :hp => 0x48, :coords => 0x4D, :field => 0x47,
  :config => 0x4F, :shift => 0x10, :ctrl => 0x11
}
```

Con arrays, los métodos que se ven por todo el proyecto son `each`, `map`, `select`, `detect`, `push` y `max_by`, siempre con bloque explícito (nada de `&:simbolo`):

```ruby
# core/foundation/config.rb
def self.schema_group(group); SCHEMA.select { |row| row[3] == group }; end
def self.schema_row(key);     SCHEMA.find   { |row| row[0] == key }; end

# core/battle/gen6/battle_g6.rb -- el primero que exista de una lista de nombres
mega_setter = ["megaButton=", "mode="].detect { |m| PokeAccess::Engine.has?("FightMenuDisplay##{m}") }
```

Un manifest no es más que un array de cadenas (`%w[...]`) que el boot recorre en orden.

## 8. `send`, `alias_method` y `define_method`

Son las tres piezas con las que está hecho el sistema de enganches.

`send` llama a un método por su nombre:

```ruby
# core/data/data.rb
pr.send(method, arg)   # llama pr.species_name(id), pr.move_name(id)... según el caso
```

`alias_method` le da un segundo nombre a un método, para poder seguir llamándolo después de redefinirlo. `define_method` define un método a partir de un bloque. Juntos son el envoltorio:

```ruby
# core/input/hooks.rb, simplificado -- guardar el original y poner uno nuevo en su sitio
k.send(:alias_method, orig, meth)
k.send(:define_method, meth) do |*args, &blk|
  # ... aquí corren los cuerpos registrados ...
  send(orig, *args, &blk)   # y luego el original
end
```

`*args` recoge todos los argumentos en un array (y al llamar, los vuelve a expandir), así el envoltorio funciona sea cual sea la firma del método original.

Casi nunca tendrás que escribir esto: para eso está `PokeAccess::Hooks`. Pero conviene reconocerlo cuando lo leas.

## 9. Introspección defensiva

El mod lee constantemente los objetos del motor, que no exponen accesores y cuyas variables de instancia cambian de una versión a otra. Por eso no se usa `instance_variable_get` a pelo: hay tres primitivas en `core/foundation/const.rb`, todas seguras en 1.8.7 y todas devuelven un valor por defecto en vez de lanzar.

```ruby
PokeAccess.ivar(menu, :@battler)        # el ivar, o nil si no existe o la lectura falla
PokeAccess.ivar_i(menu, :@index)        # igual, forzado a Integer (por defecto 0)
PokeAccess.sprite(scene, "commandwindow")  # ((@sprites || {})["clave"] rescue nil) en una llamada
```

Lo mismo con las constantes. `Object.const_defined?` rechaza un nombre con `"::"` en 1.8.7, así que se resuelve segmento a segmento:

```ruby
PokeAccess.const_at("Battle::Scene")   # la clase, o nil si falta algún segmento
```

Y para la pregunta que de verdad se hace el código — "¿puede este motor hacer X?" — hay una sola puerta, `Engine.has?`, que acepta un símbolo de capacidad, un nombre de clase o `"Clase#metodo"`:

```ruby
# core/battle/v21/battle_v21.rb
if PokeAccess::Engine.has?("Battle::Scene::MenuBase#setIndexAndMode")
  # ...
end
```

## 10. `rescue`

El mod nunca puede tumbar la partida: un lector que falla se calla, no explota. De ahí que el `rescue` esté por todas partes, en sus dos formas.

```ruby
# forma corta: valor por defecto si la expresión lanza
h = (GFW.call rescue 0)

# forma larga: registrar y degradar
# core/data/data.rb
def self.resolve(method, arg)
  pr = active
  return nil unless pr
  begin
    pr.send(method, arg)
  rescue StandardError => e
    note_error(method, e)    # se anota una vez y sale en el diagnóstico
    nil
  end
end
```

La regla del proyecto: tragar el error **sí**, pero dejando rastro. Para eso están `PokeAccess.log_once(clave, error)` y `PokeAccess.write_marker(texto)`; un fallo silencioso sin rastro es un lector mudo que nadie sabrá diagnosticar.

## 11. Expresiones regulares

Aparecen sobre todo al normalizar texto y al extraer números:

```ruby
# core/foundation/engine.rb -- la versión de Essentials como número
ev.to_s[/\d+(\.\d+)?/].to_f

# core/speech/speech.rb -- colapsar espacios antes de hablar
text = text.to_s.gsub(/\s+/, " ").strip
```

## Resumen

| Concepto | Sintaxis | Dónde lo verás |
|----------|----------|----------------|
| Módulo | `module X; def self.m; end; end` | Todo el mod |
| Memoización | `@x ||= calculo` | Cachés, providers |
| Accesores de módulo | `class << self; attr_accessor :x; end` | `Config` |
| Bloque | `do \|a, b\| ... end` | Hooks, eventos, cachés |
| Lambda | `lambda { \|x\| ... }` | Pathfinder |
| Hash | `{ :clave => valor }` | Config, tablas |
| Llamada dinámica | `obj.send(:metodo, arg)` | Data, Hooks |
| Envoltorio | `alias_method` + `define_method` | Hooks |
| Lectura defensiva | `PokeAccess.ivar(obj, :@x)` | Todos los lectores |
| Puerta por capacidad | `Engine.has?("Clase#metodo")` | Adaptadores por era |
| Error tragado con rastro | `rescue` + `log_once` | Todo el mod |

## Próximo

- [04_PATCHING_AND_HOOKS](04_PATCHING_AND_HOOKS.md) — qué hace `PokeAccess::Hooks` con todo esto.
- [14_EXTENDING](14_EXTENDING.md) — escribir tu primer lector.
- [10_API_REFERENCE](10_API_REFERENCE.md) — los métodos, por módulo.
