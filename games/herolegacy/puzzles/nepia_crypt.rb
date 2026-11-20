# Nepia's crypt, Yveltal's chamber (map 256): seven rows of candles, each with a plate in column 16 that adds one to its
# row's variable (45 to 51) per step. A row's candle number v burns blue while its variable holds v; the second row has
# four candles, the others seven. A parallel event wakes Yveltal (its self switch A) once the rows hold 7, 3, 5, 4, 4, 4
# and 4. Skelabra (event 1) sets them all back to 0; it shows up once Ziva has heard what the player found (her
# scene turns its self switch A on). Each plate can be stepped on from column 15 without touching another.
module PokeAccess
  module HeroLegacyCandles
    MAP = 256
    PLATES = [8, 5, 17, 26, 34, 42, 50]
    FIRST_VAR = 45
    TARGET = [7, 3, 5, 4, 4, 4, 4]
    CANDLES = [7, 4, 7, 7, 7, 7, 7]

    # True once Yveltal has woken.
    def self.solved?
      $game_self_switches[[MAP, 58, "A"]] || $game_switches[125]
    end

    # A row's value word: the blue candle's number, or none when no candle of the row burns blue.
    def self.words(row)
      w = {}
      (0..60).each { |v| w[v] = :hl_nepia_none if v == 0 || v > CANDLES[row] }
      w
    end

    # The Pokémon that puts the candles out, by the game's name.
    def self.keeper
      PokeAccess::Data.species_name(:CHANDELURE).to_s
    end

    # True once Skelabra stands in the chamber.
    def self.keeper_here?
      $game_self_switches[[MAP, 1, "A"]] || $game_switches[125] ? true : false
    end

    # The room's rule, with Skelabra's reset once it is there.
    def self.rule
      keeper_here? ? [:hl_nepia_rule, { :name => keeper }] : :hl_nepia_rule_plain
    end

    # The assist's line: the steps each row's plate still needs, or the keeper when a row has gone past.
    def self.hint
      rows = []
      TARGET.each_with_index do |want, i|
        have = $game_variables[FIRST_VAR + i].to_i
        return [keeper_here? ? :hl_nepia_over : :hl_nepia_over_ziva, { :name => keeper }] if have > want
        rows << PokeAccess::I18n.t(:hl_nepia_row_steps, :n => i + 1, :steps => want - have) if have < want
      end
      [:hl_nepia_hint, { :rows => rows.join("; ") }]
    end
  end
end

PokeAccess::Game.define("herolegacy") do
  candles = PokeAccess::HeroLegacyCandles
  rows = (0...candles::PLATES.length).map do |i|
    { :var => candles::FIRST_VAR + i, :label => [:hl_nepia_row, { :n => i + 1 }], :event => candles::PLATES[i],
      :words => candles.words(i) }
  end
  mechanic(:state, candles::MAP) do
    auto
    candles::PLATES.each_with_index { |id, i| name id, [:hl_nepia_plate, { :n => i + 1 }] }
    phase lambda { !candles.solved? }, :quiet => true, :values => rows, :hint => lambda { candles.hint }
    arrival_hint lambda { candles.rule }
    solved { candles.solved? }
  end
end
