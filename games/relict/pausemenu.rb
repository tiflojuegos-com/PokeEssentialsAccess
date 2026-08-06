# Relict's radial pause menu (ArcyGame edit of PokemonPauseMenu_Scene: a 6-button ring, no command window,
# so the standard pause/generic readers never see it). @index (0-5) is the cursor and update_button redraws
# the highlighted button on every move; the buttons are images, so the spoken label is mapped from the index
# following the screen's own `case @index` (party / bag / encounters / save / options / return to checkpoint).
module PokeAccess
  module RelictMenu
    RADIAL = ["Equipo", "Mochila", "Encuentros", "Guardar", "Opciones", "Volver al punto de control"]

    # Speaks the focused button, once per change.
    def self.announce(scene)
      idx = PokeAccess.ivar(scene, :@index)
      return unless idx && idx >= 0
      return unless PokeAccess::Cursor.changed?(scene, :radial, idx)
      label = RADIAL[idx]
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
    # The fade is the signal, and it is exact: every option that leaves and comes back is wrapped in
    # pbFadeOutIn, and the ones that are not (save, the checkpoint prompt) end the menu instead of returning
    # to it. Scoped to the held scene, so this costs nothing when the menu is closed.
    def self.returned
      PokeAccess::Cursor.reset(@scene, :radial) if @scene
    rescue StandardError
      nil
    end
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
    begin; nxt.call; ensure; PokeAccess::RelictMenu.unwatch; end
  end
  kernel("pbFadeOutIn", :after) { |_args, _r| PokeAccess::RelictMenu.returned }
  poll_each_frame { PokeAccess::RelictMenu.poll }
end
