module PokeAccess
  # Dark Horizon's copy of the Type Match-up UI, its colours and background edited to the game: a type
  # (TypeMatch_Scene) or a species (SpeciesTypeMatch_Scene, its types too) turned with left and right or picked from a
  # list on accept, over three columns of type icons, Weak, Resist and Immune. Each draw is said as the entry and its
  # place, then every column by the title the screen paints and the types its icons show.
  module DHTypeMatch
    # The rows the first draw paints before anything else: the three column titles, then the three key hints.
    TITLES = 3
    FIRST_ROWS = 6

    # Runs a draw, the block, and says what it shows (say); answers the draw's value.
    def self.draw(scene, kind, id)
      ret = nil
      rows = PokeAccess::PaintCapture.sample { ret = yield }
      say(scene, kind, id, rows)
      ret
    end

    # Says a draw when its entry changed, the first one queued and with the screen's key line while hints are said,
    # the next ones cutting in; the column titles and key line, painted only by the first draw, are kept on the scene,
    # and what a draw paints besides them is the species' name. The info key keeps the whole line, and the scene the
    # line as last said for jump_closed.
    def self.say(scene, kind, id, rows)
      texts = rows.map { |r| r[0].to_s }
      if PokeAccess.ivar(scene, :@access_dh_tm_titles).nil? && texts.length >= FIRST_ROWS
        scene.instance_variable_set(:@access_dh_tm_titles, texts[0, TITLES])
        scene.instance_variable_set(:@access_dh_tm_hints, texts[TITLES...FIRST_ROWS])
        texts = texts[FIRST_ROWS..-1]
      end
      list = PokeAccess.ivar(scene, kind == :type ? :@types : :@species) || []
      idx = PokeAccess.ivar_i(scene, :@index)
      first = PokeAccess::Cursor.pending?(scene, :dh_type_match)
      PokeAccess::Cursor.announce(scene, :dh_type_match, [id, idx], true, false) do
        t = line(scene, kind, id, texts.first, idx, list.length)
        PokeAccess::Info.set_info(:text, t, t)
        scene.instance_variable_set(:@access_dh_tm_last, [[id, idx], t])
        hints = PokeAccess.ivar(scene, :@access_dh_tm_hints) || []
        first ? PokeAccess::DarkHorizon.hinted(t, PokeAccess.sentences(hints)) : t
      end
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The jump list closed: on the entry already shown, which the screen does not draw again, that entry is said again,
    # queued behind the list; another entry is said by its draw.
    def self.jump_closed(scene, picked)
      key, line = PokeAccess.ivar(scene, :@access_dh_tm_last)
      return unless key && key[0] == picked
      PokeAccess::Cursor.reset(scene, :dh_type_match)
      PokeAccess::Cursor.announce(scene, :dh_type_match, key, false) { line }
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The entry with its place (a species with its types), then each column as "title: types", "none" for an empty one.
    def self.line(scene, kind, id, painted, idx, total)
      if kind == :type
        data = GameData::Type.get(id)
        head = PokeAccess::Verbosity.list_entry(data.name, idx + 1, total)
        cols = [data.weaknesses, data.resistances, data.immunities]
      else
        sp = GameData::Species.get(id)
        name = (painted.nil? || painted.empty?) ? sp.name : painted
        types = sp.types.map { |ty| PokeAccess::Data.type_name(ty) }.join("/")
        head = "#{PokeAccess::Verbosity.list_entry(name, idx + 1, total)}, #{types}"
        cols = species_columns(sp.types)
      end
      titles = PokeAccess.ivar(scene, :@access_dh_tm_titles) || []
      parts = (0...cols.length).map do |i|
        names = cols[i].map { |ty| PokeAccess::Data.type_name(ty) }
        shown = names.empty? ? PokeAccess::I18n.t(:sum_none) : names.join(", ")
        titles[i] ? "#{titles[i]}: #{shown}" : shown
      end
      PokeAccess.sentences([head] + parts)
    end

    # The attacking types a species is weak to, resists and is immune to, sorted by the predicates the screen uses over
    # the non-pseudo types, in the game's order.
    def self.species_columns(defend)
      cols = [[], [], []]
      GameData::Type.each do |t|
        next if t.pseudo_type
        v = Effectiveness.calculate(t.id, *defend)
        cols[0].push(t.id) if Effectiveness.super_effective?(v)
        cols[1].push(t.id) if Effectiveness.not_very_effective?(v)
        cols[2].push(t.id) if Effectiveness.ineffective?(v)
      end
      cols
    end
  end
end

PokeAccess::Game.define("darkhorizon") do
  around("TypeMatch_Scene", :drawTypes) do |scene, nxt, args|
    PokeAccess::DHTypeMatch.draw(scene, :type, args[0]) { nxt.call }
  end
  around("SpeciesTypeMatch_Scene", :drawSpeciesTypes) do |scene, nxt, args|
    PokeAccess::DHTypeMatch.draw(scene, :species, args[0]) { nxt.call }
  end

  # The jump list on accept, the editor's pbChooseList (a command window the core reads), runs its own loop.
  after("TypeMatch_Scene", :pbChooseTypeFromList, :hook_container => true) do |scene, picked, _a|
    PokeAccess::DHTypeMatch.jump_closed(scene, picked)
  end
  after("SpeciesTypeMatch_Scene", :pbChooseSpeciesFromList, :hook_container => true) do |scene, picked, _a|
    PokeAccess::DHTypeMatch.jump_closed(scene, picked)
  end

  # What the info key kept goes with the screen.
  %w[TypeMatch_Scene SpeciesTypeMatch_Scene].each do |cname|
    before(cname, :pbEndScene) { |_scene, _a| PokeAccess::Info.clear_text }
  end
end
