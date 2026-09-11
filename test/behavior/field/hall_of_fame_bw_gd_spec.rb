# The B/W Hall of Fame ceremony in the gen-5 style, the one both games that ship the plugin run. It never
# goes through the three window builders the reader listened to: in one game the whole ceremony was silent
# and in the other only the title was said. The card and the finale are composed from what the bars paint,
# since one copy has no text seam at all.
Suite.define("hall of fame BW: the gen-5 card and finale are spoken from their own seams") do
  scene = HallDeLaFama.new
  pk = Poke.build(:name => "Chispa", :species => 25, :level => 60)
  def pk.speciesName; "Pikachu"; end
  def pk.gender; 1; end

  SpeakCapture.clear
  scene.gen5_pokemon_info(pk, 0)
  eq "the card: nickname, species with its sex word, and level", SpeakCapture.lines,
     ["Chispa, Pikachu #{PokeAccess::I18n.t(:pk_female)}, #{PokeAccess::I18n.t(:hofbw_level, :n => 60)}"]
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
