# The real loader/boot.rb, not the harness's reimplementation of it.
#
# boot.rb decides what the mod loads, and nothing executed it: only a syntax parse. A mutation sweep put ten
# semantic changes past the whole suite, two of them "the mod loads nothing in any of the thirteen games".
# The blast radius is the largest in the tree and the symptom is total silence, which is the one failure a
# blind player cannot report precisely.
#
# The file is loaded here for its PURE functions -- the ones that map a manifest to a module list and a
# profile to its declared plugins. Nothing that touches disk beyond a temp folder runs, and $LOADED_FEATURES
# keeps it from being evaluated twice when both engine passes reach this file.
require File.expand_path("../../../loader/boot", File.dirname(__FILE__))

module BootRig
  def self.tmp
    d = File.join(Dir.tmpdir, "pea_boot_spec")
    require "fileutils"
    FileUtils.mkdir_p(d)
    d
  end

  # Writes a manifest.rb holding the given literal and returns the folder it lives in.
  def self.profile_with(body)
    d = File.join(tmp, "profile")
    require "fileutils"
    FileUtils.mkdir_p(d)
    File.open(File.join(d, "manifest.rb"), "w") { |f| f.write(body) }
    d
  end
end

require "tmpdir"

Suite.define("loader: modules_of accepts both manifest shapes") do
  b = PokeAccessBoot

  # The plain list every profile started with.
  eq("una lista llega entera", b.modules_of(%w[a b c], "mf"), %w[a b c])

  # The extended shape, which is what all fourteen profiles use today: losing this branch is the mutation
  # that leaves every profile with zero modules and still passes a syntax check.
  eq("un hash devuelve :modules", b.modules_of({ :modules => %w[x y], :plugins => ["p"] }, "mf"), %w[x y])
  eq("un hash sin :modules es nil", b.modules_of({ :plugins => ["p"] }, "mf"), nil)
  eq("un hash con :modules que no es lista es nil", b.modules_of({ :modules => "x" }, "mf"), nil)

  # Anything else is a manifest nobody can load: nil, logged, never an exception into the game.
  eq("una cadena es nil", b.modules_of("nope", "mf"), nil)
  eq("nil es nil", b.modules_of(nil, "mf"), nil)
end

Suite.define("loader: declared_plugins nunca infiere la lista") do
  b = PokeAccessBoot

  d = BootRig.profile_with("{ :modules => [\"m\"], :plugins => [\"one\", \"two\"] }")
  eq("los declarados salen tal cual", b.declared_plugins(d), %w[one two])

  d = BootRig.profile_with("{ :modules => [\"m\"], :plugins => :auto }")
  eq(":auto se conserva como simbolo", b.declared_plugins(d), :auto)

  # Un perfil que no declara nada NO hereda nada: la lista vacia es la respuesta, no "todos".
  d = BootRig.profile_with("{ :modules => [\"m\"] }")
  eq("sin clave :plugins, ninguno", b.declared_plugins(d), [])

  d = BootRig.profile_with("[\"m\"]")
  eq("la forma de lista plana no declara plugins", b.declared_plugins(d), [])

  eq("una carpeta sin manifest no declara nada", b.declared_plugins(File.join(BootRig.tmp, "nada")), [])
end

Suite.define("loader: un manifest roto no tumba el arranque") do
  b = PokeAccessBoot

  # Un manifest con un error de sintaxis se registra y devuelve nil: el mod pierde ESE manifest, no la
  # sesion entera. Que lanzara aqui dejaria al jugador con un juego que no arranca y sin voz que lo diga.
  d = BootRig.profile_with("{ :modules => [")
  eq("sintaxis rota devuelve nil, no lanza", b.read_manifest(File.join(d, "manifest.rb")), nil)
  eq("y declared_plugins lo absorbe", b.declared_plugins(d), [])
end
