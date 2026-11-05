# Ashen Frost's Tutor.net (edited: Tutor.net/Tutor.net.rb, not Soulstones 2's): the generic reader says the move under the
# list, and this adds what the screen paints beside it, its type icon and its price, and what the party's icons show, whether
# each member can learn it. In the party grid, which filters the list, each member with its icon's answer.
module PokeAccess
  module AshenTutorNet
    # The icon each party panel draws, as words. 0 is an egg, or no move under the list.
    COMP = { 1 => :tut_can, 2 => :tut_cannot, 3 => :tut_knows }

    # The list's row under the cursor as [move, cost, currency], or nil.
    def self.focused(scene)
      list = PokeAccess.sprite(scene, "commands")
      rows = PokeAccess.ivar(scene, :@move_list)
      row = (rows && list) ? rows[list.index] : nil
      row ? row[0] : nil
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The price as the row paints it: money with its sign, a number over the Gold Bottle Cap's icon or an item's; nil when
    # the move is free.
    def self.price(row)
      cost = row[1].to_i
      return nil if cost <= 0
      return "$#{cost}" if row[2] == "$"
      item = row[2] == "c" ? :GOLDBOTTLECAP : row[2]
      PokeAccess::I18n.t(:ashen_tutor_price, :n => cost, :item => PokeAccess::Data.item_name(item))
    end

    # The icon a member's panel shows now.
    def self.comp(scene, index)
      PokeAccess.ivar(PokeAccess.sprite(scene, "pokemon#{index}"), :@comp)
    end

    # The names of the members whose panel shows comp.
    def self.names_with(scene, party, comp_value)
      out = []
      party.each_with_index { |pk, i| out.push(pk.name.to_s) if pk && comp(scene, i) == comp_value }
      out
    end

    @browsing = false
    @said = nil

    # Runs the list's loop, the only stretch where a change of the party's icons means another move; back on it after refusing a
    # move, its row is said whole again. A filter that left no moves opens an empty list, which nothing else would say.
    def self.browsing(scene)
      @browsing = true
      @said = nil
      list = PokeAccess.sprite(scene, "commands")
      PokeAccess::Cursor.reset(list, :cmd_focus) if list
      PokeAccess.speak(PokeAccess::I18n.t(:ashen_tutor_empty), false) if (PokeAccess.ivar(scene, :@move_list) || []).empty?
      yield
    ensure
      @browsing = false
    end

    # The move's type and price and who it suits, once per move, queued behind its name, which the generic reader says.
    def self.say_row(scene)
      return unless @browsing
      row = focused(scene)
      return unless row
      party = PokeAccess.ivar(scene, :@party) || []
      icons = (0...party.length).map { |i| comp(scene, i) }
      key = [(PokeAccess.sprite(scene, "commands").index rescue nil), row, icons]
      return if key == @said
      @said = key
      move = (Pokemon::Move.new(row[0]) rescue nil)
      PokeAccess::Info.set_info(:move, move) if move
      PokeAccess.speak(line(scene, row, party, icons, move), false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The row's line: the type its icon paints, the price, who can learn it and who knows it.
    def self.line(scene, row, party, icons, move)
      type = (GameData::Type.get(move.type).name rescue nil)
      parts = [type, price(row)]
      can = names_with(scene, party, 1)
      knows = names_with(scene, party, 3)
      parts.push(PokeAccess::I18n.t(:tut_can_list, :names => can.join(", "))) unless can.empty?
      parts.push(PokeAccess::I18n.t(:tut_knows_list, :names => knows.join(", "))) unless knows.empty?
      parts.push(PokeAccess::I18n.t(:tut_nobody)) if can.empty? && knows.empty? && icons.include?(2)
      PokeAccess.sentences(parts.compact)
    end

    # Back on the list from the party grid, cancelled: its row and what goes with it are said again.
    def self.grid_cancelled(scene)
      @said = nil
      list = PokeAccess.sprite(scene, "commands")
      PokeAccess::Cursor.reset(list, :cmd_focus) if list
    end

    # The welcome's text names the AUX2 button's default as F, which Game.exe binds to nothing: the button is R, on W. It is said
    # with the key it is on.
    def self.true_key(text)
      text.to_s.sub("(default: F)", "(default: #{PokeAccess::KeyHints.key(:r, "W")})")
    end

    # The member under the grid's cursor: its name and its panel's icon.
    def self.say_member(scene, index)
      party = PokeAccess.ivar(scene, :@party) || []
      pk = party[index]
      return unless pk
      line = PokeAccess.clean(pk.name.to_s)
      word = COMP[comp(scene, index)]
      line = "#{line}, #{PokeAccess::I18n.t(word)}" if word
      return unless PokeAccess::Cursor.changed?(scene, :ashen_tutor_member, [index, line])
      PokeAccess.speak(line, true)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  around("PokemonTutorNet_Scene", :pbScene) { |scene, nxt, _args| PokeAccess::AshenTutorNet.browsing(scene) { nxt.call } }

  # After every repaint of the icons, the only moment they are up to date; the filter's repaint names its moves and is left
  # to the list it opens.
  after("PokemonTutorNet_Scene", :update_indicators) do |scene, _ret, args|
    PokeAccess::AshenTutorNet.say_row(scene) if args.empty?
  end

  # pbChangeSelection returns the new index; pbChoosePokemon opens on the last member.
  after("PokemonTutorNet_Scene", :pbChangeSelection) do |scene, ret, _args|
    PokeAccess::AshenTutorNet.say_member(scene, ret)
  end
  before("PokemonTutorNet_Scene", :pbChoosePokemon) do |scene, _args|
    PokeAccess::Cursor.reset(scene, :ashen_tutor_member)
    PokeAccess::AshenTutorNet.say_member(scene, PokeAccess.ivar_i(scene, :@last_mon_index))
  end
  after("PokemonTutorNet_Scene", :pbChoosePokemon, :hook_container => true) do |scene, ret, _args|
    PokeAccess::AshenTutorNet.grid_cancelled(scene) if ret.to_i < 0
  end
  # The filter refills the list only to end the scene and open it again on the filtered moves, and that new list is the one to
  # say its first row.
  before("PokemonTutorNet_Scene", :pbSetCommands) { |scene, _args| PokeAccess.dedicate(PokeAccess.sprite(scene, "commands")) }
  # The info key keeps the row's move (set_info), which clear_info_on, for text alone, would leave behind.
  after("PokemonTutorNet_Scene", :pbEndScene) { PokeAccess::Info.set_info(nil, nil) }
  override(PokeAccess, :dialogue_text) { |_mod, original, _args| PokeAccess::AshenTutorNet.true_key(original.call) }
end
