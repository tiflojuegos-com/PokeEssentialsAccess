# Back on the modern party list after a command, the choice loop says the member under the cursor (or the one it is
# told to start on); not on the opening's own choice, nor a member already said on the way back.
Suite.define("party (modern): back on the list after a command, the member under the cursor is said again") do
  pika = Poke.build(:name => "Pika", :level => 20)
  eevee = Poke.build(:name => "Eevee", :level => 5)
  scene = PokemonParty_Scene.new([pika, eevee])
  scene.on_start = lambda { scene.move_cursor(0) }
  SpeakCapture.clear
  scene.pbStartScene
  scene.on_choose = lambda { scene.move_cursor(1) }
  scene.pbChoosePokemon
  eq "the opening reads the member, and the move inside the choice the next", SpeakCapture.lines,
     [PokeAccess::UIV21.party_member(pika, nil), PokeAccess::UIV21.party_member(eevee, nil)]
  scene.on_choose = nil
  SpeakCapture.clear
  scene.pbChoosePokemon
  eq "back from a command, the member is read again, queued", SpeakCapture.log,
     [[PokeAccess::UIV21.party_member(eevee, nil), false]]
  scene.pbSelect(0)
  SpeakCapture.clear
  scene.pbChoosePokemon
  eq "a member the screen already said on the way back is not said twice", SpeakCapture.lines, []
  SpeakCapture.clear
  scene.pbChoosePokemon(true, 1)
  eq "a list told to start on a member reads that one, not the one marked before", SpeakCapture.lines,
     [PokeAccess::UIV21.party_member(eevee, nil)]
end
