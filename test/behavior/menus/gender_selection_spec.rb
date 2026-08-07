# The new-game look/gender picker (PokemonGenderSelection), a third-party plugin three of the games ship.
#
# It is two pictures and no text: without a reader there is literally nothing to tell the choices apart.
# This was written three times, once per profile, with three different conventions -- one spoke Spanish
# straight from the source, another kept its own @pa_last dedup, the third watched the scene. The three
# copies agreed on what matters, and the dumps confirm it: same four methods, same @select values, with
# 2 the boy, 4 the girl, 1 the neutral start and 3/5 the confirm step.
# The harness loads every plugin reader, so this spec does not pull it in itself. It used to, back
# when only the running profile's declared plugins were loaded -- and once the harness started
# loading them all, that require became a SECOND load of the same file: require does not know
# about a file already brought in with eval, so every constant in it was reassigned.

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

  # The odd values are the confirm step, which runs the question, the player change and the fade inside the
  # same input call: by the time the hook fires there is no picker left to describe.
  SpeakCapture.clear
  scene.instance_variable_set(:@select, 5)
  gs.announce(scene)
  silent "confirming says nothing: the screen is gone by the time the hook fires"
  eq "the boy's confirm value has no label", gs.label_key(3), nil
  eq "nor the girl's", gs.label_key(5), nil

  eq "an unknown cursor value has no label", gs.label_key(99), nil
end
