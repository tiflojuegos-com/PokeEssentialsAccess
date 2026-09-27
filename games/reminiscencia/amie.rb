module PokeAccess
  # Reminiscencia's Poke Recreo (class PokemonAmie), which paints no word and is played with the mouse: said as it
  # opens, with the character and the berry chosen for it, how to feed it from the keyboard and the keys that close
  # it; holding Down feeds the berry as holding it on the mouth does, with a word at half and nearly eaten.
  module ReminAmie
    # The opening line; the scene keeps the character under its picture folder's name (PAthan, Artica).
    def self.opening(scene)
      name = PokeAccess.ivar(scene, :@charaName).to_s
      name = { "PAthan" => "Athan", "Artica" => "Ártica" }[name] || name
      berry = (PokeAccess::Data.item_name(PokeAccess.ivar(scene, :@foodName)) rescue nil)
      who = [name, berry.to_s].reject { |s| s.strip.empty? }.join(", ")
      kh = PokeAccess::KeyHints
      PokeAccess::I18n.t(:rem_amie_open, :who => who, :c => kh.key(:c, "C"), :b => kh.key(:b, "X"))
    end

    # One frame of feeding while Down is held and the berry is not eaten: what input's mouse branch does with the
    # berry on the mouth (the mouth open, the eating sound, the count and the game's own checkEating). True when it
    # fed, so the frame's input is not run as well.
    def self.feed(scene)
      return false unless Input.press?(Input::DOWN) && !PokeAccess.ivar(scene, :@finishedFood)
      scene.instance_variable_set(:@foodmode, true)
      mouth = PokeAccess.sprite(scene, "mouth")
      mouth.visible = true if mouth
      eat_sound(scene)
      n = PokeAccess.ivar(scene, :@eatingTimeCheck).to_i + 1
      scene.instance_variable_set(:@eatingTimeCheck, n)
      scene.send(:checkEating)
      say_bite(n)
      true
    end

    # The eating sound, at the pace the game plays it.
    def self.eat_sound(scene)
      len = (getPlayTime("Audio/SE/NEWEat.ogg") rescue 0).to_f
      return unless (Time.now.to_f - PokeAccess.ivar(scene, :@eatTime).to_f) > len * 4
      pbSEPlay("NEWEat.ogg")
      scene.instance_variable_set(:@eatTime, Time.now)
    rescue StandardError
      nil
    end

    # Says the berry half eaten and nearly eaten, at the counts the game changes its picture; the game's own message
    # says the end.
    def self.say_bite(n)
      half = (::HALF_EATEN_TIME rescue 100)
      full = (::FULL_EATEN_TIME rescue 200)
      key = { half => :rem_amie_half, full => :rem_amie_nearly }[n]
      PokeAccess.speak(PokeAccess::I18n.t(key), false) if key
    end
  end
end

# main_loop is the blocking loop initialize enters last: before it, every sprite and the berry are in place. Each of
# its frames runs input, which a held Down replaces with a frame of feeding.
PokeAccess::Game.define("reminiscencia") do
  before("PokemonAmie", :main_loop, :optional => true) do |scene, _a|
    PokeAccess.speak(PokeAccess::ReminAmie.opening(scene), true)
  end
  around("PokemonAmie", :input, :optional => true) do |scene, nxt, _a|
    PokeAccess::ReminAmie.feed(scene) ? nil : nxt.call
  end
end
