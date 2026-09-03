# Two Reminiscencia screens the generic readers cannot see, both driven by their own blocking loops.
#
# ScrollTree is the permanent stat-upgrade tree of the endless mode: @selec picks one of the five stats and
# the trainer keeps [cost, percent] pairs per stat in buffStatFriend / buffStatEnemy.
#
# The Hoopa gacha is deliberately NOT read here. The roulette hands its prize to pbAddPokemonRNG, and that
# function prints "<player> ha obtenido un <species>!" itself, which the message reader already speaks --
# so naming the prize here only said it twice. Worse, it is announced before the boxes are checked: with the
# boxes full the function refuses and prints its own refusal, so the player heard a prize they never got.
#
# AyudasUI is the in-game help. Its menu entries are pictures with no text at all, but the CONTENT of each
# section is real text: the game pushes _INTL strings into a textpos array and paints them with
# pbDrawTextPositions. So the reader captures that call while (and only while) this screen is on screen --
# outside it the capture is off, which keeps every other screen unaffected.
module PokeAccess
  module ReminExtras
    STATS = [:rem_st_atk, :rem_st_spatk, :rem_st_def, :rem_st_spdef, :rem_st_speed]
    @help = nil

    # Voices the focused stat of the upgrade tree with its current bonus and what the next level costs.
    #
    # The ROW is in the dedup key, not the cursor position. Buying an upgrade bumps the percentage and the
    # price in place and redraws, without moving the cursor -- so keyed on the index alone the one thing the
    # player pressed the button to hear, the numbers changing, was the one thing that stayed silent. The
    # failure path already speaks, through the game's own message.
    def self.scroll_tree(scene)
      idx = PokeAccess.ivar(scene, :@selec)
      return unless idx.is_a?(Integer) && idx >= 0 && idx < STATS.length
      key = [idx, ($Trainer.buffStatFriend[idx].dup rescue nil)]
      PokeAccess::Cursor.announce(scene, :rem_tree, key, true) do
        row = ($Trainer.buffStatFriend[idx] rescue nil)
        name = PokeAccess::I18n.t(STATS[idx])
        if row.is_a?(Array)
          PokeAccess::I18n.t(:rem_tree, :name => name, :pct => row[1].to_i, :cost => row[0].to_i)
        else
          name
        end
      end
    rescue StandardError
      nil
    end

    # Turns the text capture on while a capturing screen runs, and off again when it closes. The world map
    # reuses it for the same reason as the help screen: its drawInfo already composes the focused place's
    # name (or "???" when unvisited) and paints it, so capturing that call is both the simplest and the most
    # faithful reading -- it says exactly what a sighted player sees, including the unvisited placeholder.
    # Armed while one of the two capturing screens is painting. The dedup slot is cleared on entry, so
    # opening the same help section twice in a row still reads it, while a repeat INSIDE one painting pass
    # does not.
    def self.help_on(scene)
      @help = scene
      PokeAccess::Cursor.reset(scene, :rem_help_info)
    end

    def self.help_off
      PokeAccess::Cursor.reset(@list, :rem_help_list) if @list
      @help = nil
    end

    # The section list is held rather than hooked: its update IS the screen's loop, so an after-hook would
    # only fire on the way out. The loop pumps input every frame, which is what the poll rides.
    @list = nil

    def self.list_on(scene); @list = scene; end
    def self.list_off; @list = nil; end
    def self.list_poll; help_section(@list) if @list; end

    # The body of a help section. AyudasUI writes the paragraph the player opened the section for through
    # drawTextEx, whose text is argument 5, and its footer (and, in the controls section, its ten body lines)
    # through pbDrawTextPositions. Both are captured; queued rather than interrupting, so they follow each
    # other in the order the screen paints them.
    #
    # Only what is painted onto the help screen's OWN panel counts. One section opens a text-entry prompt
    # from inside the help loop, and that window draws through the same function -- so without this the help
    # read out the engine's "Enter text using the keyboard" instruction, in English, as if it were the help.
    def self.help_body(bitmap, text)
      return unless @help && bitmap
      panel = (PokeAccess.sprite(@help, "desc") rescue nil)
      return unless panel && (panel.bitmap.equal?(bitmap) rescue false)
      t = PokeAccess.clean(text.to_s).to_s.strip
      return if t.empty?
      PokeAccess.speak(t, false)
    rescue StandardError
      nil
    end

    # The section list of the help screen: ten unlabelled images, or a padlock where the section has not
    # been unlocked, so there is no text on screen to read. Each entry is named after the tag the section
    # checks before it will open -- the only word the game itself attaches to them -- and the padlock is
    # reported as the game reports it, by refusing to open with a buzzer.
    HELP_SECTIONS = [[nil, :rem_help_controls], ["pokemon", :rem_help_pokemon], ["objetos", :rem_help_items],
                     ["capturas", :rem_help_catching], ["phione", :rem_help_phione],
                     ["ubicaciones", :rem_help_places], ["auxilio", :rem_help_rescue],
                     ["alarmado", :rem_help_alarm], ["cartas", :rem_help_blessings],
                     ["cartas", :rem_help_upgrades]]

    # Speaks the focused section on every move, with its position and whether it is still locked.
    def self.help_section(scene)
      idx = PokeAccess.ivar(scene, :@index)
      total = (numeroOpcionesAyudas rescue HELP_SECTIONS.length)
      return unless idx.is_a?(Integer) && idx >= 0 && idx < HELP_SECTIONS.length
      tag, key = HELP_SECTIONS[idx]
      open = tag.nil? || ($Trainer.ayudasUI.include?(tag) rescue true)
      name = PokeAccess::I18n.t(key)
      name = "#{name}, #{PokeAccess::I18n.t(:rem_help_locked)}" unless open
      PokeAccess::Cursor.announce(scene, :rem_help_list, idx, true) do
        PokeAccess::I18n.t(:list_entry, :name => name, :n => idx + 1, :tot => total)
      end
    rescue StandardError
      nil
    end

    # True when the bitmap is the held screen's own text panel: AyudasUI paints every row batch onto
    # "desc", OpenWorldMap onto "info". Same fence as help_body -- without it any window drawing through
    # the shared function while the screen is up (the text-entry prompt) leaked into the reading.
    def self.own_panel?(bitmap)
      return false unless bitmap
      ["desc", "info"].any? do |n|
        p = (PokeAccess.sprite(@help, n) rescue nil)
        p && (p.bitmap.equal?(bitmap) rescue false)
      end
    end

    def self.help_text(bitmap, rows)
      return unless @help && rows.is_a?(Array)
      return unless own_panel?(bitmap)
      lines = []
      rows.each do |r|
        t = (r.is_a?(Array) ? r[0] : nil)
        t = PokeAccess.clean(t.to_s).to_s.strip if t
        lines.push(t) if t && !t.empty?
      end
      return if lines.empty?
      t = lines.join(". ")
      PokeAccess::Cursor.announce(@help, :rem_help_info, t, true) { t }
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("reminiscencia") do
  # positionSelector, not makeloop. makeloop IS the screen's blocking loop, so an after-hook on it fired once
  # -- on the way out -- and the five permanent upgrades were silent to navigate. positionSelector runs on
  # every UP/DOWN with @selec already updated, and once more at setup before the loop starts, so it covers
  # both the opening read and each move. Dropping the makeloop hook also un-suppresses raiseStat: it is
  # called from inside that loop, so the reentrancy guard was discarding it as nested.
  after("ScrollTree", :positionSelector) { |s, _r, _a| PokeAccess::ReminExtras.scroll_tree(s) }
  after("ScrollTree", :raiseStat) { |s, _r, _a| PokeAccess::ReminExtras.scroll_tree(s) }

  [["AyudasUI", :chosenOption], ["OpenWorldMap", :drawInfo]].each do |cname, meth|
    around(cname, meth) do |scene, nxt, _a|
      PokeAccess::ReminExtras.help_on(scene)
      begin
        nxt.call
      ensure
        PokeAccess::ReminExtras.help_off
      end
    end
  end
  around("AyudasUI", :update) do |s, nxt, _a|
    PokeAccess::ReminExtras.list_on(s)
    begin; nxt.call; ensure; PokeAccess::ReminExtras.list_off; end
  end
  # Both screens run whole from their constructor, called from INSIDE the pause menu's own loop and
  # registered nowhere in ReminMenu's stack -- so leaving them must nudge the menu into saying where the
  # cursor is again (the world map gets this for free by being a registered frame).
  [["AyudasUI", :initialize], ["ScrollTree", :initialize]].each { |cname, meth| PokeAccess::MenuReturn.bare(cname, meth) }
  poll_each_frame { PokeAccess::ReminExtras.list_poll }
  kernel("pbDrawTextPositions", :before) { |args, _r| PokeAccess::ReminExtras.help_text(args[0], args[1]) }
  kernel("drawTextEx", :before) { |args, _r| PokeAccess::ReminExtras.help_body(args[0], args[5]) }
end
