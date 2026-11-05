module PokeAccess
  # Type Match-up UI: a type (TypeMatch_Scene) or a species (SpeciesTypeMatch_Scene, its types too) turned with left and
  # right or picked from a list on accept, over three columns of type icons. Each draw is said as the entry and its
  # place, then every column by the title the screen paints, in the game's language, and the types its icons show.
  module TypeMatch
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
      if PokeAccess.ivar(scene, :@access_tm_titles).nil? && texts.length >= FIRST_ROWS
        scene.instance_variable_set(:@access_tm_titles, texts[0, TITLES])
        scene.instance_variable_set(:@access_tm_hints, texts[TITLES...FIRST_ROWS])
        texts = texts[FIRST_ROWS..-1]
      end
      list = PokeAccess.ivar(scene, kind == :type ? :@types : :@species) || []
      idx = PokeAccess.ivar_i(scene, :@index)
      first = PokeAccess::Cursor.pending?(scene, :type_match)
      PokeAccess::Cursor.announce(scene, :type_match, [id, idx], true, false) do
        t = line(scene, kind, id, texts, idx, list.length)
        PokeAccess::Info.set_info(:text, t, t)
        scene.instance_variable_set(:@access_tm_last, [[id, idx], t])
        hints = PokeAccess.ivar(scene, :@access_tm_hints) || []
        first && PokeAccess::Verbosity.hints? ? PokeAccess.sentences([t] + hints) : t
      end
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The jump list closed: on the entry already shown, which the screen does not draw again, that entry is said again,
    # queued behind the list; another entry is said by its draw.
    def self.jump_closed(scene, picked)
      key, line = PokeAccess.ivar(scene, :@access_tm_last)
      return unless key && key[0] == picked
      PokeAccess::Cursor.reset(scene, :type_match)
      PokeAccess::Cursor.announce(scene, :type_match, key, false) { line }
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The entry with its place (a species with its types), then each column as "title: types", "none" for an empty one,
    # and whatever else a species' draw paints after its name. A species is its id, or the battler itself where the
    # chart opens in battle (Decades).
    # param texts what the draw painted besides the first draw's titles and key line
    def self.line(scene, kind, id, texts, idx, total)
      extra = []
      if kind == :type
        data = GameData::Type.get(id)
        head = PokeAccess::Verbosity.list_entry(data.name, idx + 1, total)
        cols = [data.weaknesses, data.resistances, data.immunities]
      else
        sp = id.respond_to?(:types) ? id : GameData::Species.get(id)
        name = (texts.first.nil? || texts.first.empty?) ? sp.name : texts.first
        extra = texts[1..-1].to_a
        types = sp.types.map { |ty| PokeAccess::Data.type_name(ty) }.join("/")
        head = "#{PokeAccess::Verbosity.list_entry(name, idx + 1, total)}, #{types}"
        cols = species_columns(sp.types)
      end
      titles = PokeAccess.ivar(scene, :@access_tm_titles) || []
      parts = (0...cols.length).map do |i|
        names = cols[i].map { |ty| PokeAccess::Data.type_name(ty) }
        shown = names.empty? ? PokeAccess::I18n.t(:sum_none) : names.join(", ")
        titles[i] ? "#{titles[i]}: #{shown}" : shown
      end
      PokeAccess.sentences([head] + parts + extra)
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

PokeAccess::Hooks.around_hook("TypeMatch_Scene", :drawTypes, :optional => true) do |scene, nxt, args|
  PokeAccess::TypeMatch.draw(scene, :type, args[0]) { nxt.call }
end
PokeAccess::Hooks.around_hook("SpeciesTypeMatch_Scene", :drawSpeciesTypes, :optional => true) do |scene, nxt, args|
  PokeAccess::TypeMatch.draw(scene, :species, args[0]) { nxt.call }
end

# The jump list on accept, the editor's pbChooseList (a command window the core reads), runs its own loop.
PokeAccess::Hooks.after_hook("TypeMatch_Scene", :pbChooseTypeFromList, :optional => true,
                             :hook_container => true) do |scene, picked, _a|
  PokeAccess::TypeMatch.jump_closed(scene, picked)
end
PokeAccess::Hooks.after_hook("SpeciesTypeMatch_Scene", :pbChooseSpeciesFromList, :optional => true,
                             :hook_container => true) do |scene, picked, _a|
  PokeAccess::TypeMatch.jump_closed(scene, picked)
end

# What the info key kept goes with the screen.
PokeAccess::Hooks.clear_info_on("TypeMatch_Scene", :pbEndScene)
PokeAccess::Hooks.clear_info_on("SpeciesTypeMatch_Scene", :pbEndScene)
