# What Perseida's quest marker pictures show (Graphics/Pictures/Quest Markers): "red" and "blue" are exclamation marks,
# "yellow" a question mark, "green" a green mark and "push" a hand over what can be pushed.
PokeAccess::Game.define("perseida") do
  override("PokeAccess::QuestMarker", :word) do |_mod, _original, args|
    { "red" => :perseida_qm_red, "blue" => :qm_excl_blue, "yellow" => :perseida_qm_question,
      "green" => :perseida_qm_green, "push" => :perseida_qm_push }[args[0].to_s]
  end
end
