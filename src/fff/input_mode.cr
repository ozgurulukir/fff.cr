require "./search_engine"
require "./terminal"

module FFF
  # InputMode - Handles interactive input modes (search, rename)
  class InputMode
    getter active : Bool
    getter mode : Symbol  # :search, :rename, or :none
    getter text : String
    getter original_list : Array(String)

    def initialize(@term : Terminal)
      @active = false
      @mode = :none
      @text = ""
      @original_list = [] of String
      @old_name = ""
    end

    def start_search(current_list : Array(String))
      @mode = :search
      @active = true
      @text = ""
      @original_list = current_list.dup
    end

    def start_rename(old_name : String)
      @mode = :rename
      @active = true
      @text = old_name
      @old_name = old_name
    end

    def handle_key(key : String) : Bool
      return false unless @active

      case key
      when "\e", "\r"  # ESC or Enter - input complete
        return true
      when "\u0003", "\u007F"  # Ctrl+C or Backspace
        if @text.size > 0
          @text = @text[0...-1]
        end
      when "\e[A", "\e[B"  # Up/Down arrows in search mode - ignore
        # Do nothing, let navigation handle these
      else
        # Only accept printable characters
        if key.size == 1 && key[0].ord >= 32 && key[0].ord <= 126
          @text += key
        end
      end

      false
    end

    def apply_search(list : Array(String)) : Array(String)
      return list unless @mode == :search
      return @original_list if @text.empty?

      if @text.starts_with?('!')
        # Content search via ripgrep
        dir = Dir.current
        query = @text[1..-1]
        return @original_list if query.empty?

        matches = SearchEngine.content_search(query, dir)
        @original_list.select { |path| matches.includes?(path) }
      else
        # Fuzzy filename search
        SearchEngine.fuzzy_match(list, @text)
      end
    end

    def apply_rename(old_path : String) : String?
      return nil unless @mode == :rename
      return nil if @text.empty?
      return nil if @text == @old_name

      dir = File.dirname(old_path)
      new_path = File.join(dir, @text)

      return "Target exists: #{@text}" if File.exists?(new_path)

      begin
        FileUtils.mv(old_path, new_path)
        nil
      rescue e : Exception
        e.message
      end
    end

    def end(restore_original : Bool = true)
      @active = false
      result = @text.dup
      
      if @mode == :search && restore_original
        # Keep text for display but signal restore
      end

      @mode = :none
      @text = ""
      @original_list.clear
      @old_name = ""
      
      result
    end

    def draw_header(width : Int32)
      return unless @mode == :search
      @term.move_to(0, 0)
      print "\e[K"
      prompt = "Search: #{@text}_"
      prompt = prompt.ljust(width)[0...width]
      print Term::Color.truecolor_string(prompt, fore: Term::Color.color(:yellow), back: Term::Color.color(:blue))
    end

    def draw_prompt(width : Int32)
      return unless @mode == :rename
      @term.move_to(@term.height - 2, 0)
      prompt = "Rename to: #{@text}_"
      prompt = prompt.ljust(width)[0...width]
      print Term::Color.truecolor_string(prompt, fore: Term::Color.color(:yellow), back: Term::Color.color(:blue))
    end

    def cursor_position : Int32
      case @mode
      when :search then 13 + @text.size  # "Search: " is 8 chars + space + cursor
      when :rename then @term.height - 2
      else              0
      end
    end
  end
end
