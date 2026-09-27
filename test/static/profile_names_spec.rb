# A profile is named by the first Game.define its own modules run, a name that signs the player's marks, names and
# tags files: each profile's first define names its own folder. A common loads before those modules, so every define
# in it names the common itself, a "_common" name Game.profile_name passes over.
Suite.define("static: every profile is named after its own folder by the first module that defines one") do
  wrong = []
  Dir.glob(File.join(Harness::ROOT, "games", "*", "manifest.rb")).sort.each do |mf|
    game = File.basename(File.dirname(mf))
    value = eval(File.read(mf), TOPLEVEL_BINDING, mf)
    mods = value.is_a?(Hash) ? value[:modules] : value
    defined = []
    Array(mods).each do |m|
      path = File.join(File.dirname(mf), "#{m}.rb")
      defined.concat(File.read(path).scan(/(?:Game|SpriteButtonMenu)\.define\("([^"]+)"/).flatten) if File.file?(path)
    end
    if game =~ /_common\z/
      others = defined.uniq - [game]
      wrong.push("#{game}: #{others.join(', ')}") unless others.empty?
    else
      wrong.push("#{game}: #{defined.first}") unless defined.empty? || defined.first == game
    end
  end
  eq "each profile's first define names its own folder, and a common's only itself", wrong, []
end
