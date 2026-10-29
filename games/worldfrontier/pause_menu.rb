# LackDeJurane's pause menu as World Frontier edits it (Pause Menu UI): a grid of icon buttons with no command window,
# the focused command's name painted on the bottom bar beside the Battle Points. Read by the index its pbShowCommands
# loop keeps (the slide-in included), with the points after the first command of an opening while they change.
module PokeAccess
  module WfPauseMenu
    SLOT = :wf_pause
    @scene = nil
    @opening = false

    # The focused command's name as the bottom bar paints it, or nil.
    def self.focused(scene)
      cmds = PokeAccess.ivar(scene, :@commands)
      idx = PokeAccess.ivar(scene, :@index)
      return nil unless cmds.is_a?(Array) && idx.is_a?(Integer) && idx >= 0 && cmds[idx]
      cmds[idx].to_s
    end

    # The points the bottom bar paints at its left ("{1} PB"), or nil before it was painted.
    def self.points(scene)
      cache = PokeAccess.ivar(scene, :@time_cache)
      (cache.is_a?(Array) && cache[2]) ? cache[2].to_s : nil
    end

    # Holds the menu while its command loop runs.
    def self.watch(scene)
      @scene = scene
      @opening = true
      PokeAccess::Cursor.reset(self, SLOT)
    end

    def self.unwatch
      @scene = nil
      PokeAccess::Cursor.reset(self, SLOT)
    end

    # One frame of the loop: the focused command when it changes, the opening's first queued and followed by the
    # points; the info key answers with the trainer, as in any pause menu.
    def self.poll
      s = @scene
      return unless s
      name = focused(s)
      return if name.nil? || name.empty?
      key = [PokeAccess.ivar(s, :@index), name]
      return unless PokeAccess::Cursor.announce(self, SLOT, key, !@opening) { name }
      PokeAccess::Info.set_info(:trainer, nil)
      return unless @opening
      @opening = false
      pts = points(s)
      PokeAccess::PausePanel.say([pts]) if pts
    end
  end
end

PokeAccess::SceneWatcher.wire("PokemonPauseMenu_Scene", :pbShowCommands, PokeAccess::WfPauseMenu)
