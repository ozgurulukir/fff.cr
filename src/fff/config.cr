require "file"
require "json"
require "./theme"

module FFF
  # Configuration from environment
  class Config
    getter editor : String
    getter opener : String
    getter trash_dir : String
    getter cd_on_exit : Bool
    getter cd_file : String
    getter ls_colors : Hash(String, Symbol)
    getter favorites : Hash(String, String)
    getter bookmarks : Hash(String, String)
    # ── New UI settings ──
    getter theme : Theme
    getter icons : Bool
    getter show_columns : Bool
    getter column_mode : Symbol
    getter preview : Bool
    getter preview_width : String?

    # ── Phase 14: key binding defaults — single source of truth ──
    # Each key is resolved as ENV[env]? || json_get(json, keys_array) || default.
    # Accessors are generated below so adding a key here keeps its resolution
    # and public config API in one place.
    KEY_DEFAULTS = {
      :up          => {env: "FFF_KEY_UP", keys: %w[keys up], default: "k"},
      :down        => {env: "FFF_KEY_DOWN", keys: %w[keys down], default: "j"},
      :enter       => {env: "FFF_KEY_ENTER", keys: %w[keys enter], default: "l"},
      :quit        => {env: "FFF_KEY_QUIT", keys: %w[keys quit], default: "q"},
      :search      => {env: "FFF_KEY_SEARCH", keys: %w[keys search], default: "/"},
      :parent      => {env: "FFF_KEY_PARENT", keys: %w[keys parent], default: "h"},
      :mark        => {env: "FFF_KEY_MARK", keys: %w[keys mark], default: " "},
      :mark_all    => {env: "FFF_KEY_MARK_ALL", keys: %w[keys mark_all], default: "m"},
      :copy        => {env: "FFF_KEY_COPY", keys: %w[keys copy], default: "y"},
      :move        => {env: "FFF_KEY_MOVE", keys: %w[keys move], default: "v"},
      :delete      => {env: "FFF_KEY_DELETE", keys: %w[keys delete], default: "d"},
      :new_dir     => {env: "FFF_KEY_NEW_DIR", keys: %w[keys new_dir], default: "n"},
      :paste       => {env: "FFF_KEY_PASTE", keys: %w[keys paste], default: "p"},
      :preview     => {env: "FFF_KEY_PREVIEW", keys: %w[keys preview], default: "i"},
      :page_up     => {env: "FFF_KEY_PAGE_UP", keys: %w[keys page_up], default: "\e[5~"},
      :page_down   => {env: "FFF_KEY_PAGE_DOWN", keys: %w[keys page_down], default: "\e[6~"},
      :top         => {env: "FFF_KEY_TOP", keys: %w[keys top], default: "g"},
      :bottom      => {env: "FFF_KEY_BOTTOM", keys: %w[keys bottom], default: "G"},
      :rename      => {env: "FFF_KEY_RENAME", keys: %w[keys rename], default: "r"},
      :shell       => {env: "FFF_KEY_SHELL", keys: %w[keys shell], default: "s"},
      :hidden      => {env: "FFF_KEY_HIDDEN", keys: %w[keys hidden], default: "."},
      :home        => {env: "FFF_KEY_HOME", keys: %w[keys home], default: "~"},
      :prev        => {env: "FFF_KEY_PREVIOUS", keys: %w[keys previous], default: "-"},
      :refresh     => {env: "FFF_KEY_REFRESH", keys: %w[keys refresh], default: "e"},
      :mkfile      => {env: "FFF_KEY_MKFILE", keys: %w[keys mkfile], default: "f"},
      :attributes  => {env: "FFF_KEY_ATTRIBUTES", keys: %w[keys attributes], default: "x"},
      :executable  => {env: "FFF_KEY_EXECUTABLE", keys: %w[keys executable], default: "X"},
      :go_dir      => {env: "FFF_KEY_GO_DIR", keys: %w[keys go_dir], default: ":"},
      :go_trash    => {env: "FFF_KEY_GO_TRASH", keys: %w[keys go_trash], default: "t"},
      :bulk_rename => {env: "FFF_KEY_BULK_RENAME", keys: %w[keys bulk_rename], default: "b"},
      :symlink     => {env: "FFF_KEY_SYMLINK", keys: %w[keys symlink], default: "S"},
      :help        => {env: "FFF_KEY_HELP", keys: %w[keys help], default: "?"},
    }

    @resolved_keys : Hash(Symbol, String)

    macro key_accessors
      {% for name, setting in KEY_DEFAULTS %}
        def key_{{name.id}} : String
          @resolved_keys[{{name}}]
        end
      {% end %}
    end

    key_accessors

    def initialize
      config_path = File.join(FFF::HOME, ".config", "fff", "config.json")
      json = if File.exists?(config_path)
               begin
                 JSON.parse(File.read(config_path))
               rescue
                 nil
               end
             else
               nil
             end

      @editor = resolve_lazy(json, "EDITOR", %w[editor]) { default_editor }
      @opener = resolve_lazy(json, "FFF_OPENER", %w[opener]) { default_opener }
      @trash_dir = resolve_lazy(json, "FFF_TRASH", %w[trash_dir]) { File.join(FFF::HOME, ".local", "share", "fff", "trash") }
      @cd_on_exit = (ENV["FFF_CD_ON_EXIT"]? == "1") || (json_get(json, %w[cd_on_exit]) == "true")
      @cd_file = resolve(json, "FFF_CD_FILE", %w[cd_file], File.join(FFF::HOME, ".cache", "fff", ".fff_d"))
      @ls_colors = parse_ls_colors
      @resolved_keys = KEY_DEFAULTS.transform_values do |setting|
        resolve(json, setting[:env], setting[:keys], setting[:default])
      end
      @favorites = parse_favorites(json)
      @bookmarks = parse_bookmarks(json)

      # ── New UI settings ──
      @theme = Theme.load(nil, json)
      @icons = (ENV["FFF_ICONS"]? == "1") || (json_get(json, %w[icons]) == "true")
      @show_columns = (ENV["FFF_COLUMNS"]? != "0") && (json_get(json, %w[columns]) != "false")
      @column_mode = parse_column_mode(resolve(json, "FFF_COLUMN_MODE", %w[column_mode], "size"))
      @preview = (ENV["FFF_PREVIEW"]? == "1") || (json_get(json, %w[preview]) == "true")
      @preview_width = ENV["FFF_PREVIEW_WIDTH"]? || json_get(json, %w[preview_width])
    end

    private def parse_column_mode(mode : String?) : Symbol
      case mode
      when "size" then :size
      when "date" then :date
      when "both" then :both
      else             :size
      end
    end

    private def json_get(json, keys : Array(String)) : String?
      return nil unless json
      node = json
      keys.each do |k|
        node = node[k]?
        return nil unless node
      end
      node.as_s? || node.to_s
    end

    # Resolve a config value: env var → JSON key path → default.
    # Plain string lookup (covers ~30 key binding assignments).
    private def resolve(json, env_var : String, keys : Array(String), default) : String
      ENV[env_var]? || json_get(json, keys) || default
    end

    # Resolve with a computed default: env var → JSON key path → block result.
    # Used when the default requires a method call (e.g. platform detection).
    private def resolve_lazy(json, env_var : String, keys : Array(String), &block : -> String) : String
      ENV[env_var]? || json_get(json, keys) || yield
    end

    private def default_opener
      {% if flag?(:windows) %}
        "explorer"
      {% elsif flag?(:darwin) %}
        "open"
      {% else %}
        "xdg-open"
      {% end %}
    end

    private def default_editor
      {% if flag?(:windows) %}
        "notepad"
      {% else %}
        "vi"
      {% end %}
    end

    private def parse_favorites(json)
      favs = Hash(String, String).new
      (1..9).each do |i|
        if path = ENV["FFF_FAV#{i}"]? || json_get(json, ["favorites", i.to_s])
          favs[i.to_s] = path
        end
      end
      favs
    end

    private def parse_bookmarks(json)
      bookmarks = Hash(String, String).new
      if json && (bm_node = json["bookmarks"]?)
        bm_node.as_h.each do |k, v|
          bookmarks[k] = v.as_s
        end
      end
      bookmarks
    end

    private def parse_ls_colors : Hash(String, Symbol)
      result = Hash(String, Symbol).new
      ls_colors = ENV["LS_COLORS"]?
      return result unless ls_colors

      ls_colors.split(':').each do |entry|
        next if entry.empty?
        parts = entry.split('=')
        next if parts.size != 2
        key, value = parts

        next unless key.starts_with?("*.")
        ext = key[2..].downcase

        color = parse_ls_color(value)
        result[ext] = color if color
      end

      result
    end

    private def parse_ls_color(code : String) : Symbol?
      case code
      when /01;31/, /31;01/ then :red
      when /01;32/, /32;01/ then :green
      when /01;33/, /33;01/ then :yellow
      when /01;34/, /34;01/ then :blue
      when /01;35/, /35;01/ then :magenta
      when /01;36/, /36;01/ then :cyan
      when /01;37/, /37;01/ then :white
      when "31"             then :red
      when "32"             then :green
      when "33"             then :yellow
      when "34"             then :blue
      when "35"             then :magenta
      when "36"             then :cyan
      when "37"             then :white
      else                       nil
      end
    end

    @key_bindings_cache : Hash(String, String)?

    def key_bindings : Hash(String, String)
      @key_bindings_cache ||= {
        "j" => key_down, "k" => key_up, "h" => key_parent, "l" => key_enter,
        "q" => key_quit, "/" => key_search, " " => key_mark, "m" => key_mark_all,
        "y" => key_copy, "v" => key_move, "p" => key_paste, "d" => key_delete,
        "n" => key_new_dir, "f" => key_mkfile, "r" => key_rename, "b" => key_bulk_rename,
        "i" => key_preview, "s" => key_shell, "g" => key_top, "G" => key_bottom,
        "." => key_hidden, "~" => key_home, "-" => key_prev, "e" => key_refresh,
        "x" => key_attributes, "X" => key_executable, ":" => key_go_dir, "t" => key_go_trash,
        "S" => key_symlink, "=" => "=", "+" => "+", "?" => key_help,
      }
    end
  end
end
