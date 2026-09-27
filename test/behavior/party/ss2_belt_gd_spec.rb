# Soulstones 2's Battle Belt button, past the party members: reaching it says what its three item slots hold (two
# medicines and a combat item), a spent one marked.

class PokemonPartyConfirmBattleBeltSprite
  def initialize; @selected = false; end
  def selected=(value); @selected = value; end
end

require File.expand_path("../../../games/soulstones2/battle_belt", File.dirname(__FILE__))

Suite.define("ss2 battle belt: the button says what its three slots hold") do
  t = PokeAccess::I18n
  saved = defined?($Trainer) ? $Trainer : nil
  begin
    trainer = Object.new
    def trainer.battlebelt
      { :med1 => [:POTION, 2, "Potion"], :med2 => [:SUPERPOTION, 0, "Super Potion"], :combat => [:NONE, 0, "None"] }
    end
    $Trainer = trainer
    button = PokemonPartyConfirmBattleBeltSprite.new
    button.selected = true
    eq "each slot with its item, a spent one marked, an empty one said empty", SpeakCapture.lines,
       [t.t(:ss2_belt, :items => [t.t(:ss2_belt_med1, :item => "ItemPOTION"),
                                  t.t(:ss2_belt_med2, :item => t.t(:ss2_belt_spent, :item => "ItemSUPERPOTION")),
                                  t.t(:ss2_belt_combat, :item => t.t(:ss2_belt_none))].join(", "))]

    SpeakCapture.clear
    button.selected = true
    silent "re-marking the focused button stays quiet"
    button.selected = false
    silent "and leaving it says nothing of its own"
  ensure
    $Trainer = saved
  end
end
