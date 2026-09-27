module PokeAccess
  # FL's Roulette mini-game (RouletteScene, the Game Corner roulette of Ruby, Sapphire and Emerald): a table of COLUMNS
  # by ROWS cells beside the wheel, all pictures. The cursor bets on one cell, a whole column (from the header row) or a
  # whole row (from the header column); the bet's payout multiplier is painted in its box, and nothing is painted once
  # every cell of the bet has come up. The coins are painted in their box, and a spin ends with the ball on its cell.
  module FLRoulette
    # The bet under the cursor: one cell, or a whole row or column.
    def self.bet(cursor)
      x = cursor.indexX
      y = cursor.indexY
      return PokeAccess::I18n.t(:flr_row, :n => y) if x == 0
      return PokeAccess::I18n.t(:flr_column, :n => x) if y == 0
      PokeAccess::I18n.t(:mg_rowcol, :row => y, :col => x)
    end

    # The bet and its painted multiplier, or that all of it has come up.
    # param painted the rows pbDrawMultiplier painted
    def self.bet_text(scene, painted)
      cursor = PokeAccess.ivar(scene, :@cursor)
      return nil unless cursor
      mult = painted.map { |r| PokeAccess.clean(r[0]) }.find { |t| t =~ /\A\d+\z/ }
      pay = mult ? PokeAccess::I18n.t(:flr_multiplier, :n => mult) : PokeAccess::I18n.t(:flr_played)
      PokeAccess.sentences([bet(cursor), pay])
    rescue StandardError
      nil
    end

    # The cells a ball has come up on this board, row by row, for the info key.
    def self.played_text(scene)
      played = PokeAccess.ivar(scene, :@playedBalls) || []
      cols = scene.class::COLUMNS
      cells = []
      played.each_with_index do |hit, i|
        cells.push(PokeAccess::I18n.t(:mg_rowcol, :row => i / cols + 1, :col => i % cols + 1)) if hit
      end
      cells.empty? ? nil : PokeAccess::I18n.t(:flr_hits, :list => cells.join(", "))
    rescue StandardError
      nil
    end

    # Where the spin's ball fell.
    def self.landing(scene)
      r = PokeAccess.ivar(scene, :@result).to_i
      cols = scene.class::COLUMNS
      cell = PokeAccess::I18n.t(:mg_rowcol, :row => r / cols + 1, :col => r % cols + 1)
      PokeAccess::I18n.t(:flr_landed, :cell => cell)
    rescue StandardError
      nil
    end

    # The coins as the credit box paints them, once per change.
    def self.coins(scene, painted)
      n = painted.map { |r| PokeAccess.clean(r[0]) }.find { |t| t =~ /\A\d+\z/ }
      return if n.nil? || !PokeAccess::Cursor.changed?(scene, :fl_roulette_coins, n)
      PokeAccess.speak(PokeAccess::I18n.t(:mg_coins, :n => n.to_i), false)
    end
  end
end

PokeAccess::Hooks.around_hook("RouletteScene", :pbDrawMultiplier, :optional => true) do |scene, nxt, _a|
  r = nil
  pairs = PokeAccess::PaintCapture.sample { r = nxt.call }
  t = PokeAccess::FLRoulette.bet_text(scene, pairs)
  if t
    PokeAccess::Info.set_info(:text, PokeAccess.sentences([t, PokeAccess::FLRoulette.played_text(scene)]))
    PokeAccess.speak(t, true)
  end
  r
end

PokeAccess::Hooks.around_hook("RouletteScene", :pbDrawCredits, :optional => true) do |scene, nxt, _a|
  r = nil
  pairs = PokeAccess::PaintCapture.sample { r = nxt.call }
  PokeAccess::FLRoulette.coins(scene, pairs)
  r
end

# The ball on its cell comes before the messages that say whether the bet won.
PokeAccess::Hooks.before_hook("RouletteScene", :pbEndSpin, :optional => true) do |scene, _a|
  t = PokeAccess::FLRoulette.landing(scene)
  PokeAccess.speak(t, false) if t
end
