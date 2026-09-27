# The new game's "Who are you?" choice names only Left and Right: as it opens, each side is said with its
# portrait (the gendered pictures on screen, ordered by x), queued ahead of the first row.
module PokeAccess
  module SS2IntroGender
    # The gender keys of the gendered portraits on screen, left to right.
    def self.portraits
      pics = ($game_screen.pictures rescue nil)
      return [] unless pics
      shown = (1..50).map { |i| (pics[i] rescue nil) }.compact
      tagged = shown.map { |p| [(p.x rescue 0).to_f, PokeAccess::Appearance.gender_for_picture((p.name rescue nil))] }
      tagged.select { |_x, g| g }.sort_by { |x, _g| x }.map { |_x, g| g }
    end

    # Each side with the portrait it holds, or nil unless a two-row choice opens over exactly two portraits.
    def self.text(choices)
      return nil unless choices.is_a?(Array) && choices.length == 2
      g = portraits
      return nil unless g.length == 2
      PokeAccess::I18n.t(:ss2_intro_sides, :left => PokeAccess::I18n.t(g[0]), :right => PokeAccess::I18n.t(g[1]))
    end
  end
end

PokeAccess::Game.define("soulstones2") do
  before("Interpreter", :command_102) do |interp, _a|
    cmd = (interp.instance_variable_get(:@list)[interp.instance_variable_get(:@index)] rescue nil)
    PokeAccess.speak(PokeAccess::SS2IntroGender.text((cmd.parameters[0] rescue nil)), false)
  end
end
