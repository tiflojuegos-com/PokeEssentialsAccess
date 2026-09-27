# Royal's diagonal staircases: touch events whose common events test the player's position against the event with
# the game's own functions, declared here so the route finder can answer them for every tile.
PokeAccess::Game.define("royal_stairs") do
  # name => [columns right of the event, first row above it, last row, whether the last row needs tam >= 3]
  {
    "escalera_pos_arriba"                       => [[1], 1, 3, true],
    "escalera_pos_arriba_2"                     => [[1], 1, 3, true],
    "escalera_pos_arriba_tocha"                 => [[1], 2, 5, false],
    "escalera_pos_arriba_tocha_medio"           => [[2], 1, 4, false],
    "escalera_pos_arriba_2_tocha"               => [[3], 2, 5, false],
    "escalera_pos_arriba_2_tocha_medio"         => [[2, 3], 1, 4, false],
    "escalera_bajada_derecha_pos_abajo"         => [[2], 0, 2, true],
    "escalera_bajada_derecha_pos_abajo_tocha"   => [[3], 0, 3, false],
    "escalera_bajada_izquierda_pos_abajo"       => [[0], 0, 2, true],
    "escalera_bajada_izquierda_pos_abajo_tocha" => [[1], 0, 3, false],
    "escalera_en_medio"                         => [[1], 1, 3, true],
    "escalera_en_medio_dcha_tocha"              => [[2], 1, 4, false],
    "escalera_en_medio_dcha_fin_tocha"          => [[1], 2, 5, false],
    "escalera_en_medio_izda_tocha"              => [[2], 1, 4, false],
    "escalera_en_medio_izda_fin_tocha"          => [[3], 2, 5, false]
  }.each do |name, spec|
    cols, first, last, sized = spec
    script_condition(/\A#{name}\b(?:\s*\(\s*(\d+)\s*\))?/) do |m, c|
      pos = c[:pos]; me = c[:self]
      next :unknown if pos.nil? || me.nil?
      top = (sized && m[1] && m[1].to_i < 3) ? last - 1 : last
      rise = me[1] - pos[1]
      cols.include?(pos[0] - me[0]) && rise >= first && rise <= top
    end
  end
end
