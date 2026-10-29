# World Frontier's rental and swap screens (Crucero Batalla, 002_Prestamo.rb), which replace the stock Battle Factory
# lists with balls on a conveyor belt and Pokemon icons, the instruction in a help window under them. The instruction
# is said when it changes and the focused ball as the Pokemon its icon shows, with its place and, renting, whether it
# was chosen; the menus and questions go through UIHelper, which the core reads, and the info key holds the Pokemon.
module PokeAccess
  module WfRental
    # A Pokemon as the icons show it, with its place in its row and the chosen mark where it carries one.
    def self.ball_line(pk, idx, total, chosen = false)
      name = (pk.speciesName rescue nil) || PokeAccess::Data.species_name(pk.species)
      name = "#{name}, #{PokeAccess::I18n.t(:swap_chosen)}" if chosen
      PokeAccess::Verbosity.list_entry(name.to_s, idx + 1, total)
    end

    # The rental screen after each repaint of its top slots: the instruction while Pokemon are left to choose (said
    # first when its count changes), then the focused ball.
    def self.rental(scene)
      rentals = PokeAccess.ivar(scene, :@rentals)
      idx = PokeAccess.ivar(scene, :@index)
      chosen = PokeAccess.ivar(scene, :@chosen)
      return unless rentals.is_a?(Array) && idx.is_a?(Integer) && chosen.is_a?(Array) && rentals[idx]
      opening = PokeAccess::Cursor.pending?(scene, :wf_rent_help)
      left = 3 - chosen.length
      told = false
      if PokeAccess::Cursor.changed?(scene, :wf_rent_help, left) && left > 0
        PokeAccess.speak_clean(_INTL("Elige {1} Pokémon para combatir.", left), !opening)
        told = true
      end
      pk = rentals[idx]
      PokeAccess::Info.set_info(:pokemon, pk)
      line = ball_line(pk, idx, rentals.length, chosen.include?(idx))
      PokeAccess::Cursor.announce(scene, :wf_rent, [idx, chosen.include?(idx)], !(opening || told), false) { line }
    end

    # The swap screen's instruction for its phase, as its help window paints it.
    def self.swap_help_text(scene)
      if PokeAccess.ivar(scene, :@phase) == :pick_rival
        _INTL("Elige uno de los Pokémon rivales para llevártelo.")
      else
        _INTL("Elige el Pokémon de tu equipo que será cambiado.")
      end
    end

    # The swap screen's instruction, once per phase; the first one queued.
    def self.swap_help(scene)
      return if PokeAccess.ivar(scene, :@access_phasing)
      opening = PokeAccess::Cursor.pending?(scene, :wf_swap_help)
      return unless PokeAccess::Cursor.changed?(scene, :wf_swap_help, PokeAccess.ivar(scene, :@phase))
      PokeAccess.speak_clean(swap_help_text(scene), !opening)
    end

    # The swap screen's focused Pokemon: a rival ball while one is picked, the player's own while the one to give is.
    def self.swap_focus(scene, interrupt = true)
      return if PokeAccess.ivar(scene, :@access_phasing)
      phase = PokeAccess.ivar(scene, :@phase)
      list, idx = phase == :pick_rival ? [:@rivals, :@idx_rival] : [:@my, :@idx_mine]
      mons = PokeAccess.ivar(scene, list)
      i = PokeAccess.ivar(scene, idx)
      return unless mons.is_a?(Array) && i.is_a?(Integer) && mons[i]
      PokeAccess::Info.set_info(:pokemon, mons[i])
      line = ball_line(mons[i], i, mons.length)
      PokeAccess::Cursor.announce(scene, :wf_swap, [phase, i], interrupt, false) { line }
    end

    # A phase change: its instruction, then the Pokemon it focuses, queued.
    def self.phase_changed(scene)
      PokeAccess::Cursor.store(scene, :wf_swap_help, PokeAccess.ivar(scene, :@phase))
      PokeAccess.speak_clean(swap_help_text(scene), true)
      PokeAccess::Cursor.reset(scene, :wf_swap)
      swap_focus(scene, false)
    end
  end
end

PokeAccess::Game.define("worldfrontier") do
  after("RentalChooseScene", :refresh_top_slots) { |scene, _r, _a| PokeAccess::WfRental.rental(scene) }
  after("SwapChooseScene", :refresh_help_text) { |scene, _r, _a| PokeAccess::WfRental.swap_help(scene) }
  after("SwapChooseScene", :update_cursor_position) { |scene, _r, _a| PokeAccess::WfRental.swap_focus(scene) }
  after("SwapChooseScene", :reset_blink) { |scene, _r, _a| PokeAccess::WfRental.swap_focus(scene) }
  # set_phase repaints the help and moves the focus in its own order; both are said after it, help first.
  around("SwapChooseScene", :set_phase) do |scene, nxt, _a|
    scene.instance_variable_set(:@access_phasing, true)
    begin
      nxt.call
    ensure
      scene.instance_variable_set(:@access_phasing, nil)
      begin
        PokeAccess::WfRental.phase_changed(scene)
      rescue StandardError => e
        PokeAccess.swallowed(e)
      end
    end
  end
end
