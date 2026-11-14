module PokeAccess
  # Source 222_DEX_OBTAINED paints an entry, then runs its own catch menu.
  # Both loops are inside initialize; an after-initialize reader runs too late.
  module XenoverseCaughtPokemon
    ENTRY = :xenoverse_caught_entry
    CHOICE = :xenoverse_caught_choice

    def self.with_view(scene, kind)
      previous = @view
      @view = { :scene => scene, :kind => kind, :child => 0, :commands => nil }
      PokeAccess::Cursor.reset(scene, kind == :entry ? ENTRY : CHOICE)
      yield
    ensure
      @view = previous
      PokeAccess::Info.clear_text
    end

    def self.child
      view = @view
      return yield unless view
      view[:child] += 1
      PokeAccess::Info.clear_text
      yield
    ensure
      if view
        view[:child] -= 1
        PokeAccess::Cursor.reset(view[:scene], view[:kind] == :entry ? ENTRY : CHOICE)
      end
    end

    def self.paint_entry(scene)
      result = nil
      rows = PokeAccess::PaintCapture.sample { result = yield }
      scene.instance_variable_set(:@access_xeno_dex_rows, rows)
      PokeAccess::Cursor.reset(scene, ENTRY)
      result
    end

    def self.row_text(rows, y)
      selected = rows.select { |row| row[3] == y }.sort_by { |row| row[2] || 0 }
      selected.map { |row| PokeAccess.clean(row[0].to_s) }.reject { |text| text.empty? }.join(' ')
    end

    # The game already resolves language/form overrides and wraps these rows.
    def self.entry_text(scene)
      rows = PokeAccess.ivar(scene, :@access_xeno_dex_rows)
      return nil unless rows.is_a?(Array) && !rows.empty?
      pokemon = PokeAccess.ivar(scene, :@pkmn)
      ids = [:type1, :type2].map { |name| pokemon.send(name) if pokemon && pokemon.respond_to?(name) }.compact.uniq
      types = ids.map { |id| PokeAccess::Data.type_name(id).to_s }.reject { |name| name.empty? }
      parts = [row_text(rows, 28), row_text(rows, 79)]
      parts.push(_INTL('Type') + ': ' + types.join(', ')) unless types.empty?
      [[141, 'Height'], [166, 'Weight']].each do |y, label|
        text = row_text(rows, y)
        parts.push(_INTL(label) + ': ' + text) unless text.empty?
      end
      description = rows.select { |row| row[3].is_a?(Numeric) && row[3] >= 220 }
      parts.push(PokeAccess::PaintCapture.laid_out(description).join(' '))
      PokeAccess.sentences(parts.reject { |text| text.to_s.empty? })
    end

    def self.entry(scene)
      viewport = PokeAccess.ivar(scene, :@viewport2)
      return unless viewport && viewport.rect.height >= 384
      text = entry_text(scene)
      return if text.to_s.empty?
      PokeAccess::Cursor.announce(scene, ENTRY, text, true, false) do
        PokeAccess::Info.set_info(:text, text, text)
        text
      end
    end

    def self.command_label(command)
      case command
      when 'pc' then _INTL('Send to PC')
      when 'party' then _INTL('Add to Party')
      when 'nick' then _INTL('Nickname')
      when 'info' then _INTL('Info')
      end
    end

    # Nickname removes its button before fading into the name editor; only
    # after the editor/fade does the game return the cursor to the first row.
    def self.choice(scene)
      commands = PokeAccess.ivar(scene, :@commands)
      index = PokeAccess.ivar(scene, :@index)
      return unless commands.is_a?(Array) && index.is_a?(Integer) && index >= 0 && index < commands.length
      if @view[:commands] != commands
        old = @view[:commands]
        @view[:reindex] = old && old.include?('nick') && !commands.include?('nick')
        @view[:commands] = commands.dup
      end
      return if @view[:reindex] && index != 0
      @view[:reindex] = false
      viewport = PokeAccess.ivar(scene, :@viewport)
      return if viewport && viewport.color.alpha > 0
      text = command_label(commands[index])
      return if text.to_s.empty?
      PokeAccess::Cursor.announce(scene, CHOICE, [index, commands[index], text], true, false) do
        PokeAccess::Info.set_info(:text, text, text)
        text
      end
    end

    def self.update(scene)
      return unless @view && @view[:scene].equal?(scene) && @view[:child] == 0
      @view[:kind] == :entry ? entry(scene) : choice(scene)
    end
  end
end

PokeAccess::Game.define("xenoverse") do
  around("DexObtained", :addPokemonInfo) do |scene, original, _args|
    PokeAccess::XenoverseCaughtPokemon.paint_entry(scene) { original.call }
  end
  around("DexObtained", :inloop) do |scene, original, _args|
    PokeAccess::XenoverseCaughtPokemon.with_view(scene, :entry) { original.call }
  end
  around("DexObtained", :whatToDo) do |scene, original, _args|
    PokeAccess::XenoverseCaughtPokemon.with_view(scene, :choice) { original.call }
  end
  after("DexObtained", :update, :hook_container => true) do |scene, _result, _args|
    PokeAccess::XenoverseCaughtPokemon.update(scene)
  end
  around("DexObtained", :message) do |_scene, original, _args|
    PokeAccess::XenoverseCaughtPokemon.child { original.call }
  end
  # Closing still calls update while fading the buttons out. Their committed
  # selection is no longer a menu choice; keep this original animation quiet.
  around("DexObtained", :endscene) do |_scene, original, _args|
    PokeAccess::XenoverseCaughtPokemon.child { original.call }
  end
  around("PokemonSummary", :pbStartScreen) do |_screen, original, _args|
    PokeAccess::XenoverseCaughtPokemon.child { original.call }
  end
  kernel(:pbEnterPokemonName, :around) do |_args, original|
    PokeAccess::XenoverseCaughtPokemon.child { original.call }
  end
  clear_info_on("DexObtained", :endscene)
end
