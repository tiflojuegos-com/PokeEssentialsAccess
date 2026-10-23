# The safe reads of engine objects (ivar, ivar_i, attr_of, sprite, const_at) answer the value, else nil or their
# fallback when it is missing or its read raises, and never raise themselves.
class IvarTest < PokeAccessTest
  # An engine object whose accessors answer nothing, a value, or raise.
  class Accessors
    def blank; nil; end
    def broken; raise "not ready yet"; end
    def level; 12; end
    def name; "Rojo"; end
  end

  test "reads an instance variable the object has set" do
    assert_equal 7, PokeAccess.ivar(holding(:@here, 7), :@here)
  end

  test "reads an unset instance variable as nil, even with a fallback given" do
    assert_nil PokeAccess.ivar(Object.new, :@nope)
    assert_nil PokeAccess.ivar(Object.new, :@nope, :fallback)
  end

  test "reads nil's instance variables as nil" do
    assert_nil PokeAccess.ivar(nil, :@x)
  end

  test "answers its fallback, nil by default, for a name it cannot read" do
    assert_equal :safe, PokeAccess.ivar(Object.new, :bad_name, :safe)
    assert_nil PokeAccess.ivar(Object.new, :bad_name)
  end

  test "reads an instance variable as an Integer" do
    { "5" => 5, 7 => 7, 3.9 => 3, "12 PS" => 12 }.each do |value, want|
      assert_equal want, PokeAccess.ivar_i(holding(:@n, value), :@n), "for #{value.inspect}"
    end
  end

  test "answers its fallback, 0 by default, for an unset instance variable" do
    assert_equal 0, PokeAccess.ivar_i(Object.new, :@missing)
    assert_equal(-1, PokeAccess.ivar_i(Object.new, :@missing, -1))
  end

  test "answers its fallback for a value without to_i or a name it cannot read" do
    assert_equal(-1, PokeAccess.ivar_i(holding(:@n, Object.new), :@n, -1), "a value without to_i")
    assert_equal(-1, PokeAccess.ivar_i(Object.new, :bad_name, -1), "a malformed name")
  end

  test "answers the first accessor that gives a value, in the order asked" do
    assert_equal 12, PokeAccess.attr_of(Accessors.new, :blank, :level, :name)
  end

  test "passes over an accessor the object lacks or that raises" do
    assert_equal "Rojo", PokeAccess.attr_of(Accessors.new, :totalpp, :broken, :name)
  end

  test "answers nil when no accessor gives a value" do
    assert_nil PokeAccess.attr_of(Accessors.new, :blank, :broken, :totalpp)
  end

  test "answers nil for an object whose respond_to? raises" do
    obj = Accessors.new
    def obj.respond_to?(*_args); raise "no introspection here"; end
    assert_nil PokeAccess.attr_of(obj, :level)
  end

  test "picks a named sprite from the scene's @sprites" do
    assert_equal :the_window, PokeAccess.sprite(holding(:@sprites, { "cmd" => :the_window }), "cmd")
  end

  test "answers nil for a name the scene's @sprites lacks" do
    assert_nil PokeAccess.sprite(holding(:@sprites, { "cmd" => :the_window }), "nope")
  end

  test "answers nil for a scene without @sprites or with @sprites that are no Hash" do
    assert_nil PokeAccess.sprite(Object.new, "cmd"), "no @sprites"
    assert_nil PokeAccess.sprite(holding(:@sprites, [:the_window]), "cmd"), "an Array"
  end

  test "finds a constant by its full name, segment by segment" do
    assert_same PokeAccess::Routes::Flood, PokeAccess.const_at("PokeAccess::Routes::Flood")
    assert_same IvarTest::Accessors, PokeAccess.const_at(:"IvarTest::Accessors")
  end

  test "answers nil for a name with a segment that is not defined" do
    assert_nil PokeAccess.const_at("PokeAccess::NoSuchModule::Flood")
    assert_nil PokeAccess.const_at("NoSuchTopLevelConstant")
  end

  test "answers nil, not Object, for an empty or missing name" do
    assert_nil PokeAccess.const_at("")
    assert_nil PokeAccess.const_at(nil)
  end

  test "answers nil for a name that cannot be a constant" do
    assert_nil PokeAccess.const_at("lowercase::name")
  end

  private

  # A fresh object with one instance variable set.
  def holding(ivar, value)
    obj = Object.new
    obj.instance_variable_set(ivar, value)
    obj
  end
end
