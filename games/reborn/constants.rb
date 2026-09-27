# Pokemon Reborn 19.5 (Reborn's own engine: a gen-6 lineage on Ruby 3.1 with its data in $cache). The letter keys
# carry Reborn's actions, named in the remap menu as its key list names them (A, S, D, Q, W).
PokeAccess::Game.define("reborn") do
  button_labels :x => :reb_btn_x, :y => :reb_btn_y, :z => :reb_btn_z, :l => :reb_btn_l, :r => :reb_btn_r
end
