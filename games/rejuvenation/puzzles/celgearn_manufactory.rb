# Celgearn Manufactory (map 616): 23 events named "Shock", with no sprite, hurt the player stepping on them; the walks
# keep off them with the assist.
PokeAccess::Game.define("rejuvenation") do
  mechanic(:state, 616, :part => :shocks) do
    auto
    name(/\AShock\z/, :rjg_cm_shock, :grouped => true)
    avoid(/\AShock\z/, :assist => true)
  end
end
