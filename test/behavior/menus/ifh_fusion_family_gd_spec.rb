# Infinite Fusion 2's fusion chooser: holding Up brings up a row of dots, one per fusion of the two Pokemon's evolution
# lines, each drawn with or without a custom sprite and the current one marked; said once as it comes up, through the
# profile's hooks on the screen's own methods, defined before the file binds to them.
class DoublePreviewScreen
  attr_accessor :family
  def drawEvolutionIcons(_dex_number, _viewport, _x, _y, _window_position)
    (@family || []).each { |sp| customSpriteExistsSpecies(sp) }
  end
  def showAllEvoIcons; @evo_icons_visible = true; end
  def hideAllEvoIcons; @evo_icons_visible = false; end
end

def customSpriteExistsSpecies(species); ($if_customs || []).include?(species); end unless Object.private_method_defined?(:customSpriteExistsSpecies)

load File.expand_path("../../../games/infinitefusion_hoenn/fusion_family.rb", File.dirname(__FILE__))

Suite.define("infinite fusion 2: the family row says how many fusions, how many with a custom sprite and which is shown") do
  t = PokeAccess::I18n
  meta = class << GameData::Species; self; end
  meta.send(:alias_method, :ifh_family_spec_get, :get)
  meta.send(:define_method, :get) { |i| i.to_s =~ /\AB\d+H\d+\z/ ? Struct.new(:species).new(i) : ifh_family_spec_get(i) }
  $if_customs = [:B25H1, :B26H1]
  begin
    screen = DoublePreviewScreen.allocate
    screen.instance_variable_set(:@selected, 1)
    screen.family = [:B172H1, :B25H1, :B26H1]
    screen.drawEvolutionIcons(:B172H1, nil, 0, 0, 0)
    screen.family = [:B172H4, :B25H4, :B26H4]
    screen.drawEvolutionIcons(:B25H4, nil, 0, 0, 1)
    SpeakCapture.clear
    screen.showAllEvoIcons
    eq "the side under the arrow: its row, the custom sprites and where the shown fusion is", SpeakCapture.lines,
       [t.t(:if2_family, :n => 3, :m => 0, :k => 2)]
    screen.showAllEvoIcons
    eq "said once while Up stays held", SpeakCapture.lines.length, 1
    screen.hideAllEvoIcons
    screen.instance_variable_set(:@selected, 0)
    SpeakCapture.clear
    screen.showAllEvoIcons
    eq "held again on the other side, that side's row", SpeakCapture.lines, [t.t(:if2_family, :n => 3, :m => 2, :k => 1)]
  ensure
    $if_customs = nil
    meta.send(:alias_method, :get, :ifh_family_spec_get)
    meta.send(:remove_method, :ifh_family_spec_get)
  end
end
