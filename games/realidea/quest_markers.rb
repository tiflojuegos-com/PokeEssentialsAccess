# What Realidea's quest marker pictures show (Graphics/Pictures/Quest Markers): "red" is a yellow exclamation mark
# (favours), "asul" a blue one (pending clients and Magnemite), and "calavera1" to "3" the white, yellow and red
# skulls over the open sea's pirate ships.
PokeAccess::Game.define("realidea") do
  override("PokeAccess::QuestMarker", :word) do |_mod, _original, args|
    { "red" => :qm_excl_yellow, "asul" => :qm_excl_blue, "calavera1" => :qm_skull_white,
      "calavera2" => :qm_skull_yellow, "calavera3" => :qm_skull_red }[args[0].to_s]
  end
end
