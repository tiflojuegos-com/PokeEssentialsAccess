# Striaton's gym (map 663): its three leaders all carry the editor name Cilan; events 10 and 11 are Chili and Cress, as
# their own lines call them, and Cress sends the player to Chili first.
PokeAccess::Game.define("fireash") do
  leaders = { 10 => :fa_chili, 11 => :fa_cress }
  event_name do |ev|
    key = $game_map.map_id == 663 ? leaders[ev.id] : nil
    key && PokeAccess::I18n.t(key)
  end
end
