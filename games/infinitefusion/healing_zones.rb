# Keep the shared healing mechanism; only this original map's displayed zone name is specific to IF.
PokeAccess::Game.define("infinitefusion") do
  event_name do |event|
    if $game_map && $game_map.map_id == 467 && PokeAccess::HealingZones.event?(event)
      PokeAccess::I18n.t(:if_purified_zone)
    end
  end
end
