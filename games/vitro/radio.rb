# Vitro's radio (RadioInterface, 0295_Radio_Core, on the Pokegear): a bar of frequencies tuned with the arrows, with a mark on each
# station, its name, and the program's lines, which change every 120 frames, two seconds, and are the content, so each goes in the
# queue behind the last. A tuning cuts them, and static is not said. The line after this one, painted dim, is left to the info key.
module PokeAccess
  module VitroRadio
    # A line of nothing but dots and static, as the programs write it.
    NOISE = /\A[.\s]*(z+t[.\s]*)*\z/

    # The frequency as painted, with the station's name when one is tuned.
    def self.tuning(radio)
      PokeAccess.sentences([sprintf("%.1f", radio.current_frequency), PokeAccess.clean(radio.get_station_info.to_s)])
    end

    # The frequencies the bar marks, for the info key: the marks carry no number.
    def self.marks(scene)
      list = scene.get_available_stations.map { |st| sprintf("%.1f", st[:frequency]) }
      list.empty? ? nil : PokeAccess::I18n.t(:vitro_radio_marks, :list => list.join(", "))
    end

    # The tuning when it changed, the first with how the arrows tune; a new station's first line is said even if it repeats.
    def self.tuned(scene, radio)
      first = PokeAccess::Cursor.pending?(scene, :vitro_radio_tune)
      station = radio.get_station_info
      PokeAccess::Cursor.reset(scene, :vitro_radio_line) if PokeAccess::Cursor.changed?(scene, :vitro_radio_station, [station])
      PokeAccess::Cursor.announce(scene, :vitro_radio_tune, tuning(radio), true, false) do
        line = tuning(radio)
        first ? PokeAccess::Verbosity.with_hint(line, PokeAccess::I18n.t(:vitro_radio_keys)) : line
      end
    end

    # The program's current line, queued, when a new one comes up and it says anything.
    def self.program(scene, line)
      return if line.empty? || line =~ NOISE
      PokeAccess::Cursor.announce(scene, :vitro_radio_line, line, false) { line }
    end

    # One frame as update_display paints it.
    def self.poll(scene)
      radio = PokeAccess.ivar(scene, :@radio_system)
      return unless radio
      data = radio.get_display_text
      current = PokeAccess.clean((data.is_a?(Hash) ? data[:current] : data).to_s)
      after = PokeAccess.clean((data.is_a?(Hash) ? data[:next] : nil).to_s)
      tuned(scene, radio)
      program(scene, current)
      publish(scene, radio, current, after)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The info key's text when any of it changed.
    def self.publish(scene, radio, current, after)
      line = tuning(radio)
      return unless PokeAccess::Cursor.changed?(scene, :vitro_radio_info, [line, current, after])
      PokeAccess::Info.set_info(:text, PokeAccess.sentences([line, current, after, marks(scene)]), line)
    end
  end
end

PokeAccess::Game.define("vitro") do
  after("RadioInterface", :update_display, :optional => true) { |scene, _r, _a| PokeAccess::VitroRadio.poll(scene) }
  clear_info_on("RadioInterface", :cleanup_on_exit)
end
