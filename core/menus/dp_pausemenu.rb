module PokeAccess
  # Shared reader for the Diamond/Pearl-style icon field menu (the DP_PauseMenu / PauseMenuDP plugin): a
  # sprite menu, not a Window_CommandPokemon, so the generic command hook never sees it. Its loop calls
  # update every frame and keeps the cursor in @option and the entries (each [label, ...]) in @options.
  # Several games bundle it; each profile (plus the generic fallback) registers a one-line hook
  # delegating here with its own options, so the body lives in one place.
  module DPMenu
    # Reads the focused entry on cursor change, deduped per menu instance (a reopened menu is a fresh
    # instance, so it reads its first option without any explicit reset). Options: :trainer_info sets the
    # contextual trainer info so the info key works while the menu is open; :relabel_trainer_card speaks the
    # player-name entry (the DP trainer-card convention) as "Trainer card" instead of the bare name.
    def self.read(menu, opts = {})
      PokeAccess::Info.set_info(:trainer, nil) if opts[:trainer_info]
      list = PokeAccess.ivar(menu, :@options)
      idx  = PokeAccess.ivar(menu, :@option)
      return unless list.is_a?(Array) && idx && list[idx]
      PokeAccess::Cursor.announce(menu, :dpmenu, idx) do
        label = list[idx][0].to_s
        if opts[:relabel_trainer_card]
          pname = (PokeAccess::Engine.player.name rescue nil)
          label = PokeAccess::I18n.t(:tc_title) if pname && !pname.to_s.empty? && label == pname
        end
        label
      end
    rescue StandardError
      nil
    end
  end
end
