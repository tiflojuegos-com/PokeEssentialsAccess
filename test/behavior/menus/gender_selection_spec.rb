# The new-game look/gender picker (PokemonGenderSelection), a third-party plugin three of the games ship.
#
# It is two pictures and no text: without a reader there is literally nothing to tell the choices apart.
# This was written three times, once per profile, with three different conventions -- one spoke Spanish
# straight from the source, another kept its own @pa_last dedup, the third watched the scene. The three
# copies agreed on what matters, and the dumps confirm it: same four methods, same @select values, with
# 2/3 the boy, 4/5 the girl and 1 the neutral start.
# The runner loads one profile, and this plugin is not the one it declares, so the spec pulls the reader
# in itself -- it needs the module, not the games classes.
require File.expand_path("../../../plugins/gender_selection", File.dirname(__FILE__))

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

  # The odd values are the confirm step of the SAME choice; they must not be read as a different one.
  SpeakCapture.clear
  scene.instance_variable_set(:@select, 5)
  gs.announce(scene)
  spoke "confirming the girl is still the girl", /#{PokeAccess::I18n.t(:gsel_girl)}/
  eq "and the confirm step maps to the same side", gs.label_key(3), gs.label_key(2)

  eq "an unknown cursor value has no label", gs.label_key(99), nil
end
