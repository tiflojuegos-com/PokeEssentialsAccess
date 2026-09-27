# The B/W Hall of Fame plugin's gen-5 ceremony: the member card and the finale are composed from what their bars
# paint (one copy of the plugin has no text seam).
Suite.define("hall of fame BW: the gen-5 card and finale are spoken from their own seams") do
  scene = HallDeLaFama.new
  pk = Poke.build(:name => "Chispa", :species => 25, :level => 60)
  def pk.speciesName; "Pikachu"; end
  def pk.gender; 1; end

  SpeakCapture.clear
  scene.gen5_pokemon_info(pk, 0)
  eq "the card: nickname, species with the sex sign its bar paints, and level", SpeakCapture.lines,
     ["Chispa, Pikachu \xE2\x99\x80, #{PokeAccess::I18n.t(:hofbw_level, :n => 60)}"]
  falsy "queued, so the card does not cut the ceremony's own line before it", SpeakCapture.log.last[1]

  SpeakCapture.clear
  scene.create_gen5_final_windows
  eq "the finale: the champion line with the region, then the player and the play time", SpeakCapture.lines,
     ["#{PokeAccess::I18n.t(:hofbw_champion, :region => 'KANTO')} #{PokeAccess::I18n.t(:hofbw_finale, :name => 'Tester', :time => '3:07')}"]

  plain = Poke.build(:name => "Pikachu", :species => 25, :level => 5)
  def plain.speciesName; "Pikachu"; end
  eq "a member without a nickname is not named twice", PokeAccess::HallOfFameBW.card(plain),
     "Pikachu#{PokeAccess::HallOfFameBW.sex_suffix(plain)}, #{PokeAccess::I18n.t(:hofbw_level, :n => 5)}"
end

# Royal's copy draws the card's species bar as the name and the type icons, with no sex sign after the name,
# so its profile says the types there and no sex.
Suite.define("hall of fame BW: Royal's card says the types its species bar shows, and no sex") do
  hof = PokeAccess::HallOfFameBW
  plugin_sex = hof.method(:sex_suffix)
  plugin_bar = hof.method(:species_bar)
  begin
    load File.expand_path("../../../games/royal/hall_of_fame.rb", File.dirname(__FILE__))
    pk = Poke.build(:name => "Chispa", :species => 25, :level => 60, :gender => 1)
    def pk.speciesName; "Pikachu"; end
    def pk.types; [:GRASS, :POISON]; end
    eq "the species, then its types, and no sex sign", hof.card(pk),
       "Chispa, Pikachu, #{PokeAccess::I18n.t(:mv_type, :t => 'TypeGRASS/TypePOISON')}, "        "#{PokeAccess::I18n.t(:hofbw_level, :n => 60)}"
  ensure
    hof.define_singleton_method(:sex_suffix, plugin_sex)
    hof.define_singleton_method(:species_bar, plugin_bar)
  end
end

# A ceremony text window is read when shown or rewritten while shown, never when built hidden.
Suite.define("hall of fame BW: a ceremony text window is read when it is shown, never when it is built") do
  scene = HallDeLaFama.new
  SpeakCapture.clear
  title = scene.create_text_window("<ac>Salon de la Fama</ac>")
  silent "a window built hidden -- the gen-5 title, never shown -- says nothing"
  stats = scene.create_text_window("Pokedex: 151", true)
  spoke "one built visible is read", /Pokedex: 151/
  SpeakCapture.clear
  title.visible = true
  spoke "the hidden one is read when it is shown", /Salon de la Fama/
  SpeakCapture.clear
  title.visible = true
  silent "and not again for being shown again"
  stats.text = "Pokedex: 152"
  spoke "a shown window rewritten is read again", /Pokedex: 152/
  SpeakCapture.clear
  title.visible = false
  title.text = "Otro"
  silent "a hidden one rewritten waits until it is shown"
end
