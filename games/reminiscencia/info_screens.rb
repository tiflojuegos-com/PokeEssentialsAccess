# Reminiscencia's full-screen notices (showControles, showEndingResults), said queued once painted, "=>" as a colon;
# and the save screen's real play time window, said after the save's first question.
module PokeAccess
  module ReminInfoScreens
    def self.poll
      return unless PokeAccess::PaintCapture.pending?(:rem_info)
      rows = PokeAccess::PaintCapture.take(:rem_info) || []
      t = PokeAccess::PaintCapture.text(rows.map { |r| r.to_s.gsub(/\s*=>\s*/, ": ") })
      PokeAccess.speak(t, false) unless t.empty?
    end

    def self.save_time(save)
      t = PokeAccess.clean((PokeAccess.ivar(save, :@infowindow).text rescue "").to_s)
      PokeAccess.after_next_line(t) unless t.empty?
    end
  end
end

PokeAccess::Game.define("reminiscencia") do
  %w[showControles showEndingResults].each do |fn|
    kernel(fn, :around) do |_args, nxt|
      PokeAccess::PaintCapture.arm(:rem_info)
      begin
        nxt.call
      ensure
        PokeAccess::PaintCapture.take(:rem_info)
      end
    end
  end
  poll_each_frame { PokeAccess::ReminInfoScreens.poll }
  after("PokemonSave", :initialize, :optional => true) { |save, _r, _a| PokeAccess::ReminInfoScreens.save_time(save) }
end

# The key-item ceremony, which this game shows for whatever a chest or a person hands over: a real item says nothing
# of its own, as the receive message names it; a picture name, which no message follows, is said by its picture.
PokeAccess::Game.define("reminiscencia") do
  override("PokeAccess::KeyItemGet", :announce) do |mod, _original, args|
    n = mod.picture_name(args[0])
    PokeAccess.speak(PokeAccess::I18n.t(:key_item_get, :name => n), false) if n
  end
end
