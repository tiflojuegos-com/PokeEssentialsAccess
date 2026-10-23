# Soulstones 2's Battle Belt button, past the party members (games/soulstones2/battle_belt.rb): reaching it says what
# its three item slots hold (two medicines and a combat item), a spent one marked and an empty one said empty.

# The belt button, a sprite class of its own that the party loop marks selected as the cursor reaches it.
class PokemonPartyConfirmBattleBeltSprite
  def initialize; @selected = false; end
  def selected=(value); @selected = value; end
end

ss2_belt_path = File.join(Harness::ROOT, "games", "soulstones2", "battle_belt.rb")
eval(Harness.source(ss2_belt_path), TOPLEVEL_BINDING, ss2_belt_path)

class Ss2BeltGdTest < PokeAccessTest
  T = PokeAccess::I18n

  # A belt as Soulstones 2 keeps it: per slot, the item, how many are left and the name it stores.
  BELT = { :med1 => [:POTION, 2, "Potion"], :med2 => [:SUPERPOTION, 0, "Super Potion"], :combat => [:NONE, 0, "None"] }

  test "reaching the button says each slot's item, a spent one marked and an empty one said empty, cutting in" do
    with_belt(BELT) do
      PokemonPartyConfirmBattleBeltSprite.new.selected = true
      said = belt(T.t(:ss2_belt_med1, :item => "ItemPOTION"),
                  T.t(:ss2_belt_med2, :item => T.t(:ss2_belt_spent, :item => "ItemSUPERPOTION")),
                  T.t(:ss2_belt_combat, :item => T.t(:ss2_belt_none)))
      assert_equal [[said, true]], SpeakCapture.log
    end
  end

  test "the loop marking the button again stays quiet" do
    with_belt(BELT) do
      button = PokemonPartyConfirmBattleBeltSprite.new
      button.selected = true
      SpeakCapture.clear
      button.selected = true
      assert_nothing_spoken
    end
  end

  test "leaving the button says nothing of its own" do
    with_belt(BELT) do
      PokemonPartyConfirmBattleBeltSprite.new.selected = false
      assert_nothing_spoken
    end
  end

  test "a slot with one item left is not spent, and none left is" do
    belt = { :med1 => [:POTION, 1, "Potion"], :med2 => [:POTION, 0, "Potion"], :combat => [:XATTACK, 3, "X Attack"] }
    with_belt(belt) do
      said = belt(T.t(:ss2_belt_med1, :item => "ItemPOTION"),
                  T.t(:ss2_belt_med2, :item => T.t(:ss2_belt_spent, :item => "ItemPOTION")),
                  T.t(:ss2_belt_combat, :item => "ItemXATTACK"))
      assert_equal said, PokeAccess::SS2Belt.text
    end
  end

  test "an item the game's data does not know is said by the name the belt stores" do
    with_belt(:med1 => [:OLDPOTION, 1, "Old Potion"], :med2 => [:NONE, 0, ""], :combat => [:NONE, 0, ""]) do
      with_unknown_item(:OLDPOTION) do
        said = belt(T.t(:ss2_belt_med1, :item => "Old Potion"), T.t(:ss2_belt_med2, :item => T.t(:ss2_belt_none)),
                    T.t(:ss2_belt_combat, :item => T.t(:ss2_belt_none)))
        assert_equal said, PokeAccess::SS2Belt.text
      end
    end
  end

  test "a belt with a slot missing, or no belt at all, says the missing slots empty" do
    none = T.t(:ss2_belt_none)
    partial = { :med1 => [:POTION, 2, "Potion"] }
    { partial => ["ItemPOTION", none, none], nil => [none, none, none] }.each do |kept, items|
      with_belt(kept) do
        said = belt(T.t(:ss2_belt_med1, :item => items[0]), T.t(:ss2_belt_med2, :item => items[1]),
                    T.t(:ss2_belt_combat, :item => items[2]))
        assert_equal said, PokeAccess::SS2Belt.text, kept.inspect
      end
    end
  end

  private

  # The button's line over its three slot phrases.
  def belt(*slots)
    T.t(:ss2_belt, :items => slots.join(", "))
  end

  # Runs the block with the player's trainer keeping the given belt (nil: a trainer with none).
  def with_belt(kept)
    saved = $Trainer
    trainer = Object.new
    trainer.define_singleton_method(:battlebelt) { kept }
    $Trainer = trainer
    yield
  ensure
    $Trainer = saved
  end

  # Runs the block with the item data finding nothing for id, as for an item the game no longer defines.
  def with_unknown_item(id)
    meta = (class << GameData::Item; self; end)
    meta.send(:alias_method, :ss2_spec_try_get, :try_get)
    GameData::Item.define_singleton_method(:try_get) { |i| i == id ? nil : ss2_spec_try_get(i) }
    yield
  ensure
    meta.send(:alias_method, :try_get, :ss2_spec_try_get)
    meta.send(:remove_method, :ss2_spec_try_get)
  end
end
