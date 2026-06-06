require "./message_bus"

module FFF
  struct DrawState
    getter scroll : Int32
    getter page_offset : Int32
    getter list : Array(String)
    getter marked : Set(String)
    getter search_mode : Bool
    getter search_term : String
    getter rename_mode : Bool
    getter rename_new_name : String
    getter prev_scroll : Int32
    getter prev_page_offset : Int32
    getter current_dir : String
    getter clipboard_mode : Symbol
    getter clipboard_size : Int32
    getter clipboard_items : Array(String)
    getter message : Message?
    getter loading : Bool
    getter full : Bool
    getter sort_mode : Symbol
    getter sort_reverse : Bool
    getter show_help : Bool
    getter git_branch : String
    getter git_status : String
    getter cursor_pos : Int32
    getter total_size : Int64
    getter hidden_count : Int32
    getter stat_cache : Hash(String, File::Info)
    getter lstat_cache : Hash(String, File::Info)
    getter favorites : Hash(String, String)
    getter match_count : Int32
    getter preview_path : String?

    def initialize(
      @scroll : Int32 = 0,
      @page_offset : Int32 = 0,
      @list : Array(String) = [] of String,
      @marked : Set(String) = Set(String).new,
      @search_mode : Bool = false,
      @search_term : String = "",
      @rename_mode : Bool = false,
      @rename_new_name : String = "",
      @prev_scroll : Int32 = -1,
      @prev_page_offset : Int32 = -1,
      @current_dir : String = "",
      @clipboard_mode : Symbol = :none,
      @clipboard_size : Int32 = 0,
      @clipboard_items : Array(String) = [] of String,
      @message : Message? = nil,
      @loading : Bool = false,
      @full : Bool = false,
      @sort_mode : Symbol = :name,
      @sort_reverse : Bool = false,
      @show_help : Bool = false,
      @git_branch : String = "",
      @git_status : String = "",
      @cursor_pos : Int32 = 0,
      @total_size : Int64 = 0_i64,
      @hidden_count : Int32 = 0,
      @stat_cache : Hash(String, File::Info) = Hash(String, File::Info).new,
      @lstat_cache : Hash(String, File::Info) = Hash(String, File::Info).new,
      @favorites : Hash(String, String) = Hash(String, String).new,
      @match_count : Int32 = -1,
      @preview_path : String? = nil
    )
    end
  end
end
