module PokeAccess
  # Insurgence's own rules for the field moves the route finder asks about, in place of Essentials' "a party Pokemon
  # knows it and the badge is won" (088_PokemonHiddenMoves.rb as 166_PokemonFollow.rb and 179_ChallengeChampionship.rb
  # redefine it). Waterfall's move can never be used (its CanUseMove fails): six badges and the Magic Carpet take it.
  module InsurgenceFieldMoves
    # The moves Kernel.pbStrength accepts, in its own order.
    STRENGTH_MOVES = [:STRENGTH, :BULLDOZE, :STEAMROLLER, :OMINOUSWIND, :ICYWIND, :GIGAIMPACT, :SLAM, :WHIRLWIND,
                      :ROCKTHROW, :HEAVYSLAM, :BARRAGE, :PSYCHIC, :HEADBUTT]
    # The items that stand in for a move here, by the move.
    ITEMS = { :WATERFALL => :JETPACK, :DIVE => :SCUBAGEAR, :ROCKCLIMB => :HIKINGBOOTS }
    # The switch the first gym sets, which Surf and Strength ask for.
    GYM1 = 4
    # The switch the stock Kernel.pbRockSmash asks for before the move or the Pickaxe.
    ROCK_SWITCH = 10
    # The switch Kernel.pbCut asks for before the move.
    CUT_SWITCH = 6

    # True for a move whose rule this game rewrites.
    def self.handles?(move)
      [:SURF, :STRENGTH, :ROCKSMASH, :CUT].include?(move) || ITEMS.key?(move)
    end

    # true / false / nil (unreadable) for a move handles? covers, by the game's rule.
    def self.can?(move)
      return bag?(ITEMS[move]) if move == :DIVE || move == :ROCKCLIMB
      case move
      when :SURF
        return false unless $game_switches[GYM1]
        bag?(:LAPRAS) ? true : PokeAccess::FieldMoves.knows?(:SURF)
      when :WATERFALL
        n = (PokeAccess::Engine.player.numbadges rescue nil)
        return nil if n.nil?
        n >= badges_for_waterfall ? bag?(:JETPACK) : false
      when :STRENGTH
        return true if ($PokemonMap.strengthUsed rescue false)
        return false unless $game_switches[GYM1]
        party.nil? ? nil : !strength_move.nil?
      when :ROCKSMASH
        party.nil? ? nil : !fighting_move.nil?
      when :CUT
        $game_switches[CUT_SWITCH] ? PokeAccess::FieldMoves.knows?(:CUT) : false
      end
    end

    # The badge count Waterfall asks for (BADGEFORWATERFALL, a count here), 6 without the setting.
    def self.badges_for_waterfall
      (Object.const_get(:BADGEFORWATERFALL) rescue 6).to_i
    end

    # Whether the bag holds the item named by the symbol, nil when there is no bag or no such item.
    def self.bag?(sym)
      id = (PBItems.const_get(sym) rescue nil)
      return nil if id.nil?
      n = PokeAccess::Engine.bag_quantity(id)
      n.nil? ? nil : n > 0
    end

    # True for a gate on a "Rock" whose page calls the stock Kernel.pbRockSmash rather than doInsurgenceRockSmash.
    def self.stock_rock?(gate)
      return false unless gate[:move] == :ROCKSMASH && gate[:ev]
      PokeAccess::Routes::Effects.script_text(gate[:ev]) =~ /\bpbRockSmash\b/ ? true : false
    end

    # true / false / nil: whether the stock Kernel.pbRockSmash breaks a rock now, by switch 10 and then the Pickaxe or
    # a Pokemon that knows Rock Smash.
    def self.stock_rock_clear?
      return false unless $game_switches[ROCK_SWITCH]
      bag?(:PICKAXE) ? true : PokeAccess::FieldMoves.knows?(:ROCKSMASH)
    end

    # Rock Smash as the game spells it, for the stock rocks (the name override says the Fighting move instead).
    def self.rock_smash_name
      PokeAccess::Data.move_name(PokeAccess::Data.move_id(:ROCKSMASH))
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The party, or nil with no player.
    def self.party
      (PokeAccess::Engine.player.party rescue nil)
    end

    # The first move, in party order, that Kernel.pbStrength would use: its id, or nil.
    def self.strength_move
      ids = STRENGTH_MOVES.map { |m| (PBMoves.const_get(m) rescue nil) }.compact
      each_move { |mv| return mv.id if ids.include?(mv.id) }
      nil
    end

    # The first damaging Fighting-type move, in party order, that doInsurgenceRockSmash would use: its id, or nil.
    def self.fighting_move
      fighting = (PBTypes.const_get(:FIGHTING) rescue nil)
      return nil if fighting.nil?
      each_move { |mv| return mv.id if mv.id.to_i > 0 && mv.type == fighting && mv.basedamage.to_i > 0 }
      nil
    end

    # Yields every move of every party Pokemon, eggs included, as the game's own loops go through them.
    def self.each_move
      (party || []).each do |pk|
        ((pk.moves rescue nil) || []).each { |mv| yield mv if mv }
      end
    end

    # What the guide names for a move this game rewrites: the move the game will pick, the item it asks for, or for a
    # rock with no move to break it, what it takes; nil leaves the move's own name.
    def self.name(move)
      case move
      when :STRENGTH
        id = strength_move
        id ? PokeAccess::Data.move_name(id) : nil
      when :ROCKSMASH
        id = fighting_move
        id ? PokeAccess::Data.move_name(id) : PokeAccess::I18n.t(:ins_fighting_move)
      when :WATERFALL, :DIVE, :ROCKCLIMB
        id = (PBItems.const_get(ITEMS[move]) rescue nil)
        id ? PokeAccess::Data.item_name(id) : nil
      end
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Game.define("insurgence") do
  override("PokeAccess::FieldMoves", :can?) do |_mod, original, args|
    PokeAccess::InsurgenceFieldMoves.handles?(args[0]) ? PokeAccess::InsurgenceFieldMoves.can?(args[0]) : original.call
  end
  override("PokeAccess::FieldMoves", :name) do |_mod, original, args|
    n = PokeAccess::InsurgenceFieldMoves.name(args[0])
    n.nil? || n.to_s.empty? ? original.call : n
  end
  override("PokeAccess::FieldMoves", :clear?) do |_mod, original, args|
    ins = PokeAccess::InsurgenceFieldMoves
    ins.stock_rock?(args[0]) ? ins.stock_rock_clear? : original.call
  end
  override("PokeAccess::FieldMoves", :clearer) do |_mod, original, args|
    ins = PokeAccess::InsurgenceFieldMoves
    n = ins.stock_rock?(args[0]) ? ins.rock_smash_name : nil
    n.nil? || n.to_s.empty? ? original.call : n
  end
end
