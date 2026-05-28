require "file_utils"

module FFF
  # DirectoryManager - Manages directory listing, navigation, and sorting
  class DirectoryManager
    getter current_dir : String
    getter list : Array(String)
    property list
    getter full_list : Array(String)
    getter show_hidden : Bool
    getter sort_mode : Symbol
    getter sort_reverse : Bool
    getter total_size : Int64
    getter hidden_count : Int32

    def initialize(start_dir : String)
      Dir.cd(start_dir)
      @current_dir = Dir.current
      @list = [] of String
      @full_list = [] of String
      @show_hidden = (ENV["FFF_HIDDEN"]? == "1")
      @sort_mode = :name
      @sort_reverse = false
      @total_size = 0_i64
      @hidden_count = 0
    end

    def read!
      @current_dir = Dir.current
      all_entries = Dir.entries(@current_dir)

      dirs = [] of String
      files = [] of String
      @hidden_count = 0
      @total_size = 0_i64

      all_entries.each do |entry|
        next if entry == "." || entry == ".."

        path = File.join(@current_dir, entry)
        next unless File.exists?(path)

        @hidden_count += 1 if !@show_hidden && entry.starts_with?('.')

        next if !@show_hidden && entry.starts_with?('.')

        if File.directory?(path)
          dirs << path
        else
          files << path
          if info = File.info?(path)
            @total_size += info.size
          end
        end
      end

      @full_list = sort(dirs, files)
      @list = @full_list
    end

    def sort(dirs : Array(String), files : Array(String)) : Array(String)
      case @sort_mode
      when :name
        sorted_dirs = dirs.sort_by { |d| File.basename(d).downcase }
        sorted_files = files.sort_by { |f| File.basename(f).downcase }
      when :size
        sorted_dirs = dirs.sort_by { |d| File.info(d).size }
        sorted_files = files.sort_by { |f| File.info?(f).try(&.size) || 0 }
      when :time
        sorted_dirs = dirs.sort_by { |d| File.info(d).modification_time }
        sorted_files = files.sort_by { |f| File.info?(f).try(&.modification_time) || Time.unix(0) }
      else
        sorted_dirs = dirs
        sorted_files = files
      end

      sorted_dirs = sorted_dirs.reverse if @sort_reverse
      sorted_files = sorted_files.reverse if @sort_reverse

      sorted_dirs + sorted_files
    end

    def go_parent : Bool
      parent = File.dirname(@current_dir)
      return false if parent == @current_dir

      Dir.cd(parent)
      read!
      true
    end

    def go_home
      home = HOME || Dir.current
      Dir.cd(home)
      read!
    end

    def go_prev(prev_dir : String?, prev_child : String?) : Bool
      return false if prev_dir.nil? || prev_child.nil?

      Dir.cd(prev_dir) if Dir.exists?(prev_dir)
      read!
      true
    end

    def go_to(path : String) : Bool
      return false unless File.exists?(path) && File.directory?(path)

      Dir.cd(path)
      read!
      true
    end

    def go_to_trash(trash_dir : String) : Bool
      return false unless Dir.exists?(trash_dir)

      Dir.cd(trash_dir)
      read!
      true
    end

    def refresh!
      read!
    end

    def toggle_hidden
      @show_hidden = !@show_hidden
      read!
    end

    def cycle_sort_mode
      @sort_mode = case @sort_mode
                   when :name then :size
                   when :size then :time
                   when :time then :name
                   else            :name
                   end
      read!
    end

    def toggle_sort_reverse
      @sort_reverse = !@sort_reverse
      read!
    end

    def find_child(name : String) : Int32?
      @list.index { |path| File.basename(path) == name }
    end
  end
end
