# Infinite Fusion's own marks: a fusion's head and body on the first summary page, the second shiny star for two
# shiny halves, and the PC's fuse action while the splicers are armed.
Suite.define("infinite fusion: head and body, both shiny halves, and fusing in the PC") do
  t = PokeAccess::I18n
  metas = { PokeAccess::Party => [:shiny_word, :held_key], PokeAccess::SummaryGameData => [:info_text] }
  metas.each { |m, names| names.each { |n| (class << m; self; end).send(:alias_method, "ifspec_#{n}", n) } }
  begin
    load File.expand_path("../../../games/infinitefusion_common/fusion_marks.rb", File.dirname(__FILE__))
    load File.expand_path("../../../games/infinitefusion_common/storage_fusion.rb", File.dirname(__FILE__))
    both = Poke.build(:name => "Pikachar", :shiny => true)
    both.define_singleton_method(:headShiny?) { true }
    both.define_singleton_method(:bodyShiny?) { true }
    eq "two stars, both halves", PokeAccess::Party.shiny_word(both), t.t(:if_shiny_both)
    truthy "and the info key says both too", PokeAccess::Info.pokemon_info(both).to_s.include?(t.t(:if_shiny_both))
    one = Poke.build(:name => "Pikachar", :shiny => true)
    one.define_singleton_method(:headShiny?) { true }
    one.define_singleton_method(:bodyShiny?) { false }
    eq "one star, one word", PokeAccess::Party.shiny_word(one), t.t(:pk_shiny)
    one.define_singleton_method(:debugShiny?) { true }
    eq "a star drawn black, a shiny not rolled naturally, says so", PokeAccess::Party.shiny_word(one),
       t.t(:if_shiny_unnatural, :shiny => t.t(:pk_shiny))
    both.define_singleton_method(:debugShiny?) { true }
    eq "both stars black too", PokeAccess::Party.shiny_word(both), t.t(:if_shiny_unnatural, :shiny => t.t(:if_shiny_both))
    one.define_singleton_method(:radarShiny?) { true }
    eq "but Hoenn draws the radar's blue instead", PokeAccess::Party.shiny_word(one), t.t(:pk_shiny)

    screen = Object.new
    def screen.fusionMode; true; end
    scene = Object.new
    scene.instance_variable_set(:@screen, screen)
    eq "with the splicers armed the slot is fused with", PokeAccess::Party.held_key(scene), :if_pc_fuse
    nb_set = !Object.const_defined?(:NB_POKEMON)
    Object.const_set(:NB_POKEMON, 501) if nb_set
    Object.send(:define_method, :dexNum) { |sp| sp == :B25H6 ? 25 * 501 + 6 : 25 }
    single = Struct.new(:species).new(:PIKACHU)
    fusion = Struct.new(:species).new(:B25H6)
    eq "a slot whose Pokemon is not a fusion can be fused with", PokeAccess::Party.held_key(scene, single), :if_pc_fuse
    eq "one that is already a fusion, its icon hidden, is said to be one", PokeAccess::Party.held_key(scene, fusion),
       :if_pc_fused
    def screen.fusionMode; false; end
    eq "and otherwise swapped", PokeAccess::Party.held_key(scene), :pc_swap
    eq "a fusion too, with the splicers put away", PokeAccess::Party.held_key(scene, fusion), :pc_swap

    fused = Poke.build(:name => "Pikachar")
    halves = Struct.new(:get_head_species, :get_body_species).new(:PIKACHU, :CHARMANDER)
    fused.define_singleton_method(:isFusion?) { true }
    fused.define_singleton_method(:species_data) { halves }
    Object.send(:define_method, :getPokemon) { |sp| Struct.new(:name).new(sp == :PIKACHU ? "Pikachu" : "Charmander") }
    line = "#{t.t(:if_head, :n => 'Pikachu')} #{t.t(:if_body, :n => 'Charmander')}"
    eq "a fusion's head and body, as the first page writes them", PokeAccess::IFFusionMarks.halves(fused), line
    truthy "and they close that page", PokeAccess::SummaryGameData.info_text(fused).to_s.end_with?(line)
    falsy "a Pokemon that is not a fusion has no halves", PokeAccess::IFFusionMarks.halves(Poke.build(:name => "Pika"))

    pc = PokemonStorageScene.new
    SpeakCapture.clear
    pc.setFusing(true)
    pc.setFusing(true)
    pc.setFusing(false)
    eq "the splicers armed and put away in the PC, each said once", SpeakCapture.lines,
       [t.t(:if_fuse_on), t.t(:if_fuse_off)]
  ensure
    Object.send(:remove_method, :getPokemon) rescue nil
    Object.send(:remove_method, :dexNum) rescue nil
    Object.send(:remove_const, :NB_POKEMON) if nb_set
    metas.each do |m, names|
      names.each do |n|
        meta = (class << m; self; end)
        meta.send(:alias_method, n, "ifspec_#{n}")
        meta.send(:remove_method, "ifspec_#{n}")
      end
    end
  end
end

Suite.define("storage modes: a game that names its mode says it") do
  scene = Object.new
  SpeakCapture.clear
  PokeAccess::StorageModes.say(scene, :pc_mode_multi)
  eq "the mode named by the caller", SpeakCapture.lines, [PokeAccess::I18n.t(:pc_mode_multi)]
end
