# The save panel of the continue screen, whose arguments are NOT in a fixed place. Four shapes of
# pbStartScene across the surveyed games, and the two things worth saying move between them:
#
#   (commands, showContinue, trainer, framecount, mapid)              seven gen-6 games
#   (commands, show_continue, trainer, stats, map_id)                 anil, emerald, relict, royal
#   (commands, show_continue, trainer, frame_count, map_id)           Fire Ash, both Infinite Fusions
#   (commands, show_continue, trainer, frame_count, stats, map_id)    Soulstones 2
#
# Read by position, the reader took a stats object for a frame count in three games and, in the one with six
# parameters, read the stats object AS the map id -- so the save announced no location and no play time at
# all. Asked by shape: the map id is the last argument in all four, and the play time is whichever of the
# middle ones answers for it.
Suite.define("load panel: the map and the play time are found whatever shape the screen passes them in") do
  lp = PokeAccess::LoadPanel
  stats = Object.new
  def stats.play_time; 7200; end

  shapes = {
    "gen-6, frames"        => ["cmds", true, nil, 3600 * 40, 35],
    "modern, stats"        => ["cmds", true, nil, stats, 35],
    "Fire Ash, frames"     => ["cmds", true, nil, 3600 * 40, 35],
    "Soulstones, both"     => ["cmds", true, nil, 3600 * 40, stats, 35]
  }
  shapes.each do |name, args|
    eq "#{name}: the map id is the last argument", lp.map_id(args), 35
    truthy "#{name}: and the play time is found", lp.seconds(args).to_i > 0
  end

  eq "a stats object is preferred over nothing", lp.seconds(["c", true, nil, stats, 9]), 7200

  # The whole line, through the real reader.
  trainer = Object.new
  def trainer.name; "Ash"; end
  def trainer.badge_count; 3; end
  line = lp.summary(["cmds", true, trainer, 3600 * 40, stats, 35])
  match "the summary names the trainer", line, /Ash/
  match "says the badges", line, /#{PokeAccess::I18n.t(:tr_badges, :n => 3)}/
  match "and the place, which is what a save is recognised by", line, /Mapa 35|35/

  truthy "a screen with nothing to continue says nothing",
         lp.summary(["cmds", false, trainer, 0, 35]).nil?
end
