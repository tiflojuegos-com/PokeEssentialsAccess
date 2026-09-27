# Reminiscencia's dating-sim minigame: the hub's icon options (their label, from @commands[@index]) and HUD, the
# results, the day roll, and the task, support and build screens' extras over the generic command windows.
module PokeAccess
  module ReminDatingSim
    # The hub's focused label, from the same pair the screen draws.
    def self.focus(scene)
      cmds = scene.instance_variable_get(:@commands)
      idx  = scene.instance_variable_get(:@index)
      txt  = (cmds.is_a?(Array) && idx) ? cmds[idx] : nil
      PokeAccess.speak_clean(txt, true)
    rescue StandardError
      nil
    end

    # The hub's HUD (objective with days left, day count), queued after the focused label as the hub opens.
    def self.hud(scene)
      %w[nextitem daycount].each do |key|
        w = PokeAccess.sprite(scene, key)
        t = (w.text rescue nil).to_s
        next if t.strip.empty?
        lines = t.split("\n").map { |l| l.strip }.reject { |l| l.empty? }
        line = (lines.length > 1 && lines[0] =~ /:\z/) ? lines[0] + " " + lines[1..-1].join(", ") : lines.join(", ")
        PokeAccess.speak_clean(line, false)
      end
    rescue StandardError
      nil
    end

    # The results screen's harvest as one line: the rows drawData painted (title and "ITEMxN" entries) and
    # the cleanliness the screen shows only as a bar, said as a number.
    def self.results_text(rows)
      t = PokeAccess::PaintCapture.text(rows)
      t = PokeAccess::Util.join_parts([t, clean_text])
      t.empty? ? nil : t
    rescue StandardError
      nil
    end

    # The island's cleanliness, which the screens draw only as a bar, as a percentage; nil without the player.
    def self.clean_text
      clean = ($Trainer.dateSimClean rescue nil)
      clean ? PokeAccess::I18n.t(:rem_clean_pct, :n => clean.to_i) : nil
    end

    # The day SlideDay rolls to, and whether sleeping sent it back.
    # param forward false when the day went back
    def self.day_text(day, forward)
      PokeAccess::I18n.t(forward == false ? :rem_day_back : :rem_day, :n => day)
    end

    # The build screen's recipe table, row by row as painted, each have/need count with its own material and the
    # arrow before the build key said as a colon.
    def self.build_text(pairs)
      PokeAccess::PaintCapture.lines(pairs).map { |l| l.gsub(/\s*->\s*/, ": ") }.join(". ")
    end

    # The build screen's two tabs (@indexTask): every recipe, or only the current objective's.
    BUILD_TABS = [:rem_build_tab_all, :rem_build_tab_goal]

    # The tab word to say before the next table when the build screen's tab has just changed, or nil; the first
    # call only records the tab the screen opens on.
    def self.build_tab_change(scene)
      tab = PokeAccess.ivar(scene, :@indexTask)
      last = PokeAccess.ivar(scene, :@access_build_tab)
      scene.instance_variable_set(:@access_build_tab, tab)
      return nil if last.nil? || last == tab
      key = BUILD_TABS[tab.to_i]
      key ? PokeAccess::I18n.t(key) : nil
    end

    # The support levels of a pair the list colours (supportWrite): the ones already seen and the ones still to come
    # (supportCheck), or nil when the pair has none.
    def self.support_levels(name, partner)
      all = (supportWrite(name, partner) rescue nil)
      return nil unless all.is_a?(Array) && !all.empty?
      pending = (supportCheck(name, partner) rescue nil) || []
      seen = all.reject { |l| pending.include?(l) }
      parts = []
      parts.push(PokeAccess::I18n.t(:rem_dating_levels_seen, :list => seen.join(", "))) unless seen.empty?
      parts.push(PokeAccess::I18n.t(:rem_dating_levels_pending, :list => pending.join(", "))) unless pending.empty?
      parts.empty? ? nil : parts.join(". ")
    end
  end
end

PokeAccess::Game.define("reminiscencia") do
  after("DatingSimMainScreen", :setText) { |s, _r, _a| PokeAccess::ReminDatingSim.focus(s) }
  # The opening, which setText misses: the first label and the HUD, before main_loop (initialize calls it itself, so
  # an after-hook there would wait for the close).
  before("DatingSimMainScreen", :main_loop) do |s, _a|
    PokeAccess::ReminDatingSim.focus(s)
    PokeAccess::ReminDatingSim.hud(s)
  end

  # The day's results: drawData's title and "ITEMxN" rows plus its cleanliness bar as a number, said as it returns.
  around("DatingSimResultsScreen", :drawData, :optional => true) do |_s, nxt, _a|
    PokeAccess::PaintCapture.arm(:rem_results)
    begin
      nxt.call
    ensure
      PokeAccess.speak(PokeAccess::ReminDatingSim.results_text(PokeAccess::PaintCapture.take(:rem_results, :positions)), false)
    end
  end

  # SlideDay, the day counter sleeping rolls (animated in its constructor): the new day, and if it went back.
  after("SlideDay", :initialize, :optional => true) do |_s, _r, args|
    day = ($Trainer.dateDays rescue nil)
    PokeAccess.speak(PokeAccess::ReminDatingSim.day_text(day, args[1]), true) if day
  end

  # Task screen gender tabs (@indexGender 0 male, 1 female, 2 unknown): on setGenderPage, the tab's sign, or a word
  # for the third's question mark, which a screen reader drops.
  after("DatingSimTaskScreen", :setGenderPage) do |scene, _r, _a|
    g = PokeAccess.ivar(scene, :@indexGender)
    t = PokeAccess::Party.sign(g) || (g == 2 ? PokeAccess::I18n.t(:rem_dating_unknown) : nil)
    PokeAccess.speak(t, true) if t
  end

  # Support screen (@index the left character, @cmdwindow.index the partner): on updatePoints, when either moves,
  # the character's points, then the partner's with the required and combined totals.
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
      parts.push(PokeAccess::ReminDatingSim.support_levels(name, pname))
    end
    txt = parts.compact.join(". ")
    PokeAccess.speak_clean(txt, true)
  end
end

# The build screen's material table (recipe, header, each material beside its have/need count), captured row by row
# from drawDataWindow; after a tab switch (setWindowSelect), the tab's name leads it.
PokeAccess::Game.define("reminiscencia") do
  after("DatingSimBuildScreen", :setWindowSelect, :optional => true) do |scene, _r, _a|
    tab = PokeAccess::ReminDatingSim.build_tab_change(scene)
    scene.instance_variable_set(:@access_build_tab_word, tab) if tab
  end
  around("DatingSimBuildScreen", :drawDataWindow, :optional => true) do |scene, nxt, _a|
    PokeAccess::PaintCapture.arm(:rem_build)
    begin
      nxt.call
    ensure
      t = PokeAccess::ReminDatingSim.build_text(PokeAccess::PaintCapture.take_pairs(:rem_build))
      tab = PokeAccess.ivar(scene, :@access_build_tab_word)
      scene.instance_variable_set(:@access_build_tab_word, nil)
      if !t.empty? && (PokeAccess::Cursor.changed?(scene, :rem_build, t) || tab)
        PokeAccess.speak(PokeAccess.sentences([tab, t]), true)
      end
    end
  end
end

# The build screen's material list (Window_CommandPokemonCraftSim): each row with the quantity the dating bag holds,
# keyed by the window's translation list (a single row is the current objective, as in drawItem).
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
