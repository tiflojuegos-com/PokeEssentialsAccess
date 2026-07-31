# Three Reminiscencia screens the generic readers cannot see, all driven by their own blocking loops.
#
# ScrollTree is the permanent stat-upgrade tree of the endless mode: @selec picks one of the five stats and
# the trainer keeps [cost, percent] pairs per stat in buffStatFriend / buffStatEnemy.
#
# HoopaGacha spins a roulette and shows the prize as a sprite only -- it never says which Pokemon you got.
# The scene does build the real Pokemon into @dummy to draw it, so that is what gets voiced.
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

    # Voices the gacha prize once the roulette has settled: the species the scene just built to draw it.
    def self.gacha(scene)
      pk = PokeAccess.ivar(scene, :@dummy)
      return unless pk
      sp = (pk.species rescue nil)
      name = (PokeAccess::Data.species_name(sp) || sp.to_s)
      return if name.nil? || name.to_s.empty?
      PokeAccess::Cursor.announce(scene, :rem_gacha, name, true) do
        PokeAccess::I18n.t(:rem_gacha, :name => name)
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

    # Collects one pbDrawTextPositions call made by the help screen and speaks its lines in order. Each entry
    # is [text, x, y, align, ...]; only the strings matter here.
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
  after("ScrollTree", :makeloop) { |s, _r, _a| PokeAccess::ReminExtras.scroll_tree(s) }
  after("ScrollTree", :raiseStat) { |s, _r, _a| PokeAccess::ReminExtras.scroll_tree(s) }
  after("HoopaGacha", :setPokePic) { |s, _r, _a| PokeAccess::ReminExtras.gacha(s) }

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
end
