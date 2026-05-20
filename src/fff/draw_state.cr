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
    getter error_msg : String?
    getter loading : Bool
    getter full : Bool

    def initialize(
      @scroll : Int32,
      @page_offset : Int32,
      @list : Array(String),
      @marked : Set(String),
      @search_mode : Bool,
      @search_term : String,
      @rename_mode : Bool,
      @rename_new_name : String,
      @prev_scroll : Int32,
      @prev_page_offset : Int32,
      @current_dir : String,
      @clipboard_mode : Symbol,
      @clipboard_size : Int32,
      @error_msg : String?,
      @loading : Bool,
      @full : Bool,
    )
    end
  end
end
