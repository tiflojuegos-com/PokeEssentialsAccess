# The continue panel as it paints itself, its title left to the command reader, then the saved team it draws as
# icons; and the save on offer, as the multi-save titles write it.

Suite.define("load panel: the continue panel as it paints itself, then the saved team") do
  t = PokeAccess::I18n
  party = [Poke.build(:species => 1)]
  trainer = Object.new
  def trainer.name; "Rojo"; end
  def trainer.numbadges; 3; end
  trainer.define_singleton_method(:party) { party }
  scene = PokemonLoadScene.new
  scene.pbStartScene(["Continuar", "Nuevo juego"], true, trainer, 0, 5)
  eq "top to bottom, the title left out; the team after it", SpeakCapture.log,
     [[["Ruta 5", "Rojo", "Medallas: 3", t.t(:load_party, :list => PokeAccess::Data.species_name(1).to_s)].join(". "), false]]
end

Suite.define("load panel: the save on offer, as the title writes it") do
  scene = PokemonLoadScene.new
  scene.pbDrawCurrentSaveFile("Partida 2", true)
  scene.pbDrawCurrentSaveFile("")
  eq "the autosave marked as painted, an empty name silent", SpeakCapture.log, [["Partida 2 Auto Save", false]]
end

# Awakening's panel puts the save's map at the far end of the route's row, and draws the endings finished as
# icons, which the profile words.
Suite.define("load panel: Awakening's map read off the route's row, and the endings it draws as icons") do
  path = File.join(Harness::ROOT, "games", "awakening", "load_panel.rb")
  eval(File.read(path)[/^module PokeAccess\r?\n.*?^end\r?\n/m], TOPLEVEL_BINDING, path) unless defined?(PokeAccess::AwakeningLoad)
  t = PokeAccess::I18n
  aw = PokeAccess::AwakeningLoad
  pairs = [["Rojo", :positions, 112, 64], ["Capítulo", :positions, 32, 112], ["4", :positions, 192, 112],
           ["Alineación", :positions, 32, 176], ["Orden", :positions, 192, 176], ["Pueblo Raíz", :positions, 376, 176]]
  eq "the route, then the map on a line of its own", aw.lines(pairs),
     ["Rojo", "Capítulo 4", "Alineación Orden", "Pueblo Raíz"]
  eq "the core joins a row whole", PokeAccess::LoadPanel.lines_of(pairs).last, "Alineación Orden Pueblo Raíz"
  eq "the endings finished, in the icons' order", aw.endings(lambda { |n| n != 1 }, lambda { |_p| true }),
     t.t(:awk_endings, :list => [t.t(:awk_end_order), t.t(:awk_end_neutral), t.t(:awk_end_true)].join(", "))
  eq "none finished, nothing", aw.endings(lambda { |_n| false }, lambda { |_p| false }), nil
end
