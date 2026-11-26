# Roei's Badgecase UI (BadgeCase_Scene) and the Medalcase UI made from it (MedalCase_Scene): a grid of pictures with no
# words, each with a page behind confirm. The grid says the badge under the cursor (named if held or where its page
# names it), held or not, and its place; the page says what it paints top to bottom, with the type its icon shows.
module PokeAccess
  module RoeiCase
    # Scene class => the word its ivars and $PokemonGlobal's holder are named after.
    KINDS = { "BadgeCase_Scene" => "badge", "MedalCase_Scene" => "medal" }
    # Scene class => the setting that shows the name of one not held yet on its page.
    NAME_ALWAYS = { "BadgeCase_Scene" => "BadgecaseSetting::BADGE_NAME_ALWAYS", "MedalCase_Scene" => "MEDAL_NAME_ALWAYS" }
    # Heights the page paints its rows at: the type row, whose value is an icon, and the three of the ace Pokemon.
    TYPE_ROW = 118
    ACE_ROWS = [304, 324, 358]

    # The badge or medal under the cursor, by its name where its page would show it, or the page it shows.
    def self.line(entry, index, scene)
      return PokeAccess::Cursor.current(scene, :roei_case_page) if page?(scene)
      word = KINDS[scene.class.name]
      return nil unless word && entry
      shown = PokeAccess.ivar(scene, :"@#{word}s_showed")
      shown = PokeAccess.ivar(scene, :"@#{word}s").length unless shown.is_a?(Integer)
      held = ($PokemonGlobal.send("#{word}s").has?(entry.id) rescue false)
      state = PokeAccess::I18n.t(held ? :case_held : :case_missing)
      count = PokeAccess::I18n.t(:loc_count, :n => index + 1, :total => shown)
      named = held || PokeAccess.const_at(NAME_ALWAYS[scene.class.name]) == true
      named ? "#{PokeAccess.clean(entry.name.to_s)}, #{state}, #{count}" : "#{state}, #{count}"
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # True while the scene shows one badge's page instead of the grid.
    def self.page?(scene)
      word = KINDS[scene.class.name]
      word ? PokeAccess.ivar(scene, :"@#{word}page") == true : false
    end

    # What the focus reader asks to change before it reads again: the place, and grid or page.
    def self.key(scene, index)
      [index, page?(scene)]
    end

    # Keeps the page just painted, its rows by height joined as sentences, the type named after its label where an icon
    # stands for it and the ace Pokemon's label and name as one line.
    def self.painted(scene, rows)
      by_y = {}
      (rows || []).each do |r|
        next unless r[2].is_a?(Numeric) && r[3].is_a?(Numeric)
        (by_y[r[3]] ||= []).push(r)
      end
      lines = []
      ace = []
      by_y.keys.sort.each do |y|
        cells = by_y[y].sort_by { |r| r[2] }.map { |r| PokeAccess.clean(r[0]) }.reject { |t| t.empty? }
        cells.push(type_name(scene)) if y == TYPE_ROW && cells.length == 1
        ACE_ROWS.include?(y) ? ace.concat(cells) : lines.push(cells.compact.join(" "))
      end
      lines.push(ace.join(" ")) unless ace.empty?
      PokeAccess::Cursor.store(scene, :roei_case_page, PokeAccess.sentences(lines))
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The type of the badge on the page, as the icon the page draws for it shows.
    def self.type_name(scene)
      word = KINDS[scene.class.name]
      list = PokeAccess.ivar(scene, :"@#{word}s")
      item = list[PokeAccess.ivar_i(scene, :"@#{word}index")]
      (GameData::Type.get(item.type).name rescue nil)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Hooks.on_paint("BadgeCase_Scene", :drawBadgePage, :optional => true) do |scene, rows, _args|
  PokeAccess::RoeiCase.painted(scene, rows)
end
PokeAccess::FocusReader.define("BadgeCase_Scene", :on => :pbUpdate, :index => :@badgeindex, :items => :@badges,
                                                  :key => proc { |scene, index| PokeAccess::RoeiCase.key(scene, index) },
                                                  :close => :pbEndScene, :optional => true) do |entry, index, scene|
  PokeAccess::RoeiCase.line(entry, index, scene)
end

PokeAccess::Hooks.on_paint("MedalCase_Scene", :drawMedalPage, :optional => true) do |scene, rows, _args|
  PokeAccess::RoeiCase.painted(scene, rows)
end
PokeAccess::FocusReader.define("MedalCase_Scene", :on => :pbUpdate, :index => :@medalindex, :items => :@medals,
                                                  :key => proc { |scene, index| PokeAccess::RoeiCase.key(scene, index) },
                                                  :close => :pbEndScene, :optional => true) do |entry, index, scene|
  PokeAccess::RoeiCase.line(entry, index, scene)
end
