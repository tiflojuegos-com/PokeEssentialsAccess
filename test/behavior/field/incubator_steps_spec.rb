# An incubator slot says the steps written under the egg and the sentence painted beside the grid, as the screen
# writes them; the reader's own hint only where none is painted.
Suite.define("incubator: the steps under the egg and the sentence beside the grid, as the screen writes them") do
  t = PokeAccess::I18n
  egg = Poke.build(:name => "Huevo")
  egg.define_singleton_method(:eggsteps) { 1 }
  had = $PokemonGlobal.respond_to?(:eggs)
  $PokemonGlobal.define_singleton_method(:eggs) { [egg, nil] }
  begin
    scene = World.stub_scene(:@index => 0)
    eq "the painted sentence after the steps", PokeAccess::Incubator.text(scene, "<c3=FFFFFF>El huevo esta listo.</c3>"),
       t.t(:hatch_slot_egg, :n => 1, :state => "#{t.t(:hatch_steps, :n => 1)}. El huevo esta listo.")
    eq "and the reader's band where nothing was painted", PokeAccess::Incubator.text(scene, nil),
       t.t(:hatch_slot_egg, :n => 1, :state => "#{t.t(:hatch_steps, :n => 1)}. #{t.t(:hatch_soon)}")
    scene2 = World.stub_scene(:@index => 1)
    eq "an empty slot is just free", PokeAccess::Incubator.text(scene2, "Selecciona una incubadora."),
       t.t(:hatch_slot_empty, :n => 2)

    SpeakCapture.clear
    PokeAccess::Incubator.arm
    drawFormattedTextEx(nil, 0, 10, 200, "El huevo esta listo.")
    PokeAccess::Incubator.announce(scene)
    eq "announced after a redraw, from the capture, waiting on the first read", SpeakCapture.log.map { |l| l[1] }, [false]
    match "with the sentence it painted", SpeakCapture.lines.first.to_s, /El huevo esta listo\./
  ensure
    class << $PokemonGlobal; remove_method :eggs; end unless had
  end
end

# Royal's upgradable incubator: the header is the level the screen prints above the grid.
Suite.define("incubator: Royal's upgraded incubator says its level before the first slot") do
  plain = PokeAccess::Incubator.method(:header)
  old = $PokemonGlobal
  begin
    load File.expand_path("../../../games/royal/incubator_level.rb", File.dirname(__FILE__))
    g = Object.new
    def g.version_incubadora; 2; end
    $PokemonGlobal = g
    eq "the level the screen prints above the grid", PokeAccess::Incubator.header(Object.new),
       PokeAccess::I18n.t(:hatch_level, :n => 2)
  ensure
    $PokemonGlobal = old
    PokeAccess::Incubator.define_singleton_method(:header, plain)
  end
end

Suite.define("incubator: the steps in brief, how close the egg is in full, and the whole slot on the info key") do
  t = PokeAccess::I18n
  egg = Poke.build(:name => "Huevo")
  egg.define_singleton_method(:eggsteps) { 1 }
  had = $PokemonGlobal.respond_to?(:eggs)
  $PokemonGlobal.define_singleton_method(:eggs) { [egg, nil] }
  begin
    scene = World.stub_scene(:@index => 0)
    whole = t.t(:hatch_slot_egg, :n => 1, :state => "#{t.t(:hatch_steps, :n => 1)}. El huevo esta listo.")
    rows = vb_levels { PokeAccess::Incubator.text(scene, "El huevo esta listo.") }
    eq "brief and medium: the slot and the steps", rows[0, 2],
       [t.t(:hatch_slot_egg, :n => 1, :state => t.t(:hatch_steps, :n => 1))] * 2
    eq "full: how close it is as well", rows[2], whole
    PokeAccess::Config.verbosity = :brief
    PokeAccess::Incubator.text(scene, "El huevo esta listo.")
    PokeAccess::Config.verbosity = :full
    eq "the info key says the slot whole", PokeAccess::Info.info_text, whole
    eq "and so does Ctrl+T", PokeAccess::Info.row_text, whole
    PokeAccess::Incubator.text(World.stub_scene(:@index => 1))
    eq "a free slot is the info key's too", PokeAccess::Info.info_text, t.t(:hatch_slot_empty, :n => 2)
  ensure
    class << $PokemonGlobal; remove_method :eggs; end unless had
  end
end
