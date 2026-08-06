# Reminiscencia's dating-sim minigame. Most screens (task, build, support) use a Window_DrawableCommand
# subclass already read by the generic hook. The main hub is the exception: it shows its options as icon
# sprites and writes the focused label to a help window via setText (@commands[@index]). Read that label
# as the cursor moves. Guarded: a no-op where absent.
module PokeAccess
  module ReminDatingSim
    # The hub's focused label, from the same pair the screen draws.
    def self.focus(scene)
      cmds = scene.instance_variable_get(:@commands)
      idx  = scene.instance_variable_get(:@index)
      txt  = (cmds.is_a?(Array) && idx) ? cmds[idx] : nil
      PokeAccess.speak_clean(txt, true) if txt && !txt.to_s.empty?
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("reminiscencia") do
  after("DatingSimMainScreen", :setText) { |s, _r, _a| PokeAccess::ReminDatingSim.focus(s) }
  # setText covers every MOVE but not the opening: initialize writes the first label straight into the
  # message window and only then enters the loop, so setText has not run yet and the hub opened silent.
  # Hooking initialize would not help -- it calls main_loop from inside itself, so an after-hook on it would
  # not fire until the whole screen closed. before main_loop is the moment the first label already exists
  # and the loop has not started.
  before("DatingSimMainScreen", :main_loop) { |s, _a| PokeAccess::ReminDatingSim.focus(s) }

  # Task screen: the gender tabs (@indexGender 0 male / 1 female / 2 unknown) are a sprite cursor with no
  # window; setGenderPage runs when the tab changes, so announce the selected gender there. The command
  # window with the character names under each tab is read by the generic hook.
  gender_key = lambda do |g|
    { 0 => :rem_dating_male, 1 => :rem_dating_female, 2 => :rem_dating_unknown }[g]
  end
  after("DatingSimTaskScreen", :setGenderPage) do |scene, _r, _a|
    g = PokeAccess.ivar(scene, :@indexGender)
    k = gender_key.call(g)
    PokeAccess.speak(PokeAccess::I18n.t(k), true) if k
  end

  # Support screen: @index selects a character whose name and friendship points are drawn to side windows;
  # updatePoints runs on each move, so read the focused character there (deduped by @index). The partner
  # command window is read by the generic hook. The cursor does NOT move with the arrows: the scene watches
  # two raw scancodes of its own, outside anything the mod's remapping can reach, so nothing here should be
  # wired to a direction.
  after("DatingSimSupportScreen", :updatePoints) do |scene, _r, _a|
    chars = PokeAccess.ivar(scene, :@characters)
    idx   = PokeAccess.ivar(scene, :@index)
    next unless chars.is_a?(Array) && idx && idx >= 0 && idx < chars.length
    next unless PokeAccess::Cursor.changed?(scene, :support, idx)
    name = chars[idx][0]
    pts  = (datingGet(name, "fpPoints") rescue nil)
    txt  = pts ? PokeAccess::I18n.t(:rem_dating_points, :name => name, :n => pts) : name.to_s
    PokeAccess.speak_clean(txt, true) if txt && !txt.to_s.empty?
  end
end
