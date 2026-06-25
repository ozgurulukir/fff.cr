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
    getter key_up : String
    getter key_down : String
    getter key_enter : String
    getter key_quit : String
    getter key_search : String
    getter key_parent : String
    getter key_mark : String
    getter key_mark_all : String
    getter key_copy : String
    getter key_move : String
    getter key_delete : String
    getter key_new_dir : String
    getter key_paste : String
    getter key_preview : String
    getter key_page_up : String
    getter key_page_down : String
    getter key_top : String
    getter key_bottom : String
    getter key_rename : String
    getter key_shell : String
    getter key_hidden : String
    getter key_home : String
    getter key_prev : String
    getter key_refresh : String
    getter key_mkfile : String
    getter key_attributes : String
    getter key_executable : String
    getter key_go_dir : String
    getter key_go_trash : String
    getter key_bulk_rename : String
    getter key_symlink : String
    getter key_help : String
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
    # key_* ivar = ENV[env]? || json_get(json, keys_array) || default
    # Order mirrors this table. Add new keys here + getter + key_bindings entry.
    KEY_DEFAULTS = {
      up:          ["FFF_KEY_UP", %w[keys up], "k"],
      down:        ["FFF_KEY_DOWN", %w[keys down], "j"],
      enter:       ["FFF_KEY_ENTER", %w[keys enter], "l"],
      quit:        ["FFF_KEY_QUIT", %w[keys quit], "q"],
      search:      ["FFF_KEY_SEARCH", %w[keys search], "/"],
      parent:      ["FFF_KEY_PARENT", %w[keys parent], "h"],
      mark:        ["FFF_KEY_MARK", %w[keys mark], " "],
      mark_all:    ["FFF_KEY_MARK_ALL", %w[keys mark_all], "m"],
      copy:        ["FFF_KEY_COPY", %w[keys copy], "y"],
      move:        ["FFF_KEY_MOVE", %w[keys move], "v"],
      delete:      ["FFF_KEY_DELETE", %w[keys delete], "d"],
      new_dir:     ["FFF_KEY_NEW_DIR", %w[keys new_dir], "n"],
      paste:       ["FFF_KEY_PASTE", %w[keys paste], "p"],
      preview:     ["FFF_KEY_PREVIEW", %w[keys preview], "i"],
      page_up:     ["FFF_KEY_PAGE_UP", %w[keys page_up], "\e[5~"],
      page_down:   ["FFF_KEY_PAGE_DOWN", %w[keys page_down], "\e[6~"],
      top:         ["FFF_KEY_TOP", %w[keys top], "g"],
      bottom:      ["FFF_KEY_BOTTOM", %w[keys bottom], "G"],
      rename:      ["FFF_KEY_RENAME", %w[keys rename], "r"],
      shell:       ["FFF_KEY_SHELL", %w[keys shell], "s"],
      hidden:      ["FFF_KEY_HIDDEN", %w[keys hidden], "."],
      home:        ["FFF_KEY_HOME", %w[keys home], "~"],
      prev:        ["FFF_KEY_PREVIOUS", %w[keys previous], "-"],
      refresh:     ["FFF_KEY_REFRESH", %w[keys refresh], "e"],
      mkfile:      ["FFF_KEY_MKFILE", %w[keys mkfile], "f"],
      attributes:  ["FFF_KEY_ATTRIBUTES", %w[keys attributes], "x"],
      executable:  ["FFF_KEY_EXECUTABLE", %w[keys executable], "X"],
      go_dir:      ["FFF_KEY_GO_DIR", %w[keys go_dir], ":"],
      go_trash:    ["FFF_KEY_GO_TRASH", %w[keys go_trash], "t"],
      bulk_rename: ["FFF_KEY_BULK_RENAME", %w[keys bulk_rename], "b"],
      symlink:     ["FFF_KEY_SYMLINK", %w[keys symlink], "S"],
      help:        ["FFF_KEY_HELP", %w[keys help], "?"],
    }

    def initialize
      config_path = File.join(HOME, ".config", "fff", "config.json")
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
      @trash_dir = resolve_lazy(json, "FFF_TRASH", %w[trash_dir]) { File.join(HOME, ".local", "share", "fff", "trash") }
      @cd_on_exit = (ENV["FFF_CD_ON_EXIT"]? == "1") || (json_get(json, %w[cd_on_exit]) == "true")
      @cd_file = resolve(json, "FFF_CD_FILE", %w[cd_file], File.join(HOME, ".cache", "fff", ".fff_d"))
      @ls_colors = parse_ls_colors
      @key_up = resolve(json, "FFF_KEY_UP", %w[keys up], "k")
      @key_down = resolve(json, "FFF_KEY_DOWN", %w[keys down], "j")
      @key_enter = resolve(json, "FFF_KEY_ENTER", %w[keys enter], "l")
      @key_quit = resolve(json, "FFF_KEY_QUIT", %w[keys quit], "q")
      @key_search = resolve(json, "FFF_KEY_SEARCH", %w[keys search], "/")
      @key_parent = resolve(json, "FFF_KEY_PARENT", %w[keys parent], "h")
      @key_mark = resolve(json, "FFF_KEY_MARK", %w[keys mark], " ")
      @key_mark_all = resolve(json, "FFF_KEY_MARK_ALL", %w[keys mark_all], "m")
      @key_copy = resolve(json, "FFF_KEY_COPY", %w[keys copy], "y")
      @key_move = resolve(json, "FFF_KEY_MOVE", %w[keys move], "v")
      @key_delete = resolve(json, "FFF_KEY_DELETE", %w[keys delete], "d")
      @key_new_dir = resolve(json, "FFF_KEY_NEW_DIR", %w[keys new_dir], "n")
      @key_paste = resolve(json, "FFF_KEY_PASTE", %w[keys paste], "p")
      @key_preview = resolve(json, "FFF_KEY_PREVIEW", %w[keys preview], "i")
      @key_page_up = resolve(json, "FFF_KEY_PAGE_UP", %w[keys page_up], "\e[5~")
      @key_page_down = resolve(json, "FFF_KEY_PAGE_DOWN", %w[keys page_down], "\e[6~")
      @key_top = resolve(json, "FFF_KEY_TOP", %w[keys top], "g")
      @key_bottom = resolve(json, "FFF_KEY_BOTTOM", %w[keys bottom], "G")
      @key_rename = resolve(json, "FFF_KEY_RENAME", %w[keys rename], "r")
      @key_shell = resolve(json, "FFF_KEY_SHELL", %w[keys shell], "s")
      @key_hidden = resolve(json, "FFF_KEY_HIDDEN", %w[keys hidden], ".")
      @key_home = resolve(json, "FFF_KEY_HOME", %w[keys home], "~")
      @key_prev = resolve(json, "FFF_KEY_PREVIOUS", %w[keys previous], "-")
      @key_refresh = resolve(json, "FFF_KEY_REFRESH", %w[keys refresh], "e")
      @key_mkfile = resolve(json, "FFF_KEY_MKFILE", %w[keys mkfile], "f")
      @key_attributes = resolve(json, "FFF_KEY_ATTRIBUTES", %w[keys attributes], "x")
      @key_executable = resolve(json, "FFF_KEY_EXECUTABLE", %w[keys executable], "X")
      @key_go_dir = resolve(json, "FFF_KEY_GO_DIR", %w[keys go_dir], ":")
      @key_go_trash = resolve(json, "FFF_KEY_GO_TRASH", %w[keys go_trash], "t")
      @key_bulk_rename = resolve(json, "FFF_KEY_BULK_RENAME", %w[keys bulk_rename], "b")
      @key_symlink = resolve(json, "FFF_KEY_SYMLINK", %w[keys symlink], "S")
      @key_help = resolve(json, "FFF_KEY_HELP", %w[keys help], "?")
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

    private def json_get(json, keys : Array(String | Symbol)) : String?
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
    private def resolve(json, env_var : String, keys : Array(String | Symbol), default) : String
      ENV[env_var]? || json_get(json, keys) || default
    end

    # Resolve with a computed default: env var → JSON key path → block result.
    # Used when the default requires a method call (e.g. platform detection).
    private def resolve_lazy(json, env_var : String, keys : Array(String | Symbol), &block : -> String) : String
      ENV[env_var]? || json_get(json, keys) || yield
    end

    private def default_opener
      {% if flag?(:windows) %}
        "explorer"
      {% else %}
        output = IO::Memory.new
        Process.run("uname", output: output)
        case output.to_s.strip
        when "Darwin" then "open"
        else               "xdg-open"
        end
      {% end %}
    rescue
      {% if flag?(:windows) %}
        "explorer"
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
        "j" => @key_down, "k" => @key_up, "h" => @key_parent, "l" => @key_enter,
        "q" => @key_quit, "/" => @key_search, " " => @key_mark, "m" => @key_mark_all,
        "y" => @key_copy, "v" => @key_move, "p" => @key_paste, "d" => @key_delete,
        "n" => @key_new_dir, "f" => @key_mkfile, "r" => @key_rename, "b" => @key_bulk_rename,
        "i" => @key_preview, "s" => @key_shell, "g" => @key_top, "G" => @key_bottom,
        "." => @key_hidden, "~" => @key_home, "-" => @key_prev, "e" => @key_refresh,
        "x" => @key_attributes, "X" => @key_executable, ":" => @key_go_dir, "t" => @key_go_trash,
        "S" => @key_symlink, "=" => "=", "+" => "+", "?" => @key_help,
      }
    end
  end
end
