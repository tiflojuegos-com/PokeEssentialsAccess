# Extracts a game's Ruby scripts to readable .rb files, so a profile can be written against what the game
# actually does instead of against a guess. Reads only the game folder, on any modern Ruby (Marshal and Zlib are
# stdlib); a colliding script name gets a numeric suffix and a line in the summary, never a silent drop.
#
#   ruby tools/dump_scripts.rb "C:\path\to\the game"          -> writes <the game>/Scripts_dump/
#   ruby tools/dump_scripts.rb "C:\path\to\the game" out_dir  -> writes out_dir/
require "zlib"

module ScriptDumper
  RGSSAD_KEY = 0xDEADCAFE
  MASK = 0xFFFFFFFF

  # Reads Scripts.rxdata / PluginScripts.rxdata, from the Data folder or from inside Game.rgssad.
  class Source
    def initialize(root)
      @root = root
      @archive = nil
    end

    # Archives are written with either separator depending on who packed them, so both are tried before
    # concluding the entry is absent.
    def read(relative)
      loose = File.join(@root, relative)
      return File.open(loose, "rb") { |f| f.read } if File.file?(loose)
      archive[relative] || archive[relative.tr("/", "\\")]
    end

    # True when the game ships its data packed, which is worth saying out loud: it is why the Data folder
    # looks empty.
    def packed?
      !archive.empty?
    end

    # The tree of loose .rb files, sorted by path. Some games keep only a loader in Scripts.rxdata and put
    # the real code in individual files, and each one picks its own folder for them, so the folder is found
    # rather than assumed. Numbered names are the load order.
    def loose_tree
      base = script_folder
      if base
        files = Dir[File.join(base, "**", "*.rb")].sort
        return files.map { |f| [f[base.length + 1..-1].tr("\\", "/"), File.open(f, "rb") { |h| h.read }] }
      end
      names = archive.keys.select { |k| k.tr("\\", "/") =~ %r{\AData/Scripts/.+\.rb\z}i }
      names.sort_by { |n| n.tr("\\", "/") }.map { |n| [n.tr("\\", "/")[13..-1], archive[n]] }
    end

    private

    # The folder under Data holding the most .rb files, widened to the top of its own subtree until it stops
    # holding only scripts and folders; never past Data, so a bundled Ruby stdlib copy isn't mistaken for the tree.
    def script_folder
      data = File.join(@root, "Data")
      return nil unless File.directory?(data)
      counts = {}
      Dir[File.join(data, "**", "*.rb")].each do |file|
        counts[File.dirname(file)] = (counts[File.dirname(file)] || 0) + 1
      end
      best = counts.keys.max_by { |dir| counts[dir] }
      return nil if best.nil?
      best = File.dirname(best) while scripts_only?(File.dirname(best)) && File.dirname(best).length > data.length
      best
    end

    def scripts_only?(dir)
      entries = Dir[File.join(dir, "*")]
      !entries.empty? && entries.all? { |e| File.directory?(e) || e =~ /\.rb\z/i }
    end

    def archive
      return @archive if @archive
      packed = Dir[File.join(@root, "*.rgssad")] + Dir[File.join(@root, "*.rgss2a")]
      unsupported = Dir[File.join(@root, "*.rgss3a")]
      if packed.empty? && !unsupported.empty?
        raise "#{File.basename(unsupported.first)} is an RPG Maker VX Ace archive; this tool reads XP games."
      end
      @archive = packed.empty? ? {} : ScriptDumper.read_rgssad(packed.first)
    end
  end

  # RGSSAD v1: a flat list of [name, size, data], every field XOR'd against a key that advances by k * 7 + 3
  # after each name byte and after each 4-byte word of content.
  def self.read_rgssad(path)
    raw = File.open(path, "rb") { |f| f.read }
    signature = raw[0, 8]
    raise "#{File.basename(path)} is not an RGSSAD archive." unless signature && signature[0, 6] == "RGSSAD"
    version = raw[7].respond_to?(:ord) ? raw[7].ord : raw[7]
    raise "#{File.basename(path)} is RGSSAD version #{version}; this tool reads version 1." unless version == 1
    entries = {}
    key = RGSSAD_KEY
    pos = 8
    while pos + 4 <= raw.length
      length = raw[pos, 4].unpack("V")[0] ^ key
      key = (key * 7 + 3) & MASK
      pos += 4
      break if length <= 0 || pos + length > raw.length
      name = ""
      raw[pos, length].each_byte do |b|
        name << (b ^ (key & 0xFF)).chr
        key = (key * 7 + 3) & MASK
      end
      pos += length
      break if pos + 4 > raw.length
      size = raw[pos, 4].unpack("V")[0] ^ key
      key = (key * 7 + 3) & MASK
      pos += 4
      break if size < 0 || pos + size > raw.length
      entries[name] = decrypt(raw[pos, size], key)
      pos += size
    end
    entries
  end

  def self.decrypt(data, key)
    out = ""
    words = data.unpack("V*")
    words.each do |w|
      out << [w ^ key].pack("V")
      key = (key * 7 + 3) & MASK
    end
    tail = data.length - words.length * 4
    if tail > 0
      k = key
      data[words.length * 4, tail].each_byte do |b|
        out << (b ^ (k & 0xFF)).chr
        k >>= 8
      end
    end
    out
  end

  # Scripts.rxdata is [[id, name, deflated source], ...]. The id is RPG Maker's own and is not used here.
  def self.engine_scripts(blob)
    Marshal.load(blob).map { |entry| [entry[1].to_s, inflate(entry[2])] }
  end

  # PluginScripts.rxdata is [[plugin name, metadata, [[file name, deflated source], ...]], ...]. Each plugin
  # becomes a folder, which is also how the game itself thinks about them.
  def self.plugin_scripts(blob)
    out = []
    Marshal.load(blob).each do |plugin|
      folder = plugin[0].to_s
      files = plugin[2]
      next unless files.is_a?(Array)
      files.each do |file|
        name = file[0].to_s.sub(/\.rb\z/i, "")
        out << ["_PluginScripts/#{folder}/#{name}", inflate(file[1])]
      end
    end
    out
  end

  def self.inflate(blob)
    Zlib::Inflate.inflate(blob.to_s)
  rescue Zlib::Error
    ""
  end

  # Script names come out of Marshal as raw bytes. Games written before UTF-8 was the default stored them in
  # the author's local codepage, so accented section names arrive as invalid UTF-8 and every later string
  # operation would raise. Latin-1 is the fallback because that is what a Spanish-language RPG Maker XP
  # wrote; anything still undecodable is replaced rather than allowed to abort the dump.
  def self.to_text(raw)
    text = raw.to_s.dup
    return text unless text.respond_to?(:force_encoding)
    text.force_encoding("UTF-8")
    return text if text.valid_encoding?
    text.force_encoding("Windows-1252").encode("UTF-8", :invalid => :replace, :undef => :replace, :replace => "_")
  rescue StandardError
    raw.to_s.gsub(/[^\x20-\x7e]/, "_")
  end

  # RPG Maker script names are free text -- slashes as section folders in newer Essentials, anything else a
  # human typed -- sanitized for Windows and prefixed with the load-order index unless the name starts with one.
  def self.safe_path(name, index)
    parts = to_text(name).split("/").map { |part| part.gsub(/[\\:*?"<>|\x00-\x1f]/, "_").strip }
    parts.reject! { |part| part.empty? || part == "." || part == ".." }
    return format("%04d_untitled", index) if parts.empty?
    parts[-1] = parts[-1].sub(/\.rb\z/i, "")
    numbered = parts.first == "_PluginScripts" || parts[-1] =~ /\A\d/
    parts[-1] = format("%04d_%s", index, parts[-1]) unless numbered
    parts.join("/")
  end

  # Dumps whichever of Scripts.rxdata or the loose script tree holds more code, keeping the loader beside it: it
  # says where the tree lives and in what order it loads.
  def self.dump(game_dir, out_dir)
    raise "#{game_dir} is not a folder." unless File.directory?(game_dir)
    source = Source.new(game_dir)
    engine = source.read("Data/Scripts.rxdata")
    tree = source.loose_tree
    raise no_scripts_message(game_dir) if engine.nil? && tree.empty?
    scripts = engine ? engine_scripts(engine) : []
    if !tree.empty? && volume(tree) > volume(scripts)
      puts "Data/Scripts.rxdata only holds a loader; reading the #{tree.length}-file script tree instead."
      scripts += tree
    end
    plugins = source.read("Data/PluginScripts.rxdata")
    scripts += plugin_scripts(plugins) if plugins
    write(scripts, out_dir, source.packed?)
  end

  def self.volume(scripts)
    scripts.inject(0) { |total, (_, code)| total + code.to_s.length }
  end

  # A wrong folder is the overwhelmingly likely reason, and it is usually one level away: games are often
  # unzipped into a folder named after the archive, with the real game inside it.
  def self.no_scripts_message(game_dir)
    nested = Dir[File.join(game_dir, "*")].select do |entry|
      File.directory?(entry) && File.directory?(File.join(entry, "Data"))
    end
    message = "No scripts found in #{game_dir} (this should be the folder with Game.exe in it)."
    return message if nested.empty?
    "#{message}\n       Try: #{nested.first}"
  end

  def self.write(scripts, out_dir, packed)
    written = 0
    empty = 0
    collisions = []
    used = {}
    scripts.each_with_index do |(name, code), index|
      if code.strip.empty?
        empty += 1
        next
      end
      path = safe_path(name, index)
      suffix = used[path.downcase]
      if suffix
        used[path.downcase] = suffix + 1
        collisions << name
        path = "#{path}~#{suffix}"
      else
        used[path.downcase] = 1
      end
      full = File.join(out_dir, "#{path}.rb")
      dir = File.dirname(full)
      require "fileutils"
      FileUtils.mkdir_p(dir)
      File.open(full, "wb") { |f| f.write(code) }
      written += 1
    end
    puts "Read from Game.rgssad (the game ships its data packed)." if packed
    puts "#{written} scripts written to #{out_dir}"
    puts "#{empty} empty entries skipped (RPG Maker separators)." if empty > 0
    unless collisions.empty?
      puts "#{collisions.length} name collisions, kept with a ~N suffix: #{collisions.uniq.join(", ")}"
    end
    written
  end
end

if __FILE__ == $PROGRAM_NAME
  game = ARGV[0]
  unless game
    puts "usage: ruby tools/dump_scripts.rb \"<game folder>\" [output folder]"
    puts "       the game folder is the one with Game.exe in it"
    exit 1
  end
  out = ARGV[1] || File.join(game, "Scripts_dump")
  begin
    ScriptDumper.dump(game, out)
  rescue StandardError => e
    puts "error: #{e.message}"
    exit 1
  end
end
