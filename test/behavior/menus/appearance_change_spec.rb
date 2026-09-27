# The appearance is spoken when pbChangePlayer puts a new one on, and only then: Insurgence puts the same one
# on again on every map transfer (over its outfits), and an id the game refuses changes nothing.
Suite.define("appearance: spoken when pbChangePlayer changes it, silent when it stays") do
  said = lambda { |n| /#{Regexp.escape(PokeAccess::I18n.t(:ap_number, :n => n))}/ }
  $PokemonGlobal.playerID = -1
  begin
    SpeakCapture.clear
    pbChangePlayer(0)
    spoke "the first appearance chosen is spoken", said.call(1)
    SpeakCapture.clear
    pbChangePlayer(0)
    silent "the same one put on again is not"
    SpeakCapture.clear
    pbChangePlayer(9)
    silent "nor an id the game refuses"
    SpeakCapture.clear
    pbChangePlayer(1)
    spoke "another one is", said.call(2)
  ensure
    $PokemonGlobal.playerID = 0
  end
end

# From v19 the appearance lives on the player (character_ID); gen-6 keeps it in $PokemonGlobal.playerID.
Suite.define("appearance: the record read is the player's own where the engine keeps it there") do
  ap = PokeAccess::Appearance
  was = $Trainer
  $Trainer = Struct.new(:character_ID).new(3)
  begin
    eq "the player's character_ID", ap.current_id, 3
  ensure
    $Trainer = was
  end
  $PokemonGlobal.playerID = 2
  begin
    eq "and the gen-6 record where the player has none", ap.current_id, 2
  ensure
    $PokemonGlobal.playerID = 0
  end
end
