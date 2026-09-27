# What Awakening's quest marker pictures show (Graphics/Pictures/Quest Markers): "red" is a blue speech bubble with
# an ellipsis, "tripletriad" a VS badge over the card players.
PokeAccess::Game.define("awakening") do
  override("PokeAccess::QuestMarker", :word) do |_mod, _original, args|
    { "red" => :qm_bubble_blue, "tripletriad" => :qm_vs }[args[0].to_s]
  end
end
