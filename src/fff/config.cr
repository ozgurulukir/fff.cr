require "file"

module FFF
  # Configuration from environment
  class Config
    getter editor : String
    getter opener : String
    getter trash_dir : String
    getter cd_on_exit : Bool
    getter cd_file : String
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

    def initialize
      @editor = ENV["EDITOR"]? || "vi"
      @opener = ENV["FFF_OPENER"]? || "xdg-open"
      @trash_dir = ENV["FFF_TRASH"]? || File.join(ENV["HOME"], ".local", "share", "fff", "trash")
      @cd_on_exit = (ENV["FFF_CD_ON_EXIT"]? == "1")
      @cd_file = ENV["FFF_CD_FILE"]? || File.join(ENV["HOME"], ".cache", "fff", ".fff_d")
      @key_up = ENV["FFF_KEY_UP"]? || "k"
      @key_down = ENV["FFF_KEY_DOWN"]? || "j"
      @key_enter = ENV["FFF_KEY_ENTER"]? || "l"
      @key_quit = ENV["FFF_KEY_QUIT"]? || "q"
      @key_search = ENV["FFF_KEY_SEARCH"]? || "/"
      @key_parent = ENV["FFF_KEY_PARENT"]? || "h"
      @key_mark = ENV["FFF_KEY_MARK"]? || " "
      @key_mark_all = ENV["FFF_KEY_MARK_ALL"]? || "m"
      @key_copy = ENV["FFF_KEY_COPY"]? || "y"
      @key_move = ENV["FFF_KEY_MOVE"]? || "v"
      @key_delete = ENV["FFF_KEY_DELETE"]? || "d"
      @key_new_dir = ENV["FFF_KEY_NEW_DIR"]? || "n"
      @key_paste = ENV["FFF_KEY_PASTE"]? || "p"
      @key_preview = ENV["FFF_KEY_PREVIEW"]? || "i"
      @key_page_up = ENV["FFF_KEY_PAGE_UP"]? || "\e[A"
      @key_page_down = ENV["FFF_KEY_PAGE_DOWN"]? || "\e[B"
      @key_top = ENV["FFF_KEY_TOP"]? || "g"
      @key_bottom = ENV["FFF_KEY_BOTTOM"]? || "G"
      @key_rename = ENV["FFF_KEY_RENAME"]? || "r"
      @key_shell = ENV["FFF_KEY_SHELL"]? || "s"
      @key_hidden = ENV["FFF_KEY_HIDDEN"]? || "."
      @key_home = ENV["FFF_KEY_HOME"]? || "~"
      @key_prev = ENV["FFF_KEY_PREVIOUS"]? || "-"
      @key_refresh = ENV["FFF_KEY_REFRESH"]? || "e"
      @key_mkfile = ENV["FFF_KEY_MKFILE"]? || "f"
      @key_attributes = ENV["FFF_KEY_ATTRIBUTES"]? || "x"
      @key_executable = ENV["FFF_KEY_EXECUTABLE"]? || "X"
      @key_go_dir = ENV["FFF_KEY_GO_DIR"]? || ":"
      @key_go_trash = ENV["FFF_KEY_GO_TRASH"]? || "t"
    end

    # Parse LS_COLORS into a hash of extension => color symbol
    def ls_colors : Hash(String, Symbol)
      result = Hash(String, Symbol).new
      ls_colors = ENV["LS_COLORS"]?
      return result unless ls_colors

      ls_colors.split(':').each do |entry|
        next if entry.empty?
        parts = entry.split('=')
        next if parts.size != 2
        key, value = parts

        # Only handle extension patterns (*.ext)
        next unless key.starts_with?("*.")
        ext = key[2..].downcase

        # Parse ANSI color code to symbol
        color = parse_ls_color(value)
        result[ext] = color if color
      end

      result
    end

    # Parse LS_COLORS ANSI code to Term::Color symbol
    private def parse_ls_color(code : String) : Symbol?
      # LS_COLORS uses ANSI codes like 01;31 (bold red), 34 (blue), etc.
      # Map common codes to our color symbols
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
  end
end
