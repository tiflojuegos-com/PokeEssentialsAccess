# Hooks.override takes a module object whose own name method wants an argument (FieldMoves.name(move)) as any other,
# labelled by the module's real name instead of calling that method and giving up.
class OverrideModuleNameTest < PokeAccessTest
  test "a module whose name method takes an argument is overridden all the same" do
    mod = Module.new do
      def self.name(move); "move:#{move}"; end
      def self.read; :core; end
    end
    Object.const_set(:OverrideSpecNamedReader, mod) unless Object.const_defined?(:OverrideSpecNamedReader)
    PokeAccess::Hooks.override(OverrideSpecNamedReader, :read, :tag => "spec") { |_m, _original, _args| :game }
    assert_equal :game, OverrideSpecNamedReader.read
    assert_includes PokeAccess::Hooks.overrides.last, "OverrideSpecNamedReader.read"
  end
end
