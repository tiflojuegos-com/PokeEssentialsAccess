# Soulstones 2's bag sort (V): the direction said as it lands, then the first row, queued. Gamedata pass.
class SS2SortBag
  attr_reader :pockets
  def initialize(pockets); @pockets = pockets; @descending_sort = false; end

  def sort_pocket_alphabetically
    sorted = @pockets[1].sort_by { |e| e[0].to_s }
    sorted.reverse! if @descending_sort
    @descending_sort = !@descending_sort
    @pockets[1] = sorted
  end
end

class SS2SortList < Window_DrawableCommand
  attr_reader :pocket
  def initialize(bag); super([]); @bag = bag; @pocket = 1; sync; end
  def sync; @commands = @bag.pockets[1].map { |e| e[0].to_s }; end
end

class SS2SortScene
  attr_accessor :on_choose
  def initialize(bag); @sprites = { "itemlist" => SS2SortList.new(bag) }; end
  def list; @sprites["itemlist"]; end
  def pbChooseItem; @on_choose.call if @on_choose; end
end

Suite.define("ss2 bag: sorting says which way it went, then the first row after it") do
  saved = [:PokemonBag, :PokemonBag_Scene].map { |c| Object.const_defined?(c) ? Object.const_get(c) : nil }
  t = PokeAccess::I18n
  begin
    [:PokemonBag, :PokemonBag_Scene].each { |c| Object.send(:remove_const, c) if Object.const_defined?(c) }
    Object.const_set(:PokemonBag, SS2SortBag)
    Object.const_set(:PokemonBag_Scene, SS2SortScene)
    load File.expand_path("../../../games/soulstones2/bag_sort.rb", File.dirname(__FILE__))

    bag = PokemonBag.new(1 => [["Potion", 2], ["Antidote", 1], ["Repel", 3]])
    scene = PokemonBag_Scene.new(bag)
    list = scene.list
    list.index = 2
    scene.on_choose = lambda { list.update }
    scene.pbChooseItem
    SpeakCapture.clear

    scene.on_choose = lambda do
      bag.sort_pocket_alphabetically
      list.sync
      list.index = 0
      list.update
    end
    scene.pbChooseItem
    eq "the direction first, and the first row after it, queued", SpeakCapture.log,
       [[t.t(:bag_sorted_az), true], ["Antidote", false]]

    SpeakCapture.clear
    scene.pbChooseItem
    eq "the next press sorts the other way, and says so", SpeakCapture.log,
       [[t.t(:bag_sorted_za), true], ["Repel", false]]

    SpeakCapture.clear
    bag.sort_pocket_alphabetically
    eq "a sort with no item choice running still says its direction", SpeakCapture.log,
       [[t.t(:bag_sorted_az), true]]
  ensure
    [:PokemonBag, :PokemonBag_Scene].each { |c| Object.send(:remove_const, c) if Object.const_defined?(c) }
    [:PokemonBag, :PokemonBag_Scene].zip(saved).each { |c, k| Object.const_set(c, k) if k }
  end
end
