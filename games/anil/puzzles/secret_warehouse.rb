# The Secret Warehouse's door (map 213, event 4, drawn with no sprite): it opens once two people have given the player their
# passwords (switches 269 and 270) and says "two are needed" when touched without them. The count of passwords known is for
# the assist.
PokeAccess::Game.define("anil") do
  mechanic(:state, 213) do
    auto
    name 4, :anil_password_door
    count :anil_passwords, :switches => [269, 270], :announce => false, :assist => true
    active { !($game_switches[269] && $game_switches[270]) }
  end
end
