# Abyssal Base (map 278; 517 is its unused copy): twenty-one teleport tiles with no graphic that carry the player to another
# part of the base (event 72 chooses its landing by switch 161), fifty force fields (AUDREY_FIELD) that a disguise lets
# through (variable 41: 2 cultist, 3 scientist, 4 Audrey; ids 1 to 10 ask 4, 11 to 20 ask 3, the rest 2), and two
# terminals (events 52 and 53) that ask for a password, "proteus", only when faced upward and until switch 161 drains the
# sewers. Switch 158 ends the base. Once drained, event 72 lands in the east room, whose sewage pool (7 by 7 tiles of the
# "slime" autotile, x 65 to 71, y 16 to 22) turns to water with Seed Flare, and Surf crosses it to Audrey's clothes.
# The pool is only reached from the south, so its point sits on the middle of that edge (68,22), not at its centre.
PokeAccess::Game.define("insurgence") do
  need = lambda { |ev| ev.id <= 10 ? 4 : (ev.id <= 20 ? 3 : 2) }
  field = lambda do |ev|
    PokeAccess::Puzzles.assist? ? "ins_abyss_field_#{need.call(ev)}".to_sym : :ins_abyss_field
  end
  cleared = lambda { $game_switches[158] }
  slime = lambda { ($game_map.autotile_names[4] rescue nil) == "slime" }
  pool_plain = lambda { slime.call && !PokeAccess::Puzzles.assist? }
  pool_answer = lambda { slime.call && PokeAccess::Puzzles.assist? }
  terminal_answer = lambda do |_ev|
    $game_switches[161] || $game_player.direction != 8 ? "" : [:puzzle_answer, { :a => "proteus" }]
  end
  mechanic(:state, [278, 517]) do
    auto
    name(/\Ateleport\z/, :ins_abyss_tile)
    name(/\AAUDREY_FIELD\z/, field, :grouped => true)
    name [52, 53], :ins_abyss_terminal
    on_use [52, 53], terminal_answer, :assist => true
    sent_back :ins_abyss_sent, :events => 54..74
    watch :var => 41, :label => :ins_abyss_disguise,
          :words => { 0 => :ins_disguise_none, 1 => :ins_disguise_darkrai, 2 => :ins_disguise_abyssal_cultist,
                      3 => :ins_disguise_abyssal_scientist, 4 => :ins_disguise_audrey,
                      13 => :ins_disguise_infernal, 14 => :ins_disguise_zenith }
    watch :switch => 161, :quiet => true
    spot :at => [68, 22], :label => :ins_u1_sewer, :when => pool_plain
    spot :at => [68, 22], :label => :ins_u1_sewer_answer, :when => pool_answer
    active { !cleared.call }
    solved(nil, :quiet => true) { cleared.call }
    arrival_hint :ins_abyss_rule
    hint :ins_abyss_hint
  end
end
