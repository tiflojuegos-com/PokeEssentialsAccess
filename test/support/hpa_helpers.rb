# Shared HPA* spec helpers, loaded by the runner like the other support files so every spec that needs them
# works standalone under a path filter. Inside one spec instead, another would depend on that file having
# loaded first.
#
# TRAP when writing ASCII grids: build the rows with SINGLE quotes, or keep '@' away from a letter.
# In a double-quoted string "#@A..." Ruby interpolates the instance variable @A -- which is nil -- so
# load_grid silently receives a SHORTER row: wrong width, events misplaced, the player never positioned,
# and the spec fails for a reason that has nothing to do with what it tests.

# Loads an ASCII grid and resets the pathfinder's per-map caches so a fresh layout is searched from scratch.
def hpa_fresh_grid(rows)
  $game_map.clear_ledges
  $game_map.load_grid(rows)
  [:@rs_key, :@pcache_state, :@hpa_sig, :@slide_key, :@rs, :@rs_full].each do |s|
    PokeAccess::Pathfinder.instance_variable_set(s, nil)
  end
end

# A 24x14 arena split by two vertical wall bands (gaps at (8,3) and (16,10)) so a route spans several
# 10-tile clusters and MUST cross portals. Player at (1,1); a target letter is dropped at (22,12).
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
