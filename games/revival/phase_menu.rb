# Revival's preparation menu before a fight (MenuFases, and MenuFases2 and 3 with fewer ways), a wheel drawn in one
# picture per lit way, with no cursor: up opens the party, right the PC, down the bag, left the PHS, and Use goes on.
# show_image paints the wheel unlit (menufases1) as the menu opens and again on the way back from what a way opened.
module PokeAccess
  module RevivalPhaseMenu
    # The words the wheel paints for each way, in the game's language (its _en pictures in English).
    WORDS = { :es => ["Pokémon", "PC", "Mochila", "PHS"], :en => ["Pokemon", "PC", "Bag", "PHS"] }

    # The ways each menu takes, as [the direction's key, its place in WORDS], in the order they are said.
    WAYS = {
      "MenuFases" => [[:dir_up, 0], [:dir_right, 1], [:dir_down, 2], [:dir_left, 3]],
      "MenuFases2" => [[:dir_up, 0], [:dir_right, 1], [:dir_down, 2]],
      "MenuFases3" => [[:dir_up, 0], [:dir_down, 2]]
    }

    # The unlit wheel, which the menu opens on and comes back to.
    UNLIT = "menufases1"

    # The menu whole, as the info key keeps it: its name, then each way's word with its direction.
    def self.text(cname)
      words = WORDS[PokeAccess::RevivalLang.english? ? :en : :es]
      ways = (WAYS[cname] || []).map do |dir, i|
        PokeAccess::I18n.t(:rv_prep_way, :name => words[i], :dir => PokeAccess::I18n.t(dir))
      end
      PokeAccess.sentences([PokeAccess::I18n.t(:rv_prep_title), ways.join("; ")])
    end

    # Speaks the wheel as show_image paints it unlit: on opening the whole menu and the key that goes on, queued; back
    # from a way, its name at once; painted again with no way lit between, nothing.
    def self.shown(menu, cname, picture)
      last = PokeAccess.ivar(menu, :@access_rv_prep)
      menu.instance_variable_set(:@access_rv_prep, picture.to_s)
      return unless picture.to_s == UNLIT && last != UNLIT
      whole = text(cname)
      PokeAccess::Info.set_info(:text, whole)
      if last.nil?
        PokeAccess.speak(PokeAccess::Verbosity.with_hint(whole, PokeAccess::TitleScreen.hint), false)
      else
        PokeAccess.speak(PokeAccess::I18n.t(:rv_prep_title), true)
      end
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Game.define("revival") do
  after("MenuFases", :show_image) { |menu, _r, args| PokeAccess::RevivalPhaseMenu.shown(menu, "MenuFases", args[0]) }
  after("MenuFases2", :show_image) { |menu, _r, args| PokeAccess::RevivalPhaseMenu.shown(menu, "MenuFases2", args[0]) }
  after("MenuFases3", :show_image) { |menu, _r, args| PokeAccess::RevivalPhaseMenu.shown(menu, "MenuFases3", args[0]) }
  before("MenuFases", :close_menu) { |_menu, _a| PokeAccess::Info.clear_text }
  before("MenuFases2", :close_menu) { |_menu, _a| PokeAccess::Info.clear_text }
  before("MenuFases3", :close_menu) { |_menu, _a| PokeAccess::Info.clear_text }
end
