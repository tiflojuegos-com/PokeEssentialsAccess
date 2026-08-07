module PokeAccess
  # Shared reader for the Diamond/Pearl-style icon field menu (the DP_PauseMenu / PauseMenuDP plugin): a
  # sprite menu, not a Window_CommandPokemon, so the generic command hook never sees it. Its loop calls
  # update every frame and keeps the cursor in @option and the entries (each [label, ...]) in @options.
  # Several games bundle it; each profile (plus the generic fallback) registers a one-line hook
  # delegating here with its own options, so the body lives in one place.
  module DPMenu
    # Reads the focused entry on cursor change, deduped per menu instance (a reopened menu is a fresh
    # instance, so it reads its first option without any explicit reset). Option :trainer_info sets the
    # contextual trainer info so the info key works while the menu is open.
    #
    # Labels go through Menus.button_label, which names the trainer card where the menu labels it with the
    # player's name -- the DP convention, and shared with the two sprite-button menus.
    def self.read(menu, opts = {})
      PokeAccess::Info.set_info(:trainer, nil) if opts[:trainer_info]
      list = PokeAccess.ivar(menu, :@options)
      idx  = PokeAccess.ivar(menu, :@option)
      return unless list.is_a?(Array) && idx && list[idx]
      PokeAccess::Cursor.announce(menu, :dpmenu, idx) do
        PokeAccess::Menus.button_label(list[idx][0])
      end
    rescue StandardError
      nil
    end

    @menu = nil

    def self.watch(menu); @menu = menu; end
    def self.unwatch; @menu = nil; end

    # Coming back from a submenu. Every entry is a proc the loop calls inline and then carries on; the loop's
    # redraw block only runs when the cursor MOVED, so the menu reappeared on the same icon and said nothing.
    # Clearing the slot makes the next update place the player again.
    #
    # Two signals cover both kinds of entry: the ones that leave the screen return through pbFadeOutIn, and
    # the ones that only put up a dialogue return through a message box. Both are gated on the menu's own
    # loop being held, so nothing happens while it is closed.
    def self.returned
      PokeAccess::Cursor.reset(@menu, :dpmenu) if @menu
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.around_hook("DP_PauseMenu", :main, :optional => true) do |menu, nxt, _a|
  PokeAccess::DPMenu.watch(menu)
  begin; nxt.call; ensure; PokeAccess::DPMenu.unwatch; end
end

%w[pbFadeOutIn pbMessage pbConfirmMessage].each do |fn|
  PokeAccess::Hooks.wrap_kernel(fn, "dpmenu_return_#{fn}", :after) do |_args, _r|
    PokeAccess::DPMenu.returned
  end
end
