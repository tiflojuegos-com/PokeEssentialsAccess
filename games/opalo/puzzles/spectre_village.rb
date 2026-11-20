# Opalo's four Magic Keys of Villa Espectro, seen only through the Lens of Truth: two in the village (map 378, events 38 and
# 39) and two in the house (map 403, events 17 and 18), each adding to var 205. The four locks of the Saloon (map 404, events
# 17 and 22 to 24) each spend one and add to var 206; with 4 the way to Cayena opens. The keys keep to the lens category,
# as the core lists them.
module PokeAccess
  module OpaloMagicKeys
    HELD = 205
    USED = 206

    # How many keys the player has found: those held and those spent on a lock.
    def self.found
      $game_variables[HELD].to_i + $game_variables[USED].to_i
    end
  end
end

PokeAccess::Game.define("opalo") do
  keys = PokeAccess::OpaloMagicKeys
  [[378, [38, 39]], [403, [17, 18]]].each do |map, events|
    mechanic(:state, map) do
      auto
      name events, :op_magic_key, :when => false
      count :op_magic_keys, :value => lambda { keys.found }, :of => 4, :hide_zero => true
      solved(nil, :quiet => true) { $game_variables[keys::USED].to_i >= 4 }
      hint :op_magic_keys_hint
    end
  end

  mechanic(:state, 404) do
    auto
    name [17, 22, 23, 24], :op_magic_lock
    count :op_magic_locks, :var => keys::USED, :of => 4, :hide_zero => true
    solved(nil, :quiet => true) { $game_variables[keys::USED].to_i >= 4 }
  end
end
