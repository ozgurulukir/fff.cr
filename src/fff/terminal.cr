require "term-color"
require "term-screen"
require "term-cursor"
require "term-reader"
require "term-prompt"

module FFF
  # Terminal wrapper using crystal-term shards
  class Terminal
    getter width : Int32
    getter height : Int32
    getter reader : Term::Reader
    getter prompt : Term::Prompt

    def initialize
      @width = 80
      @height = 24
      refresh_size
      @reader = Term::Reader.new
      @prompt = Term::Prompt.new
    end

    def max_items : Int32
      @height - 2  # Leave room for status line + prompt line
    end

    def refresh_size
      size = Term::Screen.size
      @height = size[0]  # rows
      @width = size[1]   # cols
    end

    def enter_tui
      refresh_size
      print Term::Cursor.hide
      print "\e[?1049h"   # alternate screen buffer
      print "\e[2J"       # clear
      print "\e[1;1H"     # home
      set_scroll_region
      update_window_title
      STDOUT.flush
      # Set STDIN to raw mode for key reading
      if STDIN.tty?
        STDIN.raw!
      end
    end

    def leave_tui
      print "\e[2J"
      print "\e[1;1H"
      print Term::Cursor.show
      print "\e[;r"      # reset scroll region
      print "\e[?1049l"   # restore main screen
      STDOUT.flush
      # Restore STDIN to normal (cooked + echo) for shell/prompt use.
      if STDIN.tty?
        STDIN.cooked!
      end
    end

    def move_to(row : Int32, col : Int32)
      # Raw ANSI to avoid term-cursor bug (swaps row/col)
      # Parameters are 0-indexed, ANSI uses 1-indexed
      print "\e[#{row + 1};#{col + 1}H"
    end

    def set_scroll_region
      # Set scroll region (top row 0 to max_items)
      max = max_items
      print "\e[0;#{max}r"
    end

    def update_window_title
      print "\e]0;fff - Fucking Fast File Manager\a"
    end

    def read_keypress : String?
      @reader.read_keypress(raw: false)  # raw: false = actually use raw mode
    end

    def ask(message : String) : String
      @prompt.ask(message) || ""
    end

    def confirm?(message : String) : Bool
      @prompt.yes?(message) || false
    end

    def keypress(message : String)
      @prompt.keypress(message)
    end
  end
end
