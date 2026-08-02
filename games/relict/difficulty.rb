# Relict's start-of-game difficulty picker (ArcyGame: class PickDifficulty, sprite buttons + a check cursor,
# no command window). @difficulties is [[title, description], ...] and @index is the cursor; its update loop
# changes @index on up/down, so poll @index there (deduped) and read the focused option's real label/desc.
PokeAccess::Game.define("relict") do
  after("PickDifficulty", :update) do |scr, _ret, _args|
    diffs = PokeAccess.ivar(scr, :@difficulties)
    idx   = PokeAccess.ivar(scr, :@index)
    if diffs.is_a?(Array) && idx && diffs[idx] && idx != (scr.instance_variable_get(:@access_diff) rescue nil)
      first = (scr.instance_variable_get(:@access_diff) rescue nil).nil?
      scr.instance_variable_set(:@access_diff, idx)
      line = [diffs[idx][0], diffs[idx][1]].compact.join(". ")
      line = "Dificultad. #{line}" if first
      PokeAccess.speak_clean(line, true) if line && !line.empty?
    end
  end
end
