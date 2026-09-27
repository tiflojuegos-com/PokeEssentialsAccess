# Video Poker: while the cards are picked, the ones that make up the combination found flash (the payout table
# highlights it and FLASH_CARDS is on), and the focused card says so.

VpSpecCard = Struct.new(:value, :suit)
VpSpecCursor = Struct.new(:index)

# The screen's own test of a card: in the combination found or not.
class VpSpecScreen
  def initialize(cards); @cards = cards; end
  def hand_card_in_combination?(i); @cards.include?(i); end
end

# The scene: the Hold/Draw label printed under each card.
class VpSpecScene
  def current_label_text(i); i == 0 ? "Hold" : "Draw"; end
end

def vp_spec_scene(index, highlight)
  s = VpSpecScene.new
  s.instance_variable_set(:@hand, [VpSpecCard.new(1, 1), VpSpecCard.new(1, 2), VpSpecCard.new(5, 3)])
  s.instance_variable_set(:@cursor, VpSpecCursor.new(index))
  s.instance_variable_set(:@highlight_combination, highlight)
  s.instance_variable_set(:@screen, VpSpecScreen.new([0, 1]))
  s
end

Suite.define("video poker: a card of the combination found says it flashes") do
  vp = PokeAccess::VideoPokerRead
  t = PokeAccess::I18n
  ace = t.t(:vp_card, :value => t.t(:vp_ace), :suit => t.t(:vp_hearts), :state => "Hold")
  SpeakCapture.clear
  vp.card(vp_spec_scene(0, true))
  eq "a card in the combination, marked", SpeakCapture.lines, ["#{ace}, #{t.t(:vp_in_combo)}"]
  SpeakCapture.clear
  vp.card(vp_spec_scene(2, true))
  eq "one outside it, plain", SpeakCapture.lines,
     [t.t(:vp_card, :value => "5", :suit => t.t(:vp_clubs), :state => "Draw")]
  SpeakCapture.clear
  vp.card(vp_spec_scene(0, false))
  eq "with nothing highlighted no card is marked", SpeakCapture.lines, [ace]

  unless Object.const_defined?(:VideoPoker)
    Object.const_set(:VideoPoker, Module.new)
    begin
      VideoPoker.const_set(:FLASH_CARDS, false)
      SpeakCapture.clear
      vp.card(vp_spec_scene(0, true))
      eq "a game that turns the flashing off marks none", SpeakCapture.lines, [ace]
    ensure
      Object.send(:remove_const, :VideoPoker)
    end
  end
end
