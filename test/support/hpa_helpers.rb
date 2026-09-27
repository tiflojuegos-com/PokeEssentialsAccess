# Shared HPA* spec helpers, loaded by the runner with the other support files. Build ASCII grid rows in single
# quotes: in double quotes "#@A" interpolates @A (nil), and the row comes out shorter.

# Loads an ASCII grid and resets the pathfinder's per-map caches so a fresh layout is searched from scratch.
def hpa_fresh_grid(rows)
  $game_map.clear_ledges
  $game_map.load_grid(rows)
  [:@rs_key, :@pcache_state, :@hpa_sig, :@event_indexes, :@rs, :@rs_full].each do |s|
    PokeAccess::Pathfinder.instance_variable_set(s, nil)
  end
end

# A 24x14 arena split by two vertical wall bands (gaps at (8,3) and (16,10)) so a route spans several
# 10-tile clusters and must cross portals. Player at (1,1); a target letter is dropped at (22,12).
def hpa_arena(target_ch)
  rows = ["#" * 24]
  (1..12).each do |y|
    row = ""
    (0..23).each do |x|
      row << (
        (x == 0 || x == 23) ? "#" :
        (x == 1 && y == 1) ? "@" :
        (x == 22 && y == 12) ? target_ch :
        ((x == 8 && y != 3) || (x == 16 && y != 10)) ? "#" : ".")
    end
    rows << row
  end
  rows << "#" * 24
  rows
end

# Runs a block as in a game with no terrain rules registered, which the grid searches (JPS, HPA*) need, putting the
# registered ones back afterwards; returns the block's value.
def without_terrain_rules
  pf = PokeAccess::Pathfinder
  saved = [pf.instance_variable_get(:@arrival_rules), pf.instance_variable_get(:@leave_rules)]
  pf.instance_variable_set(:@arrival_rules, [])
  pf.instance_variable_set(:@leave_rules, [])
  yield
ensure
  if saved
    pf.instance_variable_set(:@arrival_rules, saved[0])
    pf.instance_variable_set(:@leave_rules, saved[1])
  end
end
