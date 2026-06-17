require "spec"
require "../spec_helper.cr"
require "../../src/fff/draw_state.cr"

describe FFF::DrawState do
  describe ".new" do
    it "creates with default values" do
      state = FFF::DrawState.new
      state.scroll.should eq(0)
      state.page_offset.should eq(0)
      state.list.should be_empty
      state.marked.should be_empty
      state.search_mode.should be_false
      state.search_term.should eq("")
      state.rename_mode.should be_false
      state.rename_new_name.should eq("")
      state.prev_scroll.should eq(-1)
      state.prev_page_offset.should eq(-1)
      state.current_dir.should eq("")
      state.clipboard_mode.should eq(:none)
      state.clipboard_size.should eq(0)
      state.clipboard_items.should be_empty
      state.message.should be_nil
      state.loading.should be_false
      state.full.should be_false
      state.sort_mode.should eq(:name)
      state.sort_reverse.should be_false
      state.show_help.should be_false
      state.git_branch.should eq("")
      state.git_status.should eq("")
      state.cursor_pos.should eq(0)
      state.total_size.should eq(0_i64)
      state.hidden_count.should eq(0)
      state.stat_cache.should be_empty
      state.lstat_cache.should be_empty
      state.favorites.should be_empty
      state.match_count.should eq(-1)
      state.preview_path.should be_nil
    end

    it "creates with keyword arguments" do
      state = FFF::DrawState.new(
        scroll: 5,
        page_offset: 2,
        list: ["a.txt", "b.txt"],
        search_mode: true,
        search_term: "a",
        current_dir: "/tmp",
        clipboard_mode: :copy,
        total_size: 1024_i64,
        hidden_count: 3,
      )
      state.scroll.should eq(5)
      state.page_offset.should eq(2)
      state.list.should eq(["a.txt", "b.txt"])
      state.search_mode.should be_true
      state.search_term.should eq("a")
      state.current_dir.should eq("/tmp")
      state.clipboard_mode.should eq(:copy)
      state.total_size.should eq(1024_i64)
      state.hidden_count.should eq(3)
    end

    it "sets marked set from keyword argument" do
      marked = Set(String).new
      marked.add("/tmp/a.txt")
      state = FFF::DrawState.new(marked: marked)
      state.marked.should eq(marked)
    end

    it "sets favorites from keyword argument" do
      favs = Hash(String, String).new
      favs["1"] = "/tmp"
      state = FFF::DrawState.new(favorites: favs)
      state.favorites.should eq(favs)
    end

    it "sets preview_path" do
      state = FFF::DrawState.new(preview_path: "/tmp/test.txt")
      state.preview_path.should eq("/tmp/test.txt")
    end

    it "defaults preview_path to nil" do
      state = FFF::DrawState.new
      state.preview_path.should be_nil
    end
  end
end
