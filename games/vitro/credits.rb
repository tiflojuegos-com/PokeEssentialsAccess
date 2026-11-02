# Vitro's closing credits (SubtitleSystem in 0228_Creditos, map 150): pages of names painted over a scene the player only watches,
# each through SubtitleSystem#show, with its lines split by <br> and its columns by <tab>, for a few seconds. Each page is said
# queued, so none cuts the one before, and the info key keeps the page on the screen until the last one goes.
module PokeAccess
  module VitroCredits
    # A page as a sentence per line, each with its columns.
    def self.page(text)
      lines = text.to_s.split(/<br>/i).map { |line| PokeAccess.clean(line.gsub(/<tab>/i, ", ")) }
      PokeAccess.sentences(lines.reject { |line| line.strip.empty? })
    end

    # Says a page and keeps it for the info key.
    def self.show(text)
      line = page(text)
      return if line.empty?
      PokeAccess.speak(line, false)
      PokeAccess::Info.set_info(:text, line)
    end
  end
end

PokeAccess::Game.define("vitro") do
  before("SubtitleSystem", :show) { |_system, args| PokeAccess::VitroCredits.show(args[0]) }
  after("SubtitleSystem", :update, :hook_container => true) { |system, _r, _a| PokeAccess::Info.clear_text unless system.active? }
end
