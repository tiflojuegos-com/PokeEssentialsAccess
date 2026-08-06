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
    def self.scroll_tree(scene)
      idx = PokeAccess.ivar(scene, :@selec)
      return unless idx.is_a?(Integer) && idx >= 0 && idx < STATS.length
      PokeAccess::Cursor.announce(scene, :rem_tree, idx, true) do
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
    def self.help_on(scene); @help = scene; end
    def self.help_off; @help = nil; end

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

    def self.help_text(rows)
      return unless @help && rows.is_a?(Array)
      lines = []
      rows.each do |r|
        t = (r.is_a?(Array) ? r[0] : nil)
        t = PokeAccess.clean(t.to_s).to_s.strip if t
        lines.push(t) if t && !t.empty?
      end
      return if lines.empty?
      PokeAccess.speak(lines.join(". "), true)
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
  kernel("pbDrawTextPositions", :before) { |args, _r| PokeAccess::ReminExtras.help_text(args[1]) }
  kernel("drawTextEx", :before) { |args, _r| PokeAccess::ReminExtras.help_body(args[0], args[5]) }
end
