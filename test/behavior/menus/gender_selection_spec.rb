# The new-game look/gender picker (PokemonGenderSelection plugin): @select 2 is the boy, 4 the girl, 1 the neutral
# start, 3/5 the confirm step. Not required here: the harness loads it, and a second load reassigns its constants.

Suite.define("gender selection: the highlighted choice is spoken, and the neutral start is not") do
  scene = Object.new
  gs = PokeAccess::GenderSelection

  scene.instance_variable_set(:@select, 1)
  SpeakCapture.clear
  gs.announce(scene)
  silent "the neutral start says nothing: the opening help line already covered it"

  scene.instance_variable_set(:@select, 2)
  gs.announce(scene)
  spoke "left highlights the boy", /#{PokeAccess::I18n.t(:gsel_boy)}/

  SpeakCapture.clear
  scene.instance_variable_set(:@select, 4)
  gs.announce(scene)
  spoke "right highlights the girl", /#{PokeAccess::I18n.t(:gsel_girl)}/

  SpeakCapture.clear
  gs.announce(scene)
  silent "an unchanged cursor stays silent"

  SpeakCapture.clear
  scene.instance_variable_set(:@select, 5)
  gs.announce(scene)
  silent "confirming says nothing: the screen is gone by the time the hook fires"
  eq "the boy's confirm value has no label", gs.label_key(3), nil
  eq "nor the girl's", gs.label_key(5), nil

  eq "an unknown cursor value has no label", gs.label_key(99), nil
end
