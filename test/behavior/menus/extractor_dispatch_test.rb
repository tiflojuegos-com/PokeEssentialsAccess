# Which reader a command window's focused row goes to: the extractor registered for the nearest class of its
# ancestry, whatever the order of registration (the first one on a tie), else the window's own option list.
class ExtractorDispatchTest < PokeAccessTest
  # A command window the extractors are registered against by name, with its option list and cursor.
  class Base
    attr_accessor :index
    def initialize(commands = []); @commands = commands; @index = 0; end
  end

  # A window class derived from Base, as a profile's specialised screen is.
  class Child < Base; end

  # A window class below Child that no extractor names.
  class Grandchild < Child; end

  test "the most derived extractor wins, whatever order they were registered in" do
    [[:Base, :Child], [:Child, :Base]].each do |order|
      with_extractors(order.map { |c| [c, c.to_s.downcase] }) do
        assert_equal "base", focused(Base.new), "a Base window, registered #{order.inspect}"
        assert_equal "child", focused(Child.new), "a Child window, registered #{order.inspect}"
      end
    end
  end

  test "a window of a class no extractor names is read by its nearest registered ancestor's" do
    with_extractors([[:Base, "base"], [:Child, "child"]]) do
      assert_equal "child", focused(Grandchild.new)
    end
  end

  test "of two extractors registered for one class, the first registered wins" do
    with_extractors([[:Child, "first"], [:Child, "second"]]) do
      assert_equal "first", focused(Child.new)
    end
  end

  test "a window no extractor claims is read from its own option list, with nothing logged" do
    said = nil
    lines = with_extractors([[:Child, "child"], [:Absent, "absent"]]) do
      with_fresh_failures { marker_lines { said = focused(Base.new(["Curar", "Luchar"]), 1) } }
    end
    assert_equal "Luchar", said, "an extractor for a class the game lacks is passed over too"
    assert_equal [], lines
  end

  test "a window with no row focused has no focused text" do
    with_extractors([[:Base, "base"]]) do
      [nil, -1].each { |i| assert_nil focused(Base.new(["Curar"]), i), "index #{i.inspect}" }
    end
  end

  private

  # The focused text of win with its cursor on index.
  def focused(win, index = 0)
    win.index = index
    PokeAccess::Menus.focused_text(win)
  end

  # The block's value with an extractor answering text registered, in order, for each [class name in this test,
  # text]; the registry put back afterwards.
  def with_extractors(pairs)
    saved = PokeAccess::Menus::EXTRACTORS.dup
    pairs.each { |cname, text| PokeAccess::Menus.def_extractor("#{self.class}::#{cname}") { |_w, _i| text } }
    yield
  ensure
    PokeAccess::Menus::EXTRACTORS.replace(saved)
  end

  # The block's value with the extractor failures logged so far forgotten, so that one now would be written afresh;
  # they are put back afterwards.
  def with_fresh_failures
    logged = PokeAccess::Menus.instance_variable_get(:@ext_logged)
    PokeAccess::Menus.instance_variable_set(:@ext_logged, [])
    yield
  ensure
    PokeAccess::Menus.instance_variable_set(:@ext_logged, logged)
  end

  # The marker lines written while the block runs, without their time stamp.
  def marker_lines
    path = PokeAccess.marker_file
    from = File.file?(path) ? File.size(path) : 0
    yield
    return [] unless File.file?(path)
    File.open(path, "rb") { |f| f.seek(from); f.read }.to_s.split(/\r?\n/).map { |l| l.sub(/\A.*?[+-]\d{4}: /, "") }
  end
end
