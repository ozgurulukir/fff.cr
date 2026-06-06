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
    getter stat_cache : Hash(String, File::Info)
    getter lstat_cache : Hash(String, File::Info)

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
      @stat_cache = Hash(String, File::Info).new
      @lstat_cache = Hash(String, File::Info).new
    end

    def read!
      @current_dir = Dir.current
      all_entries = Dir.entries(@current_dir)

      dirs = [] of String
      files = [] of String
      @hidden_count = 0
      @total_size = 0_i64
      @stat_cache.clear
      @lstat_cache.clear

      all_entries.each do |entry|
        next if entry == "." || entry == ".."

        if entry.starts_with?('.')
          unless @show_hidden
            @hidden_count += 1
            next
          end
        end

        path = File.join(@current_dir, entry)

        linfo = File.info?(path, follow_symlinks: false)
        next unless linfo
        @lstat_cache[path] = linfo

        info = File.info?(path) || linfo
        @stat_cache[path] = info

        if info.directory?
          dirs << path
        else
          files << path
          @total_size += info.size
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
        sorted_dirs = dirs.sort_by { |d| @stat_cache[d]?.try(&.size) || 0 }
        sorted_files = files.sort_by { |f| @stat_cache[f]?.try(&.size) || 0 }
      when :time
        sorted_dirs = dirs.sort_by { |d| @stat_cache[d]?.try(&.modification_time) || Time.unix(0) }
        sorted_files = files.sort_by { |f| @stat_cache[f]?.try(&.modification_time) || Time.unix(0) }
      else
        sorted_dirs = dirs
        sorted_files = files
      end

      sorted_dirs = sorted_dirs.reverse if @sort_reverse
      sorted_files = sorted_files.reverse if @sort_reverse

      sorted_dirs + sorted_files
    end

    def safe_navigate(target_dir : String) : Bool
      original_dir = @current_dir
      begin
        Dir.cd(target_dir)
        read!
        @current_dir = Dir.current
        true
      rescue e : Exception
        Dir.cd(original_dir) rescue nil
        begin
          read!
        rescue
          @list = [] of String
          @full_list = [] of String
        end
        raise e
      end
    end

    def go_parent : Bool
      parent = File.dirname(@current_dir)
      return false if parent == @current_dir

      safe_navigate(parent)
    end

    def go_home
      home = HOME || Dir.current
      safe_navigate(home)
    end

    def go_prev(prev_dir : String?, prev_child : String?) : Bool
      return false if prev_dir.nil? || prev_child.nil?
      return false unless Dir.exists?(prev_dir)

      safe_navigate(prev_dir)
    end

    def go_to(path : String) : Bool
      return false unless File.exists?(path) && File.directory?(path)

      safe_navigate(path)
    end

    def go_to_trash(trash_dir : String) : Bool
      return false unless Dir.exists?(trash_dir)

      safe_navigate(trash_dir)
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
