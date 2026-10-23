module PokeAccess
  # Sevii's new game, run by the intro event of its first map: the version, the player and the starter, each a
  # picture whose name the message box under it shows (VersionSelection, GenderSel and StarterSel, @option into
  # @textOptions, moved with left and right), then five of twenty Pokemon from a grid of icons (PokeSelect).
  module SeviiIntro
    # What each of the three pickers asks for, said as it opens.
    TITLES = { "VersionSelection" => :sv_version_title, "GenderSel" => :gsel_help, "StarterSel" => :sv_starter_title }
    POOL_COLUMNS = 5
    POOL_ROWS = 4
    POOL_PICKS = 5

    # Says what the picker asks for and how to move, cutting in, as its loop starts.
    def self.opened(cname)
      PokeAccess.speak(PokeAccess::Verbosity.with_hint(PokeAccess::I18n.t(TITLES[cname]),
                                                       PokeAccess::I18n.t(:gsel_help_hint)), true)
    end

    # Whether the grid's Pokemon at idx is taken.
    def self.taken?(scene, idx)
      PokeAccess.sprite(scene, "pokemon#{idx}").selected ? true : false
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end

    # What has to change for the grid to be read again: the cell, or the taking or putting back of its Pokemon.
    def self.pool_key(scene, idx = PokeAccess.ivar_i(scene, :@SelNo))
      [idx, taken?(scene, idx)]
    end

    # The grid's cell at idx: its Pokemon, whether it is taken, its row and column. The first read leads with the
    # grid's size and how to use it; a read after taking or putting back one ends with how many are taken.
    def self.pool_cell(scene, idx)
      name = PokeAccess.clean(PokeAccess.sprite(scene, "pokemon#{idx}").pokemon.name)
      taken = taken?(scene, idx)
      cell = PokeAccess::I18n.t(taken ? :sv_pool_taken : :sv_slot, :name => name,
                                :row => idx / POOL_COLUMNS + 1, :col => idx % POOL_COLUMNS + 1)
      last = PokeAccess.ivar(scene, :@access_sv_pool)
      scene.instance_variable_set(:@access_sv_pool, [idx, taken])
      if last.nil?
        grid = PokeAccess::I18n.t(:sv_pool_grid, :cols => POOL_COLUMNS, :rows => POOL_ROWS)
        return PokeAccess.sentences([PokeAccess::Verbosity.with_hint(grid, PokeAccess::I18n.t(:sv_pool_hint)), cell])
      end
      return cell unless last[0] == idx && last[1] != taken
      count = (PokeAccess.ivar(scene, :@selected) || []).length
      PokeAccess.sentences([cell, PokeAccess::I18n.t(:sv_pool_count, :n => count, :max => POOL_PICKS)])
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Before one of the grid's questions: the cell first when the Pokemon there was just taken (the fifth one asks at
    # once whether the player is done), cutting in, then the question, queued, its Yes and No left to the command
    # reader.
    def self.pool_question(scene, args)
      idx = PokeAccess.ivar_i(scene, :@SelNo)
      if PokeAccess::Cursor.changed?(scene, :sv_pool, pool_key(scene, idx))
        line = pool_cell(scene, idx)
        PokeAccess.speak(line, true) if line
      end
      PokeAccess.say_screen_message(args)
    rescue StandardError => e
      PokeAccess.swallowed(e)
    end
  end
end

PokeAccess::Game.define("sevii") do
  # The three pickers' update runs each frame of their loop and pbUpdateSceneMap inside, hence hook_container; the
  # first read queues behind the opening line.
  %w[VersionSelection GenderSel StarterSel].each do |cname|
    before(cname, :main) { |_scene, _a| PokeAccess::SeviiIntro.opened(cname) }
    focus_reader(cname, :index => :@option, :items => :@textOptions, :slot => :"sv_#{cname}",
                 :hook_container => true) { |label| label }
  end

  # A No to the version's or the sex's question rebuilds the picker's text box: the choice under the cursor is said
  # again, queued behind the answer.
  %w[VersionSelection GenderSel].each do |cname|
    before(cname, :createTextBox) { |scene, _a| PokeAccess::Cursor.reset(scene, :"sv_#{cname}") }
  end

  # The starter's question goes on the picture's own message box; its Yes and No window is one the mod reads, hence
  # hook_container. A No puts the picker back on its choice, said again.
  before("StarterSel", :pbDisplayConfirm) { |_scene, args| PokeAccess.say_screen_message(args) }
  after("StarterSel", :pbDisplayConfirm, :hook_container => true) do |scene, yes, _a|
    PokeAccess::Cursor.reset(scene, :sv_StarterSel) unless yes
  end

  focus_reader("PokeSelect", :index => :@SelNo, :slot => :sv_pool, :hook_container => true,
               :key => lambda { |scene, idx| PokeAccess::SeviiIntro.pool_key(scene, idx) }) do |idx, scene|
    PokeAccess::SeviiIntro.pool_cell(scene, idx)
  end

  before("PokeSelect", :pbDisplayConfirm) { |scene, args| PokeAccess::SeviiIntro.pool_question(scene, args) }
end
