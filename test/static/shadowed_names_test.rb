# Inside module PokeAccess, an unqualified name the games also define (Settings, Battle, Events...) is the mod's own
# module: a use that names something no module of the mod by that name has meant the game's, and needs "::" (the
# game's Settings::MAXIMUM_LEVEL read as PokeAccess::Settings answered nothing in every modern game).

class ShadowedNamesTest < PokeAccessTest
  ROOTS = %w[core games plugins]
  USE = /(?<![:\w"'@$])([A-Z]\w*)(?:::([A-Z]\w*)|\.([a-z_]\w*[?!]?))/
  INTROSPECTION = %w[const_defined? const_get constants]

  test "every unqualified use of a name the games share with the mod names something the mod's module has" do
    wrong = []
    each_code_line do |rel, n, line|
      line.scan(USE) do |name, const, meth|
        mods = mod_modules[name]
        next unless mods && game_names.include?(name)
        ok = if const then mods.any? { |m| m.const_defined?(const, false) }
             elsif INTROSPECTION.include?(meth) then false
             else mods.any? { |m| m.respond_to?(meth) }
             end
        wrong.push("#{rel}:#{n} #{name}#{const ? '::' + const : '.' + meth}") unless ok
      end
    end
    assert_equal [], wrong, "a game's name is read as ::Name inside the mod"
  end

  private

  def each_code_line
    root = Harness::ROOT
    ROOTS.each do |dir|
      Dir.glob(File.join(root, dir, "**", "*.rb")).sort.each do |path|
        rel = path.sub(root + "/", "")
        File.readlines(path).each_with_index do |line, i|
          next if line =~ /\A\s*#/
          yield rel, i + 1, line.sub(/\s#\s.*\z/m, "")
        end
      end
    end
  end

  def mod_modules
    @mod_modules ||= begin
      out = {}
      ObjectSpace.each_object(Module) do |m|
        name = (Module.instance_method(:name).bind(m).call rescue nil).to_s
        next unless name.start_with?("PokeAccess::")
        (out[name.split("::").last] ||= []).push(m)
      end
      out
    end
  end

  def game_names
    @game_names ||= File.readlines(File.join(Harness::ROOT, "test", "static", "all_classes.txt"))
                        .reject { |l| l =~ /\A#/ }.map { |l| l.split(" = ").first.to_s.strip }
  end
end
