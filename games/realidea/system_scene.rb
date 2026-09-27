module PokeAccess
  # Realidea's "Vision Realidea" (SystemScene): icon menus whose cursor is a local of each blocking loop, so a
  # per-frame poll mirrors their arrow handling and says the fixed labels. The wheel wraps; the grids clamp
  # right and let left reach 0, a dead position said as such.
  module RealideaSystem
    # Option labels per menu, in the game's 1-based select order.
    MAIN  = [:rl_sys_heal, :rl_sys_moves, :rl_sys_levelup, :rl_sys_magnifier, :rl_sys_repel]
    CURE  = [:rl_cure_20, :rl_cure_50, :rl_cure_80, :rl_cure_120, :rl_cure_200, :rl_cure_revive]
    MOVES = [:rl_mo_cut, :rl_mo_rocksmash, :rl_mo_flash, :rl_mo_strength, :rl_mo_fly]

    # The switch that lights each ability's icon in chooseMO (faded while off).
    MOVE_SWITCHES = [142, 143, 153, 144, 86]

    @active = nil
    @list = nil
    @sel = 1
    @last = nil
    @stack = []

    # Tracks a menu from option 1, stacking the parent menu's state (menus nest); a nil list is a held frame.
    def self.start(list)
      @stack.push([@active, @list, @sel, @last])
      @active = true
      @list = list
      @sel = 1
      @last = nil
      @points = list.equal?(MAIN)
    end

    # Pushes a frame that tracks nothing, so a screen opened inside a menu's loop does not move the menu too.
    def self.hold
      start(nil)
    end

    # Restores the parent menu's tracking, or clears it, forgetting its focus so the option is read again.
    # param forget false to keep what the menu had said (see unhold)
    def self.stop(forget = true)
      @active, @list, @sel, @last = @stack.pop || [nil, nil, 1, nil]
      @last = nil if forget
    end

    # Ends a held frame without re-reading the menu underneath, which is not back on screen yet.
    def self.unhold
      stop(false)
    end

    # Each frame a menu is tracked: mirrors its arrow handling and says the focused option when it changes. Not
    # while a message is up, whose arrows answer the message.
    def self.poll
      return unless @active && @list
      return if ($game_temp.message_window_showing rescue false)
      max = @list.size
      if Input.trigger?(Input::RIGHT)
        @sel = (@sel < max) ? @sel + 1 : (wheel? ? 1 : @sel)
      elsif Input.trigger?(Input::LEFT)
        @sel = (@sel > 1) ? @sel - 1 : (wheel? ? max : 0)
      elsif Input.trigger?(Input::DOWN)
        @sel += 3 if grid? && @sel + 3 <= max
      elsif Input.trigger?(Input::UP)
        @sel -= 3 if grid? && @sel - 3 >= 1
      end
      return if @sel == @last
      @last = @sel
      t = label(@sel)
      PokeAccess.speak(t, true) if t
      say_points if @points
    rescue StandardError
      nil
    end

    # The focused option, and on the abilities grid whether its icon is lit.
    def self.label(sel)
      key = (sel >= 1) ? @list[sel - 1] : :rl_sys_none
      return nil unless key
      t = PokeAccess::I18n.t(key)
      off = @list.equal?(MOVES) && sel >= 1 && !($game_switches[MOVE_SWITCHES[sel - 1]] rescue true)
      off ? "#{t}, #{PokeAccess::I18n.t(:opt_unavailable)}" : t
    end

    # The points the wheel shows in its middle as five digit pictures (variable 50), which every option
    # spends: said once as the wheel opens, after its first option.
    def self.say_points
      @points = false
      n = ($game_variables[50] rescue nil)
      PokeAccess.speak(PokeAccess::I18n.t(:rl_sys_points, :n => n.to_i), false) if n
    end

    # The wheel wraps at both ends and has no vertical movement; the grids step by 3 and clamp.
    def self.wheel?
      @list.equal?(MAIN)
    end

    def self.grid?
      @list.equal?(CURE) || @list.equal?(MOVES)
    end
  end
end

PokeAccess::Game.define("realidea") do
  around("SystemScene", :startScene) do |scene, call_next, _a|
    PokeAccess::RealideaSystem.start(PokeAccess::RealideaSystem::MAIN)
    begin; call_next.call; ensure; PokeAccess::RealideaSystem.stop; end
  end
  # chooseCurar, unreachable in the current game (its call is commented out), kept for when it is re-enabled.
  around("SystemScene", :chooseCurar) do |scene, call_next, _a|
    PokeAccess::RealideaSystem.start(PokeAccess::RealideaSystem::CURE)
    begin; call_next.call; ensure; PokeAccess::RealideaSystem.stop; end
  end
  around("SystemScene", :chooseMO) do |scene, call_next, _a|
    PokeAccess::RealideaSystem.start(PokeAccess::RealideaSystem::MOVES)
    begin; call_next.call; ensure; PokeAccess::RealideaSystem.stop; end
  end
  # Screens the menus open inside their loops, held so the menu underneath keeps quiet; core reads them.
  around("PokemonScreen", :pbChoosePokemon, :optional => true) do |_s, call_next, _a|
    PokeAccess::RealideaSystem.hold
    begin; call_next.call; ensure; PokeAccess::RealideaSystem.unhold; end
  end
  # Raising a level can end on the move-forget summary, which has its own reader.
  around("SystemScene", :pbChangeLevel, :optional => true) do |_s, call_next, _a|
    PokeAccess::RealideaSystem.hold
    begin; call_next.call; ensure; PokeAccess::RealideaSystem.unhold; end
  end
  kernel("pbMessageChooseNumber", :around) do |_args, nxt|
    PokeAccess::RealideaSystem.hold
    begin; nxt.call; ensure; PokeAccess::RealideaSystem.unhold; end
  end
  poll_each_frame { PokeAccess::RealideaSystem.poll }
end
