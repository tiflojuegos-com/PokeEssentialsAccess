module PokeAccess
  # Soulstones' edit of FL's HMs as Items (0236_HM_Items.rb): a PokeGear app in the bag stands in for each of six
  # field moves, by the item constant Kernel.pbCut and the rest check; the move's badge is wanted either way, since
  # those checks refuse without it before looking at the app or the party.
  module Soulstones1FieldMoves
    # The app each move takes, by the item constant the script asks the bag for.
    APPS = { :CUT => :CUTITEM, :ROCKSMASH => :ROCKSMAMUKEM, :STRENGTH => :STRENGTHITEM, :SURF => :SURFITEM,
             :DIVE => :DIVEITEM, :WATERFALL => :WATERFALLITEM }

    # Whether an item stands in for the move now: the core's answer, as long as the move's badge has been won.
    # param ready what the core's item check answered
    def self.item_ready?(move, ready)
      (ready && PokeAccess::FieldMoves.badge_ok?(move)) ? true : false
    end
  end
end

PokeAccess::Game.define("soulstones1") do
  PokeAccess::Soulstones1FieldMoves::APPS.each { |move, app| field_move_item(move, app) }
  override("PokeAccess::FieldMoves", :item_ready?) do |_mod, original, args|
    PokeAccess::Soulstones1FieldMoves.item_ready?(args[0], original.call)
  end
end
