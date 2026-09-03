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

  # Support screen: @index selects the left character and @cmdwindow.index the partner; updatePoints runs
  # on each move of EITHER cursor, repainting both point windows and the "Puntos necesarios" line, so both
  # indexes join the dedup key and the whole pair (points, required, combined total) is read together --
  # those numbers are what decide whether the interaction can start at all. The cursor does NOT move with
  # the arrows: the scene watches two raw scancodes of its own, outside the mod's remapping.
  after("DatingSimSupportScreen", :updatePoints) do |scene, _r, _a|
    chars = PokeAccess.ivar(scene, :@characters)
    idx   = PokeAccess.ivar(scene, :@index)
    next unless chars.is_a?(Array) && idx && idx >= 0 && idx < chars.length
    cmdw = PokeAccess.ivar(scene, :@cmdwindow)
    cidx = (cmdw.index rescue nil)
    next unless PokeAccess::Cursor.changed?(scene, :support, [idx, cidx])
    name = chars[idx][0]
    pts  = (datingGet(name, "fpPoints") rescue nil)
    parts = [pts ? PokeAccess::I18n.t(:rem_dating_points, :name => name, :n => pts) : name.to_s]
    pname = (cmdw.commands[cidx] rescue nil)
    if pname
      ppts = (datingGet(pname, "fpPoints") rescue nil)
      req  = (scene.getTotalPoints(name, pname) rescue nil)
      parts.push(PokeAccess::I18n.t(:rem_dating_pair, :name => pname, :n => ppts.to_i,
                                    :req => (req.nil? ? "----" : req),
                                    :tot => (pts.to_i + ppts.to_i)))
    end
    txt = parts.join(". ")
    PokeAccess.speak_clean(txt, true) if txt && !txt.to_s.empty?
  end
end

# The build screen's material table: recipe headers and the have/need count per material, repainted by
# drawDataWindow on every selection or tab change and captured whole -- the rows are the screen's own
# words and numbers. The green/red the sighted player gets is the count comparison, already in the rows.
PokeAccess::Game.define("reminiscencia") do
  around("DatingSimBuildScreen", :drawDataWindow, :optional => true) do |scene, nxt, _a|
    PokeAccess::PaintCapture.arm(:rem_build)
    begin
      nxt.call
    ensure
      t = PokeAccess::PaintCapture.text(PokeAccess::PaintCapture.take(:rem_build))
      PokeAccess.speak(t, true) if !t.empty? && PokeAccess::Cursor.changed?(scene, :rem_build, t)
    end
  end
end

# The build screen's material list (Window_CommandPokemonCraftSim) paints each row twice: the command
# string on the left and, at a fixed column, how many of that material the dating bag holds -- the
# quantity is the half the generic reader missed. The window's own translation-key table maps the row to
# the bag name, with the single-row objective case mirrored from drawItem.
PokeAccess::Menus.def_extractor("Window_CommandPokemonCraftSim") do |win, i|
  cmds = win.instance_variable_get(:@commands)
  if cmds.is_a?(Array) && cmds[i]
    name = PokeAccess.clean(cmds[i].to_s)
    tl = win.instance_variable_get(:@translation_list)
    key = (cmds.length > 1) ? (tl.is_a?(Array) ? tl[i] : nil) : (($Trainer.nextObjective[0][0]) rescue nil)
    qty = key ? (datingBagQuantity(key) rescue nil) : nil
    qty.nil? ? name : "#{name}: #{qty}"
  else
    nil
  end
end
