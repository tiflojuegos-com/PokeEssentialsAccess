# Relict's difficulty picker (PickDifficulty, sprite buttons): the option under @index in @difficulties
# ([title, description] pairs), its description while descriptions are said; the info key keeps both.
PokeAccess::Game.define("relict") do
  after("PickDifficulty", :update) do |scr, _ret, _args|
    diffs = PokeAccess.ivar(scr, :@difficulties)
    idx   = PokeAccess.ivar(scr, :@index)
    if diffs.is_a?(Array) && idx && diffs[idx] && idx != (scr.instance_variable_get(:@access_diff) rescue nil)
      first = (scr.instance_variable_get(:@access_diff) rescue nil).nil?
      scr.instance_variable_set(:@access_diff, idx)
      line = PokeAccess::Verbosity.info_line(:descriptions, [[diffs[idx][0], :brief], [diffs[idx][1], :full]], ". ")
      line = "#{PokeAccess::I18n.t(:rel_difficulty)}. #{line}" if first
      PokeAccess.speak_clean(line, true)
    end
  end

  # run is the picker's loop, unguarded as its update and its confirm speak inside it; the difficulty leaves the
  # info key when it is over.
  after("PickDifficulty", :run, :optional => true, :hook_container => true) do |_s, _r, _a|
    PokeAccess::Info.clear_text
  end
end
