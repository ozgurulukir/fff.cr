module FFF
  # RGB color tuple for truecolor terminal output
  alias RGB = {UInt8, UInt8, UInt8}

  # Theme — Central color management for all TUI rendering.
  # Replaces hardcoded Term::Color symbols with RGB truecolor values.
  # Loaded from FFF_THEME env, config.json "theme", or defaults.
  struct Theme
    getter topbar_bg : RGB
    getter topbar_fg : RGB
    getter status_bg : RGB
    getter status_fg : RGB
    getter selection_bg : RGB
    getter selection_fg : RGB
    getter bg : RGB
    getter fg : RGB
    getter accent : RGB
    getter marked : RGB
    getter error : RGB
    getter success : RGB
    getter warning : RGB
    getter info : RGB
    getter dir_color : RGB
    getter exec_color : RGB
    getter symlink_color : RGB
    getter dim : RGB
    getter border : RGB
    getter search_match : RGB
    getter git_added : RGB
    getter git_modified : RGB
    getter git_untracked : RGB
    getter git_deleted : RGB
    getter bookmark_bg : RGB
    getter bookmark_fg : RGB
    getter bookmark_active : RGB
    getter preview_border : RGB
    getter preview_header : RGB
    getter progress_fill : RGB
    getter progress_empty : RGB

    def initialize(
      @topbar_bg = {30_u8, 30_u8, 46_u8},
      @topbar_fg = {205_u8, 214_u8, 244_u8},
      @status_bg = {24_u8, 24_u8, 37_u8},
      @status_fg = {186_u8, 194_u8, 222_u8},
      @selection_bg = {69_u8, 71_u8, 90_u8},
      @selection_fg = {205_u8, 214_u8, 244_u8},
      @bg = {30_u8, 30_u8, 46_u8},
      @fg = {205_u8, 214_u8, 244_u8},
      @accent = {137_u8, 180_u8, 250_u8},
      @marked = {249_u8, 226_u8, 175_u8},
      @error = {243_u8, 139_u8, 168_u8},
      @success = {166_u8, 227_u8, 161_u8},
      @warning = {249_u8, 226_u8, 175_u8},
      @info = {137_u8, 180_u8, 250_u8},
      @dir_color = {137_u8, 180_u8, 250_u8},
      @exec_color = {166_u8, 227_u8, 161_u8},
      @symlink_color = {245_u8, 194_u8, 231_u8},
      @dim = {108_u8, 112_u8, 134_u8},
      @border = {88_u8, 91_u8, 112_u8},
      @search_match = {249_u8, 226_u8, 175_u8},
      @git_added = {166_u8, 227_u8, 161_u8},
      @git_modified = {249_u8, 226_u8, 175_u8},
      @git_untracked = {148_u8, 226_u8, 213_u8},
      @git_deleted = {243_u8, 139_u8, 168_u8},
      @bookmark_bg = {24_u8, 24_u8, 37_u8},
      @bookmark_fg = {108_u8, 112_u8, 134_u8},
      @bookmark_active = {137_u8, 180_u8, 250_u8},
      @preview_border = {88_u8, 91_u8, 112_u8},
      @preview_header = {137_u8, 180_u8, 250_u8},
      @progress_fill = {137_u8, 180_u8, 250_u8},
      @progress_empty = {69_u8, 71_u8, 90_u8}
    )
    end

    # ── Built-in Themes ────────────────────────────────────────────

    BUILTIN_THEMES = {
      "default" => Theme.new,

      "catppuccin-mocha" => Theme.new(
        topbar_bg: {30_u8, 30_u8, 46_u8},
        topbar_fg: {205_u8, 214_u8, 244_u8},
        status_bg: {24_u8, 24_u8, 37_u8},
        status_fg: {186_u8, 194_u8, 222_u8},
        selection_bg: {69_u8, 71_u8, 90_u8},
        selection_fg: {205_u8, 214_u8, 244_u8},
        bg: {30_u8, 30_u8, 46_u8},
        fg: {205_u8, 214_u8, 244_u8},
        accent: {137_u8, 180_u8, 250_u8},
        marked: {249_u8, 226_u8, 175_u8},
        error: {243_u8, 139_u8, 168_u8},
        success: {166_u8, 227_u8, 161_u8},
        warning: {249_u8, 226_u8, 175_u8},
        info: {137_u8, 180_u8, 250_u8},
        dir_color: {137_u8, 180_u8, 250_u8},
        exec_color: {166_u8, 227_u8, 161_u8},
        symlink_color: {245_u8, 194_u8, 231_u8},
        dim: {108_u8, 112_u8, 134_u8},
        border: {88_u8, 91_u8, 112_u8},
        search_match: {249_u8, 226_u8, 175_u8},
        git_added: {166_u8, 227_u8, 161_u8},
        git_modified: {249_u8, 226_u8, 175_u8},
        git_untracked: {148_u8, 226_u8, 213_u8},
        git_deleted: {243_u8, 139_u8, 168_u8},
        bookmark_bg: {24_u8, 24_u8, 37_u8},
        bookmark_fg: {108_u8, 112_u8, 134_u8},
        bookmark_active: {137_u8, 180_u8, 250_u8},
        preview_border: {88_u8, 91_u8, 112_u8},
        preview_header: {137_u8, 180_u8, 250_u8},
        progress_fill: {137_u8, 180_u8, 250_u8},
        progress_empty: {69_u8, 71_u8, 90_u8},
      ),

      "gruvbox-dark" => Theme.new(
        topbar_bg: {40_u8, 40_u8, 40_u8},
        topbar_fg: {235_u8, 219_u8, 178_u8},
        status_bg: {29_u8, 32_u8, 33_u8},
        status_fg: {213_u8, 196_u8, 161_u8},
        selection_bg: {80_u8, 73_u8, 69_u8},
        selection_fg: {251_u8, 241_u8, 199_u8},
        bg: {40_u8, 40_u8, 40_u8},
        fg: {235_u8, 219_u8, 178_u8},
        accent: {131_u8, 165_u8, 152_u8},
        marked: {250_u8, 189_u8, 47_u8},
        error: {251_u8, 73_u8, 52_u8},
        success: {184_u8, 187_u8, 38_u8},
        warning: {250_u8, 189_u8, 47_u8},
        info: {131_u8, 165_u8, 152_u8},
        dir_color: {131_u8, 165_u8, 152_u8},
        exec_color: {184_u8, 187_u8, 38_u8},
        symlink_color: {211_u8, 134_u8, 155_u8},
        dim: {146_u8, 131_u8, 116_u8},
        border: {80_u8, 73_u8, 69_u8},
        search_match: {250_u8, 189_u8, 47_u8},
        git_added: {184_u8, 187_u8, 38_u8},
        git_modified: {250_u8, 189_u8, 47_u8},
        git_untracked: {131_u8, 165_u8, 152_u8},
        git_deleted: {251_u8, 73_u8, 52_u8},
        bookmark_bg: {29_u8, 32_u8, 33_u8},
        bookmark_fg: {146_u8, 131_u8, 116_u8},
        bookmark_active: {254_u8, 128_u8, 25_u8},
        preview_border: {80_u8, 73_u8, 69_u8},
        preview_header: {131_u8, 165_u8, 152_u8},
        progress_fill: {254_u8, 128_u8, 25_u8},
        progress_empty: {80_u8, 73_u8, 69_u8},
      ),

      "nord" => Theme.new(
        topbar_bg: {46_u8, 52_u8, 64_u8},
        topbar_fg: {236_u8, 239_u8, 244_u8},
        status_bg: {59_u8, 66_u8, 82_u8},
        status_fg: {229_u8, 233_u8, 240_u8},
        selection_bg: {67_u8, 76_u8, 94_u8},
        selection_fg: {236_u8, 239_u8, 244_u8},
        bg: {46_u8, 52_u8, 64_u8},
        fg: {216_u8, 222_u8, 233_u8},
        accent: {136_u8, 192_u8, 208_u8},
        marked: {235_u8, 203_u8, 139_u8},
        error: {191_u8, 97_u8, 106_u8},
        success: {163_u8, 190_u8, 140_u8},
        warning: {235_u8, 203_u8, 139_u8},
        info: {129_u8, 161_u8, 193_u8},
        dir_color: {136_u8, 192_u8, 208_u8},
        exec_color: {163_u8, 190_u8, 140_u8},
        symlink_color: {180_u8, 142_u8, 173_u8},
        dim: {76_u8, 86_u8, 106_u8},
        border: {67_u8, 76_u8, 94_u8},
        search_match: {235_u8, 203_u8, 139_u8},
        git_added: {163_u8, 190_u8, 140_u8},
        git_modified: {235_u8, 203_u8, 139_u8},
        git_untracked: {136_u8, 192_u8, 208_u8},
        git_deleted: {191_u8, 97_u8, 106_u8},
        bookmark_bg: {59_u8, 66_u8, 82_u8},
        bookmark_fg: {76_u8, 86_u8, 106_u8},
        bookmark_active: {136_u8, 192_u8, 208_u8},
        preview_border: {67_u8, 76_u8, 94_u8},
        preview_header: {136_u8, 192_u8, 208_u8},
        progress_fill: {136_u8, 192_u8, 208_u8},
        progress_empty: {67_u8, 76_u8, 94_u8},
      ),

      "dracula" => Theme.new(
        topbar_bg: {40_u8, 42_u8, 54_u8},
        topbar_fg: {248_u8, 248_u8, 242_u8},
        status_bg: {33_u8, 34_u8, 44_u8},
        status_fg: {248_u8, 248_u8, 242_u8},
        selection_bg: {68_u8, 71_u8, 90_u8},
        selection_fg: {248_u8, 248_u8, 242_u8},
        bg: {40_u8, 42_u8, 54_u8},
        fg: {248_u8, 248_u8, 242_u8},
        accent: {139_u8, 233_u8, 253_u8},
        marked: {241_u8, 250_u8, 140_u8},
        error: {255_u8, 85_u8, 85_u8},
        success: {80_u8, 250_u8, 123_u8},
        warning: {241_u8, 250_u8, 140_u8},
        info: {139_u8, 233_u8, 253_u8},
        dir_color: {189_u8, 147_u8, 249_u8},
        exec_color: {80_u8, 250_u8, 123_u8},
        symlink_color: {255_u8, 121_u8, 198_u8},
        dim: {98_u8, 114_u8, 164_u8},
        border: {68_u8, 71_u8, 90_u8},
        search_match: {241_u8, 250_u8, 140_u8},
        git_added: {80_u8, 250_u8, 123_u8},
        git_modified: {241_u8, 250_u8, 140_u8},
        git_untracked: {139_u8, 233_u8, 253_u8},
        git_deleted: {255_u8, 85_u8, 85_u8},
        bookmark_bg: {33_u8, 34_u8, 44_u8},
        bookmark_fg: {98_u8, 114_u8, 164_u8},
        bookmark_active: {189_u8, 147_u8, 249_u8},
        preview_border: {68_u8, 71_u8, 90_u8},
        preview_header: {189_u8, 147_u8, 249_u8},
        progress_fill: {189_u8, 147_u8, 249_u8},
        progress_empty: {68_u8, 71_u8, 90_u8},
      ),
    }

    # ── Loading ────────────────────────────────────────────────────

    def self.load(name : String? = nil, json : JSON::Any? = nil) : Theme
      theme_name = name || ENV["FFF_THEME"]? || json_theme_name(json) || "default"
      BUILTIN_THEMES[theme_name]? || BUILTIN_THEMES["default"]
    end

    private def self.json_theme_name(json : JSON::Any?) : String?
      return nil unless json
      json["theme"]?.try(&.["name"]?.try(&.as_s?))
    end

    # ── ANSI Rendering Helpers ────────────────────────────────────

    # Render text with truecolor foreground and background
    def self.fg_bg(text : String, fore : RGB, back : RGB) : String
      "\e[38;2;#{fore[0]};#{fore[1]};#{fore[2]}m\e[48;2;#{back[0]};#{back[1]};#{back[2]}m#{text}\e[0m"
    end

    # Render text with truecolor foreground only
    def self.fg(text : String, fore : RGB) : String
      "\e[38;2;#{fore[0]};#{fore[1]};#{fore[2]}m#{text}\e[0m"
    end

    # Render text with bold + truecolor foreground
    def self.fg_bold(text : String, fore : RGB) : String
      "\e[1m\e[38;2;#{fore[0]};#{fore[1]};#{fore[2]}m#{text}\e[0m"
    end

    # Render text with underline + truecolor foreground + background
    def self.fg_bg_bold_underline(text : String, fore : RGB, back : RGB) : String
      "\e[1;4m\e[38;2;#{fore[0]};#{fore[1]};#{fore[2]}m\e[48;2;#{back[0]};#{back[1]};#{back[2]}m#{text}\e[0m"
    end

    # Set truecolor foreground + background (no reset, for building strings)
    def self.set_fg_bg(fore : RGB, back : RGB) : String
      "\e[38;2;#{fore[0]};#{fore[1]};#{fore[2]}m\e[48;2;#{back[0]};#{back[1]};#{back[2]}m"
    end

    # Set truecolor foreground only (no reset)
    def self.set_fg(fore : RGB) : String
      "\e[38;2;#{fore[0]};#{fore[1]};#{fore[2]}m"
    end

    # Reset all attributes
    def self.reset : String
      "\e[0m"
    end
  end
end
