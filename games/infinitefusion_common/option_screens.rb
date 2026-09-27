module PokeAccess
  # Infinite Fusion's option screens (PokemonOption_Scene and its submenus): the box under the list always holds the
  # focused option's help, per value where the option has one each; a submenu opens under a title of its own and a
  # line saying what it sets; a number option paints its value as "Type N/M".
  module IFOptionScreens
    # The submenus that open under their own title (several by themselves, when an option is turned on); the last
    # four are Hoenn's.
    SUBMENUS = %w[FusionSelectOptionsScene AutosaveOptionsScene ExperimentalOptionsScene RandomizerOptionsScene
                  RandomizerTrainerOptionsScene RandomizerWildPokemonOptionsScene RandomizerGymOptionsScene
                  RandomizerItemOptionsScene ChallengeOptionsScene GameplayOptionsScene SpriteOptionsScene
                  SystemOptionsScene]

    # A window's text, cleaned, or "" when it has none.
    def self.text_of(scene, key)
      PokeAccess.clean((PokeAccess.sprite(scene, key).text rescue "").to_s)
    end

    # What a submenu opens with: its title and the line in its box, or nil when both are blank.
    def self.opening(scene)
      line = PokeAccess.sentences([text_of(scene, "title"), text_of(scene, "textbox")])
      line.empty? ? nil : line
    end

    # Hands the help the box shows for the option and value just focused to the info key.
    def self.help(scene)
      d = text_of(scene, "textbox")
      PokeAccess::Info.set_info(:text, PokeAccess::KeyHints.localize(d, nil, true)) unless d.empty?
    end

    # Whether an option is a number one, which drawItem paints as "Type N/M".
    def self.number?(o)
      defined?(::NumberOption) && o.is_a?(::NumberOption) && o.respond_to?(:optstart) ? true : false
    end
  end
end

PokeAccess::Game.define("infinitefusion_common") do
  after("PokemonOption_Scene", :updateDescription, :optional => true) { |s, _r, _a| PokeAccess::IFOptionScreens.help(s) }
  PokeAccess::IFOptionScreens::SUBMENUS.each do |cn|
    read_on_open(cn, :pbStartScene, :optional => true, :hook_container => true) { |s| PokeAccess::IFOptionScreens.opening(s) }
  end
  override("PokeAccess::Options", :value_of) do |_mod, original, args|
    o, v = args
    if PokeAccess::IFOptionScreens.number?(o)
      _INTL("Type {1}/{2}", o.optstart + v.to_i, o.optend - o.optstart + 1)
    else
      original.call
    end
  end
end
