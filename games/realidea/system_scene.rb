module PokeAccess
  # Realidea's "Vision Realidea" (SystemScene): icon menus whose cursor is a LOCAL variable inside each
  # blocking loop, so no clean hook can read it. We hold the scene during the loop (around-hook) and, since
  # the cursor never reaches an ivar, the scene's loop is left to run untouched while we speak the focused
  # option from a per-frame poll that tracks the cursor ourselves by mirroring the same key handling.
  #
  # The labels are fixed and known by position, so they come from i18n. We never reimplement the game's
  # actions: C and B fall through to the game, which owns all point spending and screen transitions. We only
  # track LEFT/RIGHT/UP/DOWN to know where the cursor is and announce it. If Realidea changes SystemScene's
  # navigation or option order, only the LISTS and the bounds in poll below need updating.
  #
  # The bounds are transcribed from the scene's own three loops, and the two families differ at the LEFT
  # edge, which is where the mirror used to drift apart from the game for good:
  #   - the wheel (startScene) wraps both ways. Its LEFT is TWO independent ifs, not an elsif: `select -= 1
  #     if select > 0` and then `select = 5 if select < 1`, so one press on the first option lands on the
  #     last. Clamping at the first option instead meant every later press named a different option than the
  #     one C would activate.
  #   - the grids (chooseCurar, chooseMO) clamp RIGHT at the last option and let LEFT walk down to 0. Index 0
  #     is a dead position: the scene's if/elsif chain has no branch for it, so it does not move the
  #     highlight and it does not act on C either. It must not be read as an option -- list[-1] is Ruby's
  #     last element, so "helpfully" reading it would announce the option at the far end of the menu -- but
  #     it must not be silent either, or a press that does nothing is indistinguishable from a press the
  #     reader missed. It is named for what it is.
  module RealideaSystem
    # Option labels per menu, in the game's 1-based select order.
    MAIN  = [:rl_sys_heal, :rl_sys_moves, :rl_sys_levelup, :rl_sys_magnifier, :rl_sys_repel]
    CURE  = [:rl_cure_20, :rl_cure_50, :rl_cure_80, :rl_cure_120, :rl_cure_200, :rl_cure_revive]
    MOVES = [:rl_mo_cut, :rl_mo_rocksmash, :rl_mo_flash, :rl_mo_strength, :rl_mo_fly]

    @active = nil
    @list = nil
    @sel = 1
    @last = nil
    @stack = []

    # Begins tracking a menu, saving the parent menu's state first. The menus nest (startScene opens chooseMO
    # from inside its own loop), so a stack is needed: stopping a child must restore its parent's tracking
    # instead of leaving it muted. Resets the cursor to the game's initial value (always 1). A nil list is a
    # held frame -- see hold.
    def self.start(list)
      @stack.push([@active, @list, @sel, @last])
      @active = true
      @list = list
      @sel = 1
      @last = nil
    end

    # A frame that tracks nothing, for a screen opened from INSIDE a menu's own loop. startScene opens the
    # party picker (PokemonScreen#pbChoosePokemon) and the repel step counter (pbMessageChooseNumber) that
    # way, so its ensure has not fired yet and its mirror was still armed underneath -- and both navigate
    # with the very same arrows, so every press moved the menu cursor too and announced an option from the
    # screen behind, over the top of the reader that owns that screen. Both have their own core readers.
    def self.hold
      start(nil)
    end

    # Restores the parent menu's tracking state, or clears it when no parent remains.
    def self.stop
      @active, @list, @sel, @last = @stack.pop || [nil, nil, 1, nil]
    end

    # Mirrors the scene's own navigation and speaks the focused option when it changes. Called once per frame
    # while a menu is active.
    #
    # Not while a message is up. These menus ask things from inside their own loops -- confirmations, level
    # prompts, item questions -- and every one of them RETURNS to the loop, so the mirror stays armed
    # underneath: the arrows that answer the question moved the mirror too, and it never moved back. One
    # question was enough to leave the menu naming the wrong option for the rest of the session. Explicit
    # holds cover the screens that replace the menu; this covers everything that merely sits on top of it,
    # which is most of them and grows every time the game adds a prompt.
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
      key = (@sel >= 1) ? @list[@sel - 1] : :rl_sys_none
      PokeAccess.speak(PokeAccess::I18n.t(key), true) if key
    rescue StandardError
      nil
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
  # chooseCurar is currently unreachable: the one call in startScene is commented out in the dump, and the
  # others are its own recursion after using an item. Kept bound and correct so the healing menu reads the
  # day the game re-enables it, rather than looking like a missing reader.
  around("SystemScene", :chooseCurar) do |scene, call_next, _a|
    PokeAccess::RealideaSystem.start(PokeAccess::RealideaSystem::CURE)
    begin; call_next.call; ensure; PokeAccess::RealideaSystem.stop; end
  end
  around("SystemScene", :chooseMO) do |scene, call_next, _a|
    PokeAccess::RealideaSystem.start(PokeAccess::RealideaSystem::MOVES)
    begin; call_next.call; ensure; PokeAccess::RealideaSystem.stop; end
  end
  # The screens the menus open from inside their own loops. Held rather than tracked: each is already read by
  # the core, and the only thing needed here is for the menu underneath to stop talking over it. Anything
  # that merely puts a message on top is handled by poll's own gate instead of being listed here.
  around("PokemonScreen", :pbChoosePokemon, :optional => true) do |_s, call_next, _a|
    PokeAccess::RealideaSystem.hold
    begin; call_next.call; ensure; PokeAccess::RealideaSystem.stop; end
  end
  # Raising a level walks off into the item flow and can end on the move-forget summary, a navigable screen
  # of its own with its own reader.
  around("SystemScene", :pbChangeLevel, :optional => true) do |_s, call_next, _a|
    PokeAccess::RealideaSystem.hold
    begin; call_next.call; ensure; PokeAccess::RealideaSystem.stop; end
  end
  kernel("pbMessageChooseNumber", :around) do |_args, nxt|
    PokeAccess::RealideaSystem.hold
    begin; nxt.call; ensure; PokeAccess::RealideaSystem.stop; end
  end
  poll_each_frame { PokeAccess::RealideaSystem.poll }
end
