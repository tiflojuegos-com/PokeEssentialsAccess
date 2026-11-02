# Essentials BES's battle, over the gen-6 scene the core reads: the Z-Move, Dynamax and Tera buttons the fight menu
# draws beside the Mega and Ultra Burst ones (zButton, dynaButton, teraButton, each 0 hidden, 1 shown, 2 registered; the
# menu paints only the first that is up, in the order of ORDER), the Dynamax itself, which the battle runs with no
# message, the ability strip its battlers slide in (showAbilityMessage, Elite Battle System's), the move type the fight
# buttons draw through the game's MoveTypeHelper, and the databox icons of the Ultra Burst, Dynamax and Tera states.
module PokeAccess
  module BesBattle
    BUTTONS = ["zButton=", "dynaButton=", "teraButton="]
    ORDER = [[:@megaButton, :mega], [:@dynaButton, :dynamax], [:@teraButton, :tera], [:@ultraButton, :ultra],
             [:@zButton, :zmove]]
    MINE = [:zmove, :dynamax, :tera]
    @pending = []

    # A button of a menu was set. The menu sets them all as it opens, in an order of its own, each first to 0, so the
    # change is judged once the frame ends, and a 0 forgets the button last painted.
    def self.touched(disp, value)
      disp.instance_variable_set(:@access_painted, nil) if value == 0
      @pending.push(disp) unless @pending.include?(disp)
    end

    # Judges the menus whose buttons were set since the last frame.
    def self.poll
      return if @pending.empty?
      menus, @pending = @pending, []
      menus.each { |disp| settle(disp) }
    end

    # The button the menu paints, the first up in its order, as [mechanic, state]; nil with none up.
    def self.painted(disp)
      ORDER.each do |ivar, mech|
        state = PokeAccess.ivar(disp, ivar)
        return [mech, state] if state.is_a?(Integer) && state > 0
      end
      nil
    end

    # Says the painted button's change when it is one of this plugin's: the core says the Mega and Ultra Burst ones. A
    # press can register another mechanic than the button painted (the key tries Dynamax before Z-Moves and Ultra Burst),
    # which counts as that mechanic's own button going from shown to registered.
    def self.settle(disp)
      now = painted(disp)
      was = PokeAccess.ivar(disp, :@access_painted)
      disp.instance_variable_set(:@access_painted, now)
      return unless now && MINE.include?(now[0])
      last = was ? (was[0] == now[0] ? was[1] : 1) : 0
      announce(disp, now[0], last, now[1])
    end

    # Says a mechanic button's change from its last state to v: that it is available as the button comes up, and that
    # it is on or off as it is registered or cancelled; a registered Dynamax renames the moves, which are read again.
    # param mech :zmove, :dynamax or :tera
    def self.announce(disp, mech, last, v)
      if PokeAccess::Battle.mega_reveal?(last, v)
        PokeAccess.speak(PokeAccess::Battle.ready_text(mech), false)
      elsif PokeAccess::Battle.mega_key(last, v)
        name = PokeAccess::I18n.t(PokeAccess::Battle::SPECIAL_NAMES[mech])
        line = PokeAccess::I18n.t(v == 2 ? :bt_special_on : :bt_special_off, :name => name)
        PokeAccess.speak(v == 2 && mech == :tera ? with_tera_type(disp, line) : line, true)
        reread_moves(disp) if mech == :dynamax
      end
    end

    # The line of a registered Tera with the type its button paints.
    def self.with_tera_type(disp, line)
      type = (PokeAccess.ivar(disp, :@battler).pokemon.teratype rescue nil)
      type ? "#{line}, #{PokeAccess::Data.type_name(type)}" : line
    end

    # The focused move again, whose name the registered mechanic changed.
    def self.reread_moves(disp)
      PokeAccess::Cursor.reset(disp, :fight_move)
      PokeAccess::Battle.read_fight_move(disp, false)
    end

    # A battler's Dynamax, which the battle runs with no message: who it was and whether it took its Gigantamax form.
    def self.dynamaxed(battle, index)
      b = (battle.battlers[index] rescue nil)
      return unless b && (b.isDynamax? rescue false)
      key = (b.isGigantamax? rescue false) ? :bes_gigantamaxed : :bes_dynamaxed
      PokeAccess.speak(PokeAccess::I18n.t(key, :name => PokeAccess.clean(b.pbThis.to_s)), false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Forgets the menus waiting to be judged.
    def self.reset
      @pending = []
    end

    # The type the fight button paints for a battler's move, which the game's helper works out from the Pokemon, the
    # weather and the field, or nil where the game has no helper.
    def self.drawn_type(move, battler)
      return nil unless defined?(::MoveTypeHelper)
      ::MoveTypeHelper.get_move_type(battler.pokemon, move, battler.battle)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Caches.register(:bes_battle) { PokeAccess::BesBattle.reset }

PokeAccess::BesBattle::BUTTONS.each do |setter|
  PokeAccess::Hooks.after_hook("FightMenuDisplay", setter.to_sym, :optional => true) do |disp, _r, args|
    PokeAccess::BesBattle.touched(disp, args[0])
  end
end

PokeAccess::Frame.each_pulse { PokeAccess::BesBattle.poll }

PokeAccess::Hooks.after_hook("PokeBattle_Battle", :pbDynamax, :optional => true,
                             :hook_container => true) do |battle, _r, args|
  PokeAccess::BesBattle.dynamaxed(battle, args[0])
end

PokeAccess::Hooks.after_hook("PokeBattle_Battler", :showAbilityMessage, :optional => true,
                             :hook_container => true) do |_b, _r, args|
  PokeAccess::BattleScene.hold_strip(args[0])
end

PokeAccess::Hooks.override(PokeAccess::Battle, :fight_type, :tag => "bes_battle") do |_mod, original, args|
  PokeAccess::BesBattle.drawn_type(args[0], args[1]) || original.call
end

PokeAccess::Battle.icon_mark(/\AbattleUltraBurstBox\z/i, :bt_m_ultra)
PokeAccess::Battle.icon_mark(/\AbattleDynamaxBox\z/i, :bt_m_dynamax)
PokeAccess::Battle.icon_mark(/\AteraTypes\z/i, :bt_m_tera)
