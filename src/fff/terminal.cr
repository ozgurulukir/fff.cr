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
      @height - 2 # Leave room for status line + prompt line
    end

    def refresh_size
      size = Term::Screen.size
      @height = size[0] # rows
      @width = size[1]  # cols
    end

    def enter_tui
      refresh_size
      print Term::Cursor.hide
      print "\e[?1049h" # alternate screen buffer
      print "\e[2J"     # clear
      print "\e[1;1H"   # home
      set_scroll_region
      update_window_title
      STDOUT.flush
      # Note: term-reader manages raw mode automatically
    end

    def leave_tui
      print "\e[2J"
      print "\e[1;1H"
      print Term::Cursor.show
      reset_scroll_region
      print "\e[?1049l" # restore main screen
      STDOUT.flush
    end

    def clear
      print "\e[2J"
    end

    def move_to(row : Int32, col : Int32)
      # Raw ANSI to avoid term-cursor bug (swaps row/col)
      # Parameters are 0-indexed, ANSI uses 1-indexed
      print "\e[#{row + 1};#{col + 1}H"
    end

    def set_scroll_region
      # Set scroll region (top row 1 to max_items)
      # ANSI uses 1-indexed rows
      print "\e[1;#{@height - 2}r"
    end

    def reset_scroll_region
      print "\e[;r"
    end

    def update_window_title(path : String = "")
      title = path.empty? ? "fff-cr" : "fff-cr: #{path}"
      # Use both title sequences for better compatibility
      print "\e]2;#{title}\a"
      print "\e]2;#{title}\e\\"
    end

    def read_keypress : String?
      @reader.read_keypress(raw: false) # raw: false = actually use raw mode in term-reader
    rescue
      nil
    end

    def ask(message : String) : String
      @prompt.ask(message) || ""
    end

    def confirm_inline(message : String) : Bool
      row = @height - 2
      col = 0

      move_to(row, col)
      print "\e[K"
      prompt = "#{message} [y/N] "
      print Term::Color.truecolor_string(prompt, fore: Term::Color.color(:yellow), back: Term::Color.color(:blue))
      STDOUT.flush

      loop do
        key = @reader.read_keypress(raw: false) rescue nil
        case key
        when "y", "Y"
          move_to(row, col)
          print "\e[K"
          STDOUT.flush
          return true
        when "n", "N", "\e", "\u0003", nil
          move_to(row, col)
          print "\e[K"
          STDOUT.flush
          return false
        end
      end
    end

    # TUI içi inline text prompt — TUI'dan çıkmadan en altına soru çizer,
    # kullanıcı girdisini alır, Enter/Esc ile sonlandırır.
    # default: kullanıcı boş geçerse döndürülecek değer
    def prompt_inline(message : String, default : String? = nil) : String?
      row = @height - 2
      col = 0
      text = default.to_s
      cursor = text.size

      draw_prompt(row, col, message, text, cursor)

      loop do
        key = @reader.read_keypress(raw: false) rescue nil

        case key
        when "\e", "escape", nil
          move_to(row, col)
          print "\e[K"
          STDOUT.flush
          return nil
        when "\r", "\n", "enter"
          return text.empty? ? (default || "") : text
        when "\u0003"
          return nil
        when "\u007F", "\b", "backspace"
          if cursor > 0
            text = text[0...cursor - 1] + text[cursor..]
            cursor -= 1
            draw_prompt(row, col, message, text, cursor)
          end
        when "\e[3~", "delete"
          if cursor < text.size
            text = text[0...cursor] + text[cursor + 1..]
            draw_prompt(row, col, message, text, cursor)
          end
        when "\e[D", "left"
          cursor -= 1 if cursor > 0
          draw_prompt(row, col, message, text, cursor)
        when "\e[C", "right"
          cursor += 1 if cursor < text.size
          draw_prompt(row, col, message, text, cursor)
        when "\e[H", "home"
          cursor = 0
          draw_prompt(row, col, message, text, cursor)
        when "\e[F", "end"
          cursor = text.size
          draw_prompt(row, col, message, text, cursor)
        else
          if key && key.bytesize > 0 && key.char_at(0).ord >= 32
            text = text[0...cursor] + key + text[cursor..]
            cursor += 1
            draw_prompt(row, col, message, text, cursor)
          end
        end
      end
    end

    private def draw_prompt(row : Int32, col : Int32, message : String, text : String, cursor : Int32)
      move_to(row, col)
      print "\e[K"
      prompt = "#{message} #{text}"
      print Term::Color.truecolor_string(prompt, fore: Term::Color.color(:yellow), back: Term::Color.color(:blue))
      # Position cursor after the text
      move_to(row, col + 1 + text.size)
      STDOUT.flush
    end

    def keypress(message : String)
      @prompt.keypress(message)
    end
  end
end
