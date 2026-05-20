require "file"
require "json"

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
    getter favorites : Hash(String, String)
    getter bookmarks : Hash(String, String)

    def initialize
      config_path = File.join(ENV["HOME"], ".config", "fff", "config.json")
      json = if File.exists?(config_path)
               begin
                 JSON.parse(File.read(config_path))
               rescue
                 nil
               end
             else
               nil
             end

      @editor = ENV["EDITOR"]? || json_get(json, "editor") || "vi"
      @opener = ENV["FFF_OPENER"]? || json_get(json, "opener") || default_opener
      @trash_dir = ENV["FFF_TRASH"]? || json_get(json, "trash_dir") || File.join(ENV["HOME"], ".local", "share", "fff", "trash")
      @cd_on_exit = (ENV["FFF_CD_ON_EXIT"]? == "1") || (json_get(json, "cd_on_exit") == "true")
      @cd_file = ENV["FFF_CD_FILE"]? || json_get(json, "cd_file") || File.join(ENV["HOME"], ".cache", "fff", ".fff_d")
      @ls_colors = parse_ls_colors
      @key_up = ENV["FFF_KEY_UP"]? || json_get(json, "keys", "up") || "k"
      @key_down = ENV["FFF_KEY_DOWN"]? || json_get(json, "keys", "down") || "j"
      @key_enter = ENV["FFF_KEY_ENTER"]? || json_get(json, "keys", "enter") || "l"
      @key_quit = ENV["FFF_KEY_QUIT"]? || json_get(json, "keys", "quit") || "q"
      @key_search = ENV["FFF_KEY_SEARCH"]? || json_get(json, "keys", "search") || "/"
      @key_parent = ENV["FFF_KEY_PARENT"]? || json_get(json, "keys", "parent") || "h"
      @key_mark = ENV["FFF_KEY_MARK"]? || json_get(json, "keys", "mark") || " "
      @key_mark_all = ENV["FFF_KEY_MARK_ALL"]? || json_get(json, "keys", "mark_all") || "m"
      @key_copy = ENV["FFF_KEY_COPY"]? || json_get(json, "keys", "copy") || "y"
      @key_move = ENV["FFF_KEY_MOVE"]? || json_get(json, "keys", "move") || "v"
      @key_delete = ENV["FFF_KEY_DELETE"]? || json_get(json, "keys", "delete") || "d"
      @key_new_dir = ENV["FFF_KEY_NEW_DIR"]? || json_get(json, "keys", "new_dir") || "n"
      @key_paste = ENV["FFF_KEY_PASTE"]? || json_get(json, "keys", "paste") || "p"
      @key_preview = ENV["FFF_KEY_PREVIEW"]? || json_get(json, "keys", "preview") || "i"
      @key_page_up = ENV["FFF_KEY_PAGE_UP"]? || json_get(json, "keys", "page_up") || "\e[A"
      @key_page_down = ENV["FFF_KEY_PAGE_DOWN"]? || json_get(json, "keys", "page_down") || "\e[B"
      @key_top = ENV["FFF_KEY_TOP"]? || json_get(json, "keys", "top") || "g"
      @key_bottom = ENV["FFF_KEY_BOTTOM"]? || json_get(json, "keys", "bottom") || "G"
      @key_rename = ENV["FFF_KEY_RENAME"]? || json_get(json, "keys", "rename") || "r"
      @key_shell = ENV["FFF_KEY_SHELL"]? || json_get(json, "keys", "shell") || "s"
      @key_hidden = ENV["FFF_KEY_HIDDEN"]? || json_get(json, "keys", "hidden") || "."
      @key_home = ENV["FFF_KEY_HOME"]? || json_get(json, "keys", "home") || "~"
      @key_prev = ENV["FFF_KEY_PREVIOUS"]? || json_get(json, "keys", "previous") || "-"
      @key_refresh = ENV["FFF_KEY_REFRESH"]? || json_get(json, "keys", "refresh") || "e"
      @key_mkfile = ENV["FFF_KEY_MKFILE"]? || json_get(json, "keys", "mkfile") || "f"
      @key_attributes = ENV["FFF_KEY_ATTRIBUTES"]? || json_get(json, "keys", "attributes") || "x"
      @key_executable = ENV["FFF_KEY_EXECUTABLE"]? || json_get(json, "keys", "executable") || "X"
      @key_go_dir = ENV["FFF_KEY_GO_DIR"]? || json_get(json, "keys", "go_dir") || ":"
      @key_go_trash = ENV["FFF_KEY_GO_TRASH"]? || json_get(json, "keys", "go_trash") || "t"
      @key_bulk_rename = ENV["FFF_KEY_BULK_RENAME"]? || json_get(json, "keys", "bulk_rename") || "b"
      @key_symlink = ENV["FFF_KEY_SYMLINK"]? || json_get(json, "keys", "symlink") || "S"
      @favorites = parse_favorites(json)
      @bookmarks = parse_bookmarks(json)
    end

    private def json_get(json, *keys) : String?
      return nil unless json
      node = json
      keys.each do |k|
        node = node[k]?
        return nil unless node
      end
      node.as_s? || node.to_s
    end

    private def default_opener
      case `uname`.strip
      when "Darwin" then "open"
      else "xdg-open"
      end
    rescue
      "xdg-open"
    end

    private def parse_favorites(json)
      favs = Hash(String, String).new
      (1..9).each do |i|
        if path = ENV["FFF_FAV#{i}"]? || json_get(json, "favorites", i.to_s)
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
      when /01;31/, /31;01/  then :red
      when /01;32/, /32;01/  then :green
      when /01;33/, /33;01/  then :yellow
      when /01;34/, /34;01/  then :blue
      when /01;35/, /35;01/  then :magenta
      when /01;36/, /36;01/  then :cyan
      when /01;37/, /37;01/  then :white
      when "31"               then :red
      when "32"               then :green
      when "33"               then :yellow
      when "34"               then :blue
      when "35"               then :magenta
      when "36"               then :cyan
      when "37"               then :white
      else nil
      end
    end

    def key_bindings : Hash(String, String)
      {
        "j" => @key_down, "k" => @key_up, "h" => @key_parent, "l" => @key_enter,
        "q" => @key_quit, "/" => @key_search, " " => @key_mark, "m" => @key_mark_all,
        "y" => @key_copy, "v" => @key_move, "p" => @key_paste, "d" => @key_delete,
        "n" => @key_new_dir, "f" => @key_mkfile, "r" => @key_rename, "b" => @key_bulk_rename,
        "i" => @key_preview, "s" => @key_shell, "g" => @key_top, "G" => @key_bottom,
        "." => @key_hidden, "~" => @key_home, "-" => @key_prev, "e" => @key_refresh,
        "x" => @key_attributes, "X" => @key_executable, ":" => @key_go_dir, "t" => @key_go_trash,
        "S" => @key_symlink, "=" => "=", "+" => "+"
      }
    end
  end
end
