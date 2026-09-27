module PokeAccess
  # The jukebox of the engine Reborn and Rejuvenation share (xLeD's Scene_Jukebox, edited by each game; its list a
  # Window_JukeboxCommand): the BGM files as a command list, the track playing first and painted in a colour of its
  # own. Its row says it plays, and the list repainted after a choice is read again under the still cursor.
  module JukeboxRV
    # The track the list paints as playing: the one the Jukebox set before the map's where the game keeps it
    # (Rejuvenation's getDefaultBGM), else the one playing; nil off the jukebox scene or with no track.
    def self.playing_name
      return nil unless defined?(Scene_Jukebox) && $scene.is_a?(Scene_Jukebox)
      sys = $game_system
      bgm = (sys.respond_to?(:getDefaultBGM) ? sys.getDefaultBGM : nil) || sys.playing_bgm
      name = bgm ? bgm.name.to_s : ""
      name.empty? ? nil : name
    rescue StandardError
      nil
    end

    # A row: the track's name, and that it plays when the list paints it so.
    def self.row(win, i)
      name = (win.instance_variable_get(:@commands)[i] rescue nil)
      return nil if name.nil?
      name.to_s == playing_name ? "#{name}, #{PokeAccess::I18n.t(:rv_jukebox_playing)}" : name.to_s
    end

    # Hooks the rows and the repaint a choice makes.
    def self.bind
      PokeAccess::Menus.def_extractor("Window_JukeboxCommand") { |win, i| PokeAccess::JukeboxRV.row(win, i) }
      PokeAccess::Hooks.after_hook("Window_JukeboxCommand", :refresh, :optional => true) do |win, _r, _a|
        PokeAccess::Cursor.reset(win, :cmd_focus)
      end
    end
  end
end

PokeAccess::JukeboxRV.bind if PokeAccess::DataRV.engine?
