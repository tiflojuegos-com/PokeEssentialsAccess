# The v22 Pokedex list (Essentials v22 UI::PokedexVisuals). Three states share one row and only the spoken
# line tells them apart: caught, merely seen, and never encountered -- and the last one must NOT leak the
# species name, which is the whole point of an unseen entry. The reader had no assert, so nothing stopped
# the name slipping into the unknown branch or the caught/seen words swapping. Runs only in the gamedata
# pass. Swaps $player's pokedex and restores it, since the stub's default dex owns everything.
def pokedex_v22_dex(owned, seen)
  dex = Object.new
  dex.instance_variable_set(:@owned, owned)
  dex.instance_variable_set(:@seen, seen)
  def dex.owned?(sp); @owned.include?(sp); end
  def dex.seen?(sp); @seen.include?(sp); end
  dex
end

Suite.define("v22 pokedex list: caught, seen and unknown entries each read differently") do
  previous = $player.pokedex
  $player.instance_variable_set(:@dex, pokedex_v22_dex([:BULBASAUR], [:BULBASAUR, :CHARMANDER]))
  begin
    vis = UI::PokedexVisuals.new([:BULBASAUR, :CHARMANDER, :MEWTWO])

    vis.set_index(0)
    eq "a caught species is named and flagged as caught", SpeakCapture.lines,
       ["SpeciesBULBASAUR, " + PokeAccess::I18n.t(:dex_caught)]

    SpeakCapture.clear
    vis.set_index(1)
    eq "a species only seen is named and flagged as seen, not caught", SpeakCapture.lines,
       ["SpeciesCHARMANDER, " + PokeAccess::I18n.t(:dex_seen)]

    SpeakCapture.clear
    vis.set_index(2)
    eq "an unseen species reads as unknown", SpeakCapture.lines,
       [PokeAccess::I18n.t(:dex_unknown)]
    not_spoke "and never leaks its name", /SpeciesMEWTWO/

    SpeakCapture.clear
    vis.set_index(2)
    silent "a redraw on the same entry says nothing"
  ensure
    $player.instance_variable_set(:@dex, previous)
  end
end
