module PokeAccess
  # Sevii's Pokeblock kit screens (PokeBlock), which paint little and show the rest in pictures and sprites: the case
  # (pbStart_item), a grid of colors, then a color's levels and quantity, then the party to feed one to; and the
  # party's condition (pbStart_pokemon), six bars per member. One dedup slot follows the focus through them all.
  module SeviiPokeblocks
    # The colors as the grid's buttons and the case's title write them, in @firstchoice's order.
    COLORS = ["GOLD", "BLACK", "GRAY", "WHITE", "RED", "BLUE", "PINK", "GREEN", "YELLOW", "PURPLE", "INDIGO", "BROWN",
              "LITE BLUE", "OLIVE"]
    GOLD = 0
    BLACK = 1
    # The flavor squares by sprite name, in the order the grid's left box lists them (its columns, top to bottom):
    # <name>1 marks a flavor of the focused color there, <name>2 lights the five under the RANDOM box.
    FLAVORS = [["spicy", :bdx_fl_spicy], ["dry", :bdx_fl_dry], ["sweet", :bdx_fl_sweet], ["bitter", :bdx_fl_bitter],
               ["sour", :bdx_fl_sour]]
    # The @process phases told apart: the grid, the frame that draws the chosen color, its level screens (gold's
    # second) and the frame that draws the party to feed.
    GRID = 0
    CHOSEN = 1
    LEVEL_SCREENS = [2, 3]
    FEEDING = 6
    # The condition bars top to bottom, as [word key, the stat each draws]; 255 fills one.
    CONDITIONS = [[:cnd_cool, :cool], [:cnd_beauty, :beauty], [:cnd_cute, :cute], [:cnd_smart, :smart],
                  [:cnd_tough, :tough], [:cnd_sheen, :sheen]]
    CONDITION_MAX = 255
    # Where information_pokemon paints each fact, as [x, y].
    PAINTED = { :species => [205, 7], :name => [205, 39], :level => [205, 71], :sign => [315, 71],
                :nature => [3, 317] }

    # The confirm and back keys the hints name, as the player has them now.
    def self.hint_keys
      { :ok => PokeAccess::KeyHints.key(:c, PokeAccess::I18n.t(:key_enter)),
        :back => PokeAccess::KeyHints.key(:b, PokeAccess::I18n.t(:key_escape)) }
    end

    # Says the case's name and keys as it opens, cutting in; the grid's first color follows, queued.
    def self.case_opened
      hint = PokeAccess::I18n.t(:sv_pb_case_keys, hint_keys)
      PokeAccess.speak(PokeAccess::Verbosity.with_hint(PokeAccess::I18n.t(:sv_pb_case), hint), true)
    end

    # Says the condition screen's name and keys as it draws the party, cutting in: to feed the chosen block while the
    # case runs (@process at FEEDING), else to look; the first member follows, queued.
    def self.condition_opened(scene)
      key = PokeAccess.ivar_i(scene, :@process) == FEEDING ? :sv_pb_feed_keys : :sv_pb_condition_keys
      hint = PokeAccess::I18n.t(key, hint_keys)
      PokeAccess.speak(PokeAccess::Verbosity.with_hint(PokeAccess::I18n.t(:sv_pb_condition), hint), true)
      PokeAccess::Cursor.reset(scene, :sv_pb_focus)
    end

    # Says the block's line once per change of key: a screen's first read queued behind its name, the next cutting in.
    def self.focus(scene, key)
      PokeAccess::Cursor.announce(scene, :sv_pb_focus, key, true, false) { yield }
    end

    # Says the grid's color the frame showed (shown, @firstchoice as first_choice began and lit its squares); the
    # frame that takes the color, and hides them, says nothing.
    def self.grid(scene, shown)
      return unless shown.is_a?(Integer) && shown >= 0 && shown < COLORS.length
      return unless PokeAccess.ivar_i(scene, :@process) == GRID
      focus(scene, [:grid, shown]) { color_line(scene, shown) }
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # A color as the grid shows it, at the bag item reading's level: its name, then from medium the flavors its
    # squares mark; the info key keeps it whole.
    def self.color_line(scene, idx)
      PokeAccess::Verbosity.info_line(:bag_item, [[COLORS[idx], :brief], [flavors(scene), :medium]])
    end

    # The flavors the lit squares show: the RANDOM box's when its own are lit, else the left box's; nil for none.
    def self.flavors(scene)
      return PokeAccess::I18n.t(:sv_pb_random) if FLAVORS.any? { |name, _key| lit?(scene, "#{name}2") }
      names = FLAVORS.select { |name, _key| lit?(scene, "#{name}1") }.map { |_name, key| PokeAccess::I18n.t(key) }
      names.empty? ? nil : PokeAccess::I18n.t(:pbk_flavors, :list => names.join(", "))
    end

    # Whether the scene's sprite under key shows.
    def self.lit?(scene, key)
      s = PokeAccess.sprite(scene, key)
      s && (s.visible rescue false) ? true : false
    end

    # Keeps the chosen color's name the case paints at its top (draw_title; rows as painted).
    def self.title_painted(scene, rows)
      scene.instance_variable_set(:@access_sv_pb_title, PokeAccess::PaintCapture.text(rows.map { |r| r[0] }))
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Keeps the quantity the case paints (draw_quantity) and, on a level screen, says it: titled as the chosen color
    # draws it. The repaint after a feeding, under the party, is only kept.
    def self.quantity_painted(scene, rows)
      scene.instance_variable_set(:@access_sv_pb_quantity, PokeAccess::PaintCapture.text(rows.map { |r| r[0] }))
      phase = PokeAccess.ivar_i(scene, :@process)
      levels(scene, phase == CHOSEN) if phase == CHOSEN || LEVEL_SCREENS.include?(phase)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Says the level screen once per change: the color's name when titled, the choice the cursor is on (black's
    # screen has none) and the quantity painted for it, at the bag item reading's level.
    def self.levels(scene, titled)
      fc = PokeAccess.ivar_i(scene, :@firstchoice)
      choice = fc == BLACK ? nil : PokeAccess.ivar_i(scene, fc == GOLD ? :@secondgold : :@secondnormal)
      qty = PokeAccess.ivar(scene, :@access_sv_pb_quantity).to_s
      focus(scene, [:level, fc, choice, qty]) do
        parts = [titled ? PokeAccess.ivar(scene, :@access_sv_pb_title) : nil, choice ? choice_text(fc, choice) : nil]
        parts.push(qty.empty? ? nil : PokeAccess::I18n.t(:sv_pb_quantity, :n => qty))
        PokeAccess::Verbosity.info_line(:bag_item, parts.map { |p| [p, :brief] })
      end
    end

    # A level button as it reads (LEVEL1, LEVEL2), after the column gold's screen adds, its count of flavors (1, 2).
    def self.choice_text(fc, choice)
      level = PokeAccess::I18n.t(:dbk_level, :n => fc == GOLD ? choice % 2 + 1 : choice + 1)
      fc == GOLD ? "#{PokeAccess::I18n.t(:sv_pb_flavor_count, :n => choice / 2 + 1)}, #{level}" : level
    end

    # Says the member the condition screen painted (information_pokemon; rows as painted) once per change, keeping the
    # rows for a feeding's refresh of the info key.
    def self.member(scene, rows)
      pos = PokeAccess.ivar_i(scene, :@position)
      scene.instance_variable_set(:@access_sv_pb_rows, rows)
      focus(scene, [:party, pos, rows.map { |r| r[0] }]) { member_text(pos, rows) }
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The member at pos, the info key keeping the Pokemon and Ctrl+T its line whole; past the party, its CANCEL.
    def self.member_text(pos, rows)
      party = party_list
      pk = member_at(party, pos)
      return PokeAccess::I18n.t(:pc_cancel) unless pk
      keep_info(pk, rows, pos, party.length)
      member_line(pk, rows, pos, party.length)
    end

    # Hands the info key the member and Ctrl+T its line whole.
    def self.keep_info(pk, rows, pos, size)
      PokeAccess::Info.set_info(:pokemon, pk, PokeAccess::Verbosity.whole { member_line(pk, rows, pos, size) })
    end

    # A member as the screen shows it, at the party reading's level: its name (its sex sign in full), its species in
    # full after a nickname, its level from medium, its nature in full, its six bars, and its place in the party.
    def self.member_line(pk, rows, pos, size)
      vb = PokeAccess::Verbosity
      name = painted(rows, :name) || PokeAccess.clean(pk.name.to_s)
      sign = vb.keep?(:party, :full) ? painted(rows, :sign) : nil
      nature = painted(rows, :nature)
      parts = [[[name, sign].compact.join(" "), :brief]]
      parts.push([painted(rows, :species), :full]) if nicknamed?(pk)
      parts.push([painted(rows, :level), :medium])
      parts.push([nature ? PokeAccess::I18n.t(:sm_nature, :n => nature) : nil, :full])
      parts.push([conditions_text(pk), :brief])
      parts.push([vb.position(pos + 1, size), :brief])
      vb.line(:party, parts)
    end

    # The text information_pokemon painted for a fact of PAINTED, cleaned, or nil.
    def self.painted(rows, what)
      x, y = PAINTED[what]
      row = rows.find { |r| r[2] == x && r[3] == y }
      row ? PokeAccess.clean(row[0]) : nil
    end

    # Whether the member goes by a name other than its species'.
    def self.nicknamed?(pk)
      pk.name.to_s != PokeAccess::Data.species_name(pk.species).to_s
    end

    # The player's party, or none.
    def self.party_list
      (PokeAccess::Engine.player.party rescue nil) || []
    end

    # The member of party at pos, or nil past it.
    def self.member_at(party, pos)
      pos >= 0 ? party[pos] : nil
    end

    # A member's six bars, top to bottom, as [word key, value] pairs.
    def self.bars(pk)
      CONDITIONS.map { |key, stat| [key, (pk.send(stat) rescue 0).to_f] }
    end

    # The bars as the condition list says them.
    def self.conditions_text(pk)
      PokeAccess::I18n.t(:pbk_conditions, :list => bars(pk).map { |key, value| bar_word(key, value) }.join(", "))
    end

    # A bar as said: its word and value, and the max word once it is full (the sheen, left uncapped, past it too).
    def self.bar_word(key, value)
      word = "#{PokeAccess::I18n.t(key)} #{[value, CONDITION_MAX].min.to_i}"
      value >= CONDITION_MAX ? "#{word} #{PokeAccess::I18n.t(:cnd_max)}" : word
    end

    # Runs a feeding (increase_condition, the block) and says the bars it raised, as they stand now, queued after the
    # game's message; a refused one raises none and says nothing. Answers the block's value.
    def self.feed(scene)
      before = fed_bars(scene)
      r = yield
      raised(scene, before)
      r
    end

    # The member the cursor feeds and its bars before the feeding, as [member, bars], or nil.
    def self.fed_bars(scene)
      pk = member_at(party_list, PokeAccess.ivar_i(scene, :@position))
      pk ? [pk, bars(pk)] : nil
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Says the bars that rose since before ([member, bars]), with their values now, and hands the info key the member
    # as fed: its painted rows are the same, so its line is not said again.
    def self.raised(scene, before)
      return unless before
      pk, was = before
      rose = []
      bars(pk).each_with_index { |(key, value), i| rose.push(bar_word(key, value)) if value > was[i][1] }
      PokeAccess.speak(PokeAccess::I18n.t(:pbk_rose, :list => rose.join(", ")), false) unless rose.empty?
      rows = PokeAccess.ivar(scene, :@access_sv_pb_rows) || []
      keep_info(pk, rows, PokeAccess.ivar_i(scene, :@position), party_list.length)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

# The case opens on its grid. first_choice lights the squares of the color it begins on and then moves the cursor, so
# the color said is the one it began on. The level screens speak from their repaints, the party from its paint.
PokeAccess::Game.define("sevii") do
  before("PokeBlock", :pbStart_item) { |_s, _a| PokeAccess::SeviiPokeblocks.case_opened }
  around("PokeBlock", :first_choice) do |scene, nxt, _a|
    shown = PokeAccess.ivar(scene, :@firstchoice)
    r = nxt.call
    PokeAccess::SeviiPokeblocks.grid(scene, shown)
    r
  end
  around("PokeBlock", :draw_title) do |scene, nxt, _a|
    r = nil
    rows = PokeAccess::PaintCapture.sample { r = nxt.call }
    PokeAccess::SeviiPokeblocks.title_painted(scene, rows)
    r
  end
  around("PokeBlock", :draw_quantity) do |scene, nxt, _a|
    r = nil
    rows = PokeAccess::PaintCapture.sample { r = nxt.call }
    PokeAccess::SeviiPokeblocks.quantity_painted(scene, rows)
    r
  end
  after("PokeBlock", :disappear_scene) { |scene, _r, _a| PokeAccess::SeviiPokeblocks.levels(scene, true) }

  # draw_scene_pokemon draws the condition screen, for pbStart_pokemon or for the case's feeding.
  before("PokeBlock", :draw_scene_pokemon) { |scene, _a| PokeAccess::SeviiPokeblocks.condition_opened(scene) }
  around("PokeBlock", :information_pokemon) do |scene, nxt, _a|
    r = nil
    rows = PokeAccess::PaintCapture.sample { r = nxt.call }
    PokeAccess::SeviiPokeblocks.member(scene, rows)
    r
  end
  around("PokeBlock", :increase_condition) { |scene, nxt, _a| PokeAccess::SeviiPokeblocks.feed(scene) { nxt.call } }
  before("PokeBlock", :pbEndScene) { |_s, _a| PokeAccess::Info.clear_text }
end
