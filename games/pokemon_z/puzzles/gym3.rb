# 3rd gym "Bastion Pokemon" (maps 87, 89): floor plates toggle the "rayos" barriers, named by colour and lie as drawn;
# each room's red, blue and green plate switches and the optional Rotom lever are said as on/off. No win: the room
# never settles.
PokeAccess::Game.define("pokemon_z") do
  [[87, 142, 141, 143, 147], [89, 144, 145, 146, 148]].each do |map, red, blue, green, power|
    mechanic(:state, map) do
      watch :switch => red,   :label => :gym3_red,   :on => :gym3_on, :off => :gym3_off
      watch :switch => blue,  :label => :gym3_blue,  :on => :gym3_on, :off => :gym3_off
      watch :switch => green, :label => :gym3_green, :on => :gym3_on, :off => :gym3_off
      watch :switch => power, :label => :gym3_power, :on => :gym3_power_on, :off => :gym3_power_off
      controls
      obstacle(/\ArayosR\z/i, :label => :gym3_rays_red)
      obstacle(/\ArayosRojosV\z/i, :label => :gym3_rays_red_v)
      obstacle(/\ArayosBarrera\z/i, :label => :gym3_rays_blue)
      obstacle(/\ArayosAzulesV\z/i, :label => :gym3_rays_blue_v)
      obstacle(/\ArayosV\z/i, :label => :gym3_rays_green)
      hint :gym3_hint
    end
  end
end
