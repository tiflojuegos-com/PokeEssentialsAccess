# The real loader/boot.rb, not the harness's copy: its pure functions (manifest to module list, profile to declared
# plugins) against a temp folder. require keeps the two engine passes from evaluating it twice.
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

  eq("una lista llega entera", b.modules_of(%w[a b c], "mf"), %w[a b c])

  eq("un hash devuelve :modules", b.modules_of({ :modules => %w[x y], :plugins => ["p"] }, "mf"), %w[x y])
  eq("un hash sin :modules es nil", b.modules_of({ :plugins => ["p"] }, "mf"), nil)
  eq("un hash con :modules que no es lista es nil", b.modules_of({ :modules => "x" }, "mf"), nil)

  eq("una cadena es nil", b.modules_of("nope", "mf"), nil)
  eq("nil es nil", b.modules_of(nil, "mf"), nil)
end

Suite.define("loader: declared_plugins nunca infiere la lista") do
  b = PokeAccessBoot

  d = BootRig.profile_with("{ :modules => [\"m\"], :plugins => [\"one\", \"two\"] }")
  eq("los declarados salen tal cual", b.declared_plugins(d), %w[one two])

  d = BootRig.profile_with("{ :modules => [\"m\"], :plugins => :auto }")
  eq(":auto se conserva como simbolo", b.declared_plugins(d), :auto)

  d =BootRig.profile_with("{ :modules => [\"m\"] }")
  eq("sin clave :plugins, ninguno", b.declared_plugins(d), [])

  d = BootRig.profile_with("[\"m\"]")
  eq("la forma de lista plana no declara plugins", b.declared_plugins(d), [])

  eq("una carpeta sin manifest no declara nada", b.declared_plugins(File.join(BootRig.tmp, "nada")), [])
end

Suite.define("loader: un manifest roto no tumba el arranque") do
  b = PokeAccessBoot

  d = BootRig.profile_with("{ :modules => [")
  eq("sintaxis rota devuelve nil, no lanza", b.read_manifest(File.join(d, "manifest.rb")), nil)
  eq("y declared_plugins lo absorbe", b.declared_plugins(d), [])
end

Suite.define("loader: los comunes importados van en su orden, una vez, y suman sus plugins") do
  b = PokeAccessBoot
  base = File.join(BootRig.tmp, "common")
  %w[a_common b_common].each do |c|
    FileUtils.mkdir_p(File.join(base, c))
    File.open(File.join(base, c, "manifest.rb"), "w") { |f| f.write("{ :modules => [], :plugins => [\"#{c}_p\"] }") }
  end
  a_dir = "#{base}/a_common"
  b_dir = "#{base}/b_common"

  d = BootRig.profile_with("{ :imports => %w[b_common a_common b_common], :modules => [], :plugins => [\"own\"] }")
  dirs = b.imported_dirs(d, base)
  eq("en el orden del manifest y una sola vez", dirs, [b_dir, a_dir])
  eq("los plugins del perfil primero, luego los de sus comunes", b.declared_plugins(d, dirs), %w[own b_common_p a_common_p])

  d = BootRig.profile_with("{ :imports => %w[a_common], :modules => [], :plugins => :auto }")
  eq("un :auto del perfil sigue siendo :auto", b.declared_plugins(d, b.imported_dirs(d, base)), :auto)

  d = BootRig.profile_with("{ :imports => %w[a_common], :modules => [] }")
  eq("sin :plugins propios, los del comun", b.declared_plugins(d, b.imported_dirs(d, base)), %w[a_common_p])

  d = BootRig.profile_with("{ :imports => %w[x_common a_common], :modules => [] }")
  eq("un import sin carpeta se salta, sin tumbar el resto", b.imported_dirs(d, base), [a_dir])
  log = File.read(File.join(PokeAccess::Paths::DATA, "loader_error.txt")) rescue ""
  truthy("y queda anotado en loader_error.txt", log.include?("import declarado pero ausente: #{base}/x_common"))

  eq("sin :imports, ninguno", b.imported_dirs(BootRig.profile_with("{ :modules => [] }"), base), [])
  eq("ni con la forma de lista plana", b.imported_dirs(BootRig.profile_with("[\"m\"]"), base), [])
end
