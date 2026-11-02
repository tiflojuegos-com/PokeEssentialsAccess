# Perseida's pause menu and arcane clock (0212_Menu_Base, 0213_Menu_Reloj). Each icon of the menu paints the letter of its
# direct key, said after its name; both screens paint the map's name, the time and, with its switch, the mana, which the
# info key says with the trainer; and the clock's dial shows the gems that work by themselves, said as it opens. Cometry's
# icon paints a T its Input::T does not read (0185_PSystem_Controls gives that button to F4), so it goes unsaid.
module PokeAccess
  module PerseidaPause
    ICON_KEYS = { "Menu_pokeball" => [:x, "A"], "Menu_bag" => [:clara_bag, "B"], "Menu_save" => [:y, "S"],
                  "Menu_reloj" => [:r, "W"], "Menu_pokegear" => [:z, "D"] }

    @open = false

    # Runs a screen saying whether it paints the map's name, the time and the mana, and hands that back as it closes:
    # these screens open one another, and the Pokegear, which paints none of them, opens from the menu.
    def self.painting(on)
      was = @open
      @open = on
      yield
    ensure
      @open = was
    end

    # An entry's name, with the key its icon paints.
    def self.with_key(entry, name)
      key = ICON_KEYS[entry[0].to_s]
      return name unless key
      hint = PokeAccess::I18n.t(:perseida_pause_key, :key => PokeAccess::KeyHints.key(key[0], key[1]))
      PokeAccess::Verbosity.with_hint(name, hint, ", ")
    end

    # The mana as painted, on the screens that paint it and while its switch is on.
    def self.mana
      return nil unless @open && $game_switches[ACTIVARMANA]
      PokeAccess::I18n.t(:perseida_mana, :n => $game_variables[VARMANA], :max => pbMaxMana)
    end

    # The map's name and the time, on the screens that paint them.
    def self.place
      return nil unless @open
      "#{($game_map.name rescue nil)}, #{pbGetTimeNow.strftime('%H:%M')}"
    end

    # The gems that work by themselves and that the dial shows, as it opens; nil with none.
    def self.dial
      names = [:SURF, :CUT].select { |m| PokeAccess::PerseidaFieldMoves.gem_on?(m) }.map { |m| PokeAccess::PerseidaFieldMoves.clearer(m) }
      names.empty? ? nil : PokeAccess::I18n.t(:perseida_clock_gems, :list => names.join(", "))
    end
  end
end

PokeAccess::Game.define("perseida") do
  override("PokeAccess::Menu2Pause", :label) do |_mod, original, args|
    PokeAccess::PerseidaPause.with_key(args[0], original.call)
  end
  trainer_part(:mana) { |_trainer| PokeAccess::PerseidaPause.mana }
  trainer_part(:place) { |_trainer| PokeAccess::PerseidaPause.place }
  %w[Menu2 ItemsM].each do |menu|
    around(menu, :pbUpdate, :optional => true) do |_scene, nxt, _a|
      PokeAccess::PerseidaPause.painting(true) { nxt.call }
    end
  end
  override("PokeAccess::ClaraClock", :publish) { |_mod, _original, args| PokeAccess::Info.set_info(:trainer, nil, args[0]) }
  before("ItemsM", :pbEndScene, :optional => true) { |_menu, _a| PokeAccess::Info.set_info(:trainer, nil) }
  read_on_open("ItemsM", :pbStartScene, :optional => true, :hook_container => true) { |_menu| PokeAccess::PerseidaPause.dial }
end
