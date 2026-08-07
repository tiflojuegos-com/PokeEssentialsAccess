# Relict's radial pause menu (ArcyGame edit of PokemonPauseMenu_Scene: a 6-button ring, no command window,
# so the standard pause/generic readers never see it). @index (0-5) is the cursor and update_button redraws
# the highlighted button on every move; the buttons are images, so the spoken label is mapped from the index
# following the screen's own `case @index` (party / bag / encounters / save / options / return to checkpoint).
module PokeAccess
  module RelictMenu
    # The buttons are images, and the game loads a different set per language, so the labels come from lang/
    # rather than from literals here.
    RADIAL = [:rel_radial_party, :rel_radial_bag, :rel_radial_encounters,
              :rel_radial_save, :rel_radial_options, :rel_radial_checkpoint]

    # Speaks the focused button, once per change.
    def self.announce(scene)
      idx = PokeAccess.ivar(scene, :@index)
      return unless idx && idx >= 0
      return unless PokeAccess::Cursor.changed?(scene, :radial, idx)
      key = RADIAL[idx]
      label = key ? PokeAccess::I18n.t(key) : nil
      PokeAccess.speak(label, true) if label && !label.to_s.empty?
    rescue StandardError
      nil
    end

    @scene = nil

    def self.watch(scene); @scene = scene; end
    def self.unwatch; @scene = nil; end
    def self.poll; announce(@scene) if @scene; end

    # Coming back from a subscreen. pickCommand opens the bag, the party and the rest INLINE and then just
    # carries on looping: update_button never runs again, so the menu returned in silence with the cursor
    # somewhere the player could no longer hear. Clearing the slot makes the next poll say it again.
    #
    # Two signals, because the options split in two: the ones that leave the screen come back through
    # pbFadeOutIn, and the ones that only put up a dialogue -- a cancelled save, a refused checkpoint, the
    # empty-party notice -- come back through a message box that ends with the ring still on screen. Both are
    # scoped to the held scene, so they cost nothing when the menu is closed.
    def self.returned
      PokeAccess::Cursor.reset(@scene, :radial) if @scene
    rescue StandardError
      nil
    end

    @depth = 0

    # Las tres señales anidan: una pbMessage dentro de la pantalla de guardado, un pbFadeOutIn dentro de la
    # mochila. Solo la SALIDA de la más externa devuelve el anillo al frente; soltar la ranura desde dentro
    # hace que el poll del frame siguiente cante el botón por encima de la pantalla hija, que es la que el
    # jugador tiene delante.
    def self.enter!; @depth += 1; end

    def self.leave!
      @depth = [@depth - 1, 0].max
      returned if @depth == 0
    end

    def self.reset_nesting; @depth = 0; end
  end
end

PokeAccess::Game.define("relict") do
  after("PokemonPauseMenu_Scene", :update_button) do |scene, _ret, _args|
    PokeAccess::RelictMenu.announce(scene)
  end
  # pickCommand IS the menu's loop, so it is held rather than hooked after: an after-hook would fire on the
  # way out. The poll covers both the opening read and the return from a subscreen.
  around("PokemonPauseMenu_Scene", :pickCommand) do |scene, nxt, _a|
    PokeAccess::RelictMenu.watch(scene)
    PokeAccess::RelictMenu.reset_nesting
    begin; nxt.call; ensure; PokeAccess::RelictMenu.unwatch end
  end
  %w[pbFadeOutIn pbMessage pbConfirmMessage].each do |fn|
    kernel(fn, :around) do |_args, nxt|
      PokeAccess::RelictMenu.enter!
      begin; nxt.call; ensure; PokeAccess::RelictMenu.leave! end
    end
  end
  poll_each_frame { PokeAccess::RelictMenu.poll }
end
