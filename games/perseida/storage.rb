# The PC panel of Perseida (pbUpdateOverlay in 0157_PScreen_Storage) draws a letter for each IV, the Pokemon's sign as a
# token and, over it, a mark on one that can Mega Evolve; said among the full details. A trade from the PC (0197_TradePC, the
# Wonder Trade's too) opens the same box with nothing to say what it is for, said after the first slot, which cuts in.
module PokeAccess
  module PerseidaStorage
    # The token's sign and mark, as rows of the panel's details.
    def self.sign_rows(pk)
      return [] unless pk.hasBirthsign?
      rows = [[PokeAccess::I18n.t(:perseida_sign, :name => pk.pbGetBirthsignName), :full]]
      rows.push([PokeAccess::I18n.t(:perseida_mega_able), :full]) if pk.hasMegaForm?
      rows
    rescue StandardError => e
      PokeAccess.swallowed(e)
      []
    end

    # Holds the line for when the trade's box has opened.
    def self.trade_opens
      @trade_pick = true
    end

    # What the box is for, once, as its first selection starts.
    def self.trade_pick
      return unless @trade_pick
      @trade_pick = false
      PokeAccess.speak(PokeAccess::I18n.t(:perseida_trade_pick), false)
    end
  end
end

PokeAccess::Game.define("perseida") do
  before("PokemonStorageScreen", :pbChooseTradePoke, :optional => true) { |_screen, _a| PokeAccess::PerseidaStorage.trade_opens }
  before("PokemonStorageScene", :pbSelectBox, :optional => true) { |_scene, _a| PokeAccess::PerseidaStorage.trade_pick }
  override("PokeAccess::Party", :pc_details) do |_mod, original, args|
    original.call + [[PokeAccess::PerseidaSummary.ivs(args[0]), :full]] + PokeAccess::PerseidaStorage.sign_rows(args[0])
  end
end
