require "./search_engine"
require "./terminal"

module FFF
  class InputMode
    getter active : Bool
    getter mode : Symbol
    getter text : String
    getter cursor_pos : Int32
    getter original_list : Array(String)
    getter navigating : Bool
    getter match_count : Int32

    def initialize(@term : Terminal)
      @active = false
      @mode = :none
      @text = ""
      @cursor_pos = 0
      @original_list = [] of String
      @old_name = ""
      @navigating = false
      @match_count = -1
    end

    def start_search(current_list : Array(String))
      @mode = :search
      @active = true
      @text = ""
      @cursor_pos = 0
      @original_list = current_list.dup
      @navigating = false
      @match_count = current_list.size
    end

    def start_rename(old_name : String)
      @mode = :rename
      @active = true
      @text = old_name
      @cursor_pos = old_name.size
      @old_name = old_name
      @navigating = false
      @match_count = -1
    end

    def handle_key(key : String) : Bool
      @navigating = false
      return false unless @active

      case key
      when "\e", "escape"
        return true
      when "\r", "\n", "enter"
        return true
      when "\u0003"
        return true
      when "\u007F", "\b", "backspace"
        if @cursor_pos > 0
          @text = String.build { |s| s << @text[0...@cursor_pos - 1] << @text[@cursor_pos..] }
          @cursor_pos -= 1
        end
      when "\e[A", "\e[B", "up", "down"
        if @mode == :rename
          return false
        elsif @mode == :search
          @navigating = true
        end
      when "\e[D", "left"
        @cursor_pos -= 1 if @cursor_pos > 0
      when "\e[C", "right"
        @cursor_pos += 1 if @cursor_pos < @text.size
      when "\e[H", "home"
        @cursor_pos = 0
      when "\e[F", "end"
        @cursor_pos = @text.size
      when "\e[3~", "delete"
        if @cursor_pos < @text.size
          @text = String.build { |s| s << @text[0...@cursor_pos] << @text[@cursor_pos + 1..] }
        end
      else
        if key.bytesize > 0 && key.char_at(0).ord >= 32
          @text = String.build { |s| s << @text[0...@cursor_pos] << key << @text[@cursor_pos..] }
          @cursor_pos += 1
        end
      end

      false
    end

    def apply_search(list : Array(String)) : Array(String)
      return list unless @mode == :search
      return @original_list.tap { @match_count = @original_list.size } if @text.empty?

      result = if @text.starts_with?('!')
                 # Content search (ripgrep)
                 dir = Dir.current
                 query = @text[1..-1]
                 return @original_list.tap { @match_count = @original_list.size } if query.empty?
                 matches = SearchEngine.content_search(query, dir)
                 @original_list.select { |path| matches.includes?(path) }
               elsif @text.starts_with?('>')
                 # Recursive path search
                 dir = Dir.current
                 query = @text[1..-1]
                 return @original_list.tap { @match_count = @original_list.size } if query.empty?
                 SearchEngine.recursive_search(query, dir)
               else
                 # Fuzzy filename search
                 SearchEngine.fuzzy_match(list, @text)
               end

      @match_count = result.size
      result
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
      @mode = :none
      @text = ""
      @cursor_pos = 0
      @original_list.clear
      @old_name = ""
      @navigating = false
      @match_count = -1
    end

    def cursor_position : Int32
      case @mode
      when :search then 13 + @text.size
      when :rename then @term.height - 2
      else              0
      end
    end
  end
end
