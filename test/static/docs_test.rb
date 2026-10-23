# The technical documentation names only what exists: each relative link reaches a file, each repository path in
# backticks a file or folder, and each code identifier in backticks a name the code uses.
class DocsTest < PokeAccessTest
  DOCS = File.join(Harness::ROOT, "docs")
  CODE = %w[core games plugins loader test tools].freeze
  # Paths that live in an installed game or outside the repository, and names the code builds at run time.
  ELSEWHERE = %r{\A(accessibility/|decompiled Scripts/|Scripts_dump/|recordings/|fangames/)}
  BUILT = /__pa_orig_|__pa_override_/

  test "every relative link in the documentation reaches a file" do
    assert_equal [], pages.flat_map { |page| broken_links(page) }
  end

  test "every repository path in backticks exists" do
    assert_equal [], pages.flat_map { |page| spans(page).select { |s| repo_path?(s) && !exists?(s) }.map { |s| "#{rel(page)}: #{s}" } }
  end

  test "every code identifier in backticks is a name the code uses" do
    assert_equal [], pages.flat_map { |page| spans(page).map { |s| unknown_name(s) }.compact.map { |n| "#{rel(page)}: #{n}" } }
  end

  private

  # The documentation's Markdown pages.
  def pages
    Dir.glob(File.join(DOCS, "**", "*.md")).sort
  end

  # A page's path from the repository root.
  def rel(page)
    page.sub("#{Harness::ROOT}/", "")
  end

  # The page's text outside fenced code blocks.
  def prose(page)
    File.read(page).gsub(/^```.*?^```/m, "")
  end

  # The inline code spans of a page.
  def spans(page)
    prose(page).scan(/`([^`\n]+)`/).map { |m| m[0].strip }
  end

  # The page's relative links whose target does not exist, as "page: target".
  def broken_links(page)
    prose(page).scan(/\]\(([^)\s]+)\)/).map { |m| m[0] }.reject { |t| t =~ /\A(https?:|mailto:|#)/ }.map do |t|
      target = File.expand_path(t.sub(/#.*\z/, ""), File.dirname(page))
      File.exist?(target) ? nil : "#{rel(page)}: #{t}"
    end.compact
  end

  # True for a span that names a path of the repository: it starts with one of the repository's top-level entries
  # and has no spaces or placeholders (a folder relative to a module, such as gen6/, is not one).
  def repo_path?(s)
    return false unless s.include?("/") && s !~ /[\s<>*{}%$]/ && s !~ ELSEWHERE
    top_level.include?(s.split("/").first)
  end

  # The names at the repository's root.
  def top_level
    @@top_level ||= Dir.entries(Harness::ROOT) - [".", ".."]
  end

  # Whether a repository path exists, a trailing ":line" or slash aside.
  def exists?(s)
    File.exist?(File.join(Harness::ROOT, s.sub(/:\d+(-\d+)?\z/, "").chomp("/")))
  end

  # The last name of a span that is a code identifier (Mod::Const, Mod.meth, Class#meth) the code never mentions, or
  # nil.
  def unknown_name(s)
    return nil unless s =~ /\A[A-Za-z_]\w*(::[A-Za-z_]\w*)*([.#][A-Za-z_]\w*[?!=]?)?\z/ && s =~ /::|[.#]/
    return nil if s =~ BUILT || s.include?("/") || s =~ /\.(rb|txt|md|ya?ml|toml|json|ini|dll|exe|rs|py|rxdata|dat)\z/
    name = s.split(/::|[.#]/).last.sub(/[?!=]\z/, "")
    corpus =~ /\b#{Regexp.escape(name)}\b/ ? nil : s
  end

  # Every Ruby and text file of the code folders, joined, read once per run.
  def corpus
    @@corpus ||= CODE.flat_map { |d| Dir.glob(File.join(Harness::ROOT, d, "**", "*.{rb,txt}")) }
                     .map { |f| File.read(f) rescue "" }.join("\n")
  end
end
