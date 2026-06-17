require "../../src/fff/format_utils.cr"
require "spec"
require "../spec_helper.cr"
require "../../src/fff/input_mode.cr"
require "../../src/fff/terminal.cr"
require "../../src/fff/search_engine.cr"

describe FFF::InputMode do
  describe ".new" do
    it "creates input mode with default state" do
      term = FFF::Terminal.new
      input_mode = FFF::InputMode.new(term)

      input_mode.active.should be_false
      input_mode.mode.should eq(:none)
      input_mode.text.should eq("")
      input_mode.original_list.should be_empty
    end
  end

  describe "#start_search" do
    it "starts search mode" do
      term = FFF::Terminal.new
      input_mode = FFF::InputMode.new(term)
      current_list = ["file1.txt", "file2.txt", "dir1"]

      input_mode.start_search(current_list)

      input_mode.active.should be_true
      input_mode.mode.should eq(:search)
      input_mode.text.should eq("")
      input_mode.original_list.should eq(current_list)
    end

    it "stores a copy of the original list" do
      term = FFF::Terminal.new
      input_mode = FFF::InputMode.new(term)
      current_list = ["file1.txt", "file2.txt"]

      input_mode.start_search(current_list)

      current_list << "file3.txt"

      input_mode.original_list.should eq(["file1.txt", "file2.txt"])
    end
  end

  describe "#start_rename" do
    it "starts rename mode" do
      term = FFF::Terminal.new
      input_mode = FFF::InputMode.new(term)
      old_name = "old_file.txt"

      input_mode.start_rename(old_name)

      input_mode.active.should be_true
      input_mode.mode.should eq(:rename)
      input_mode.text.should eq(old_name)
    end
  end

  describe "#handle_key" do
    it "ignores keys when not active" do
      term = FFF::Terminal.new
      input_mode = FFF::InputMode.new(term)

      result = input_mode.handle_key("a")
      result.should be_false
      input_mode.text.should eq("")
    end

    it "returns true on ESC" do
      term = FFF::Terminal.new
      input_mode = FFF::InputMode.new(term)
      input_mode.start_search(["file1.txt"])

      result = input_mode.handle_key("\e")
      result.should be_true
    end

    it "returns true on Ctrl+C" do
      term = FFF::Terminal.new
      input_mode = FFF::InputMode.new(term)
      input_mode.start_search(["file1.txt"])

      result = input_mode.handle_key("\u0003")
      result.should be_true
    end

    it "returns true on Enter" do
      term = FFF::Terminal.new
      input_mode = FFF::InputMode.new(term)
      input_mode.start_search(["file1.txt"])

      result = input_mode.handle_key("\r")
      result.should be_true
    end

    it "deletes on backspace" do
      term = FFF::Terminal.new
      input_mode = FFF::InputMode.new(term)
      input_mode.start_search(["file1.txt"])

      "hello".each_char { |c| input_mode.handle_key(c.to_s) }

      input_mode.handle_key("\b")
      input_mode.text.should eq("hell")

      input_mode.handle_key("\u007F")
      input_mode.text.should eq("hel")
    end

    it "ignores up/down arrows in search mode" do
      term = FFF::Terminal.new
      input_mode = FFF::InputMode.new(term)
      input_mode.start_search(["file1.txt"])
      original_text = input_mode.text

      "abc".each_char { |c| input_mode.handle_key(c.to_s) }

      input_mode.handle_key("\e[A")
      input_mode.text.should eq("abc")

      input_mode.handle_key("\e[B")
      input_mode.text.should eq("abc")
    end

    it "adds printable characters" do
      term = FFF::Terminal.new
      input_mode = FFF::InputMode.new(term)
      input_mode.start_search(["file1.txt"])

      "hello".each_char { |c| input_mode.handle_key(c.to_s) }
      input_mode.text.should eq("hello")
    end

    it "handles Turkish characters" do
      term = FFF::Terminal.new
      input_mode = FFF::InputMode.new(term)
      input_mode.start_search(["file1.txt"])

      "üğşıöç".each_char { |c| input_mode.handle_key(c.to_s) }
      input_mode.text.should eq("üğşıöç")
    end

    it "ignores control characters (below 32)" do
      term = FFF::Terminal.new
      input_mode = FFF::InputMode.new(term)
      input_mode.start_search(["file1.txt"])

      "hello".each_char { |c| input_mode.handle_key(c.to_s) }

      input_mode.handle_key("\u0001")
      input_mode.text.should eq("hello")

      input_mode.handle_key("\u001F")
      input_mode.text.should eq("hello")
    end

    it "ignores empty keys" do
      term = FFF::Terminal.new
      input_mode = FFF::InputMode.new(term)
      input_mode.start_search(["file1.txt"])

      input_mode.handle_key("")
      input_mode.text.should eq("")
    end
  end

  describe "#apply_search" do
    it "returns original list when not in search mode" do
      term = FFF::Terminal.new
      input_mode = FFF::InputMode.new(term)
      list = ["file1.txt", "file2.txt", "dir1"]

      result = input_mode.apply_search(list)
      result.should eq(list)
    end

    it "returns original list when search text is empty" do
      term = FFF::Terminal.new
      input_mode = FFF::InputMode.new(term)
      list = ["file1.txt", "file2.txt", "dir1"]
      input_mode.start_search(list)

      result = input_mode.apply_search(list)
      result.should eq(list)
    end

    it "performs fuzzy filename search" do
      term = FFF::Terminal.new
      input_mode = FFF::InputMode.new(term)
      list = ["file1.txt", "file2.txt", "document.pdf"]
      input_mode.start_search(list)

      "file".each_char { |c| input_mode.handle_key(c.to_s) }
      result = input_mode.apply_search(list)
      result.should contain("file1.txt")
      result.should contain("file2.txt")
      result.should_not contain("document.pdf")

      # Reset and try different search
      input_mode.end
      input_mode.start_search(list)
      "doc".each_char { |c| input_mode.handle_key(c.to_s) }
      result = input_mode.apply_search(list)
      result.should contain("document.pdf")
      result.should_not contain("file1.txt")
    end
  end

  describe "#apply_rename" do
    it "returns nil when not in rename mode" do
      term = FFF::Terminal.new
      input_mode = FFF::InputMode.new(term)
      old_path = "/path/to/old_file.txt"

      result = input_mode.apply_rename(old_path)
      result.should be_nil
    end

    it "returns nil when new name is same as old name" do
      term = FFF::Terminal.new
      input_mode = FFF::InputMode.new(term)
      old_path = "/path/to/old_file.txt"
      input_mode.start_rename("old_file.txt")

      result = input_mode.apply_rename(old_path)
      result.should be_nil
    end

    it "returns error message when target file exists" do
      temp_dir = SpecHelper.create_temp_dir("rename_exists_test")
      begin
        SpecHelper.create_temp_file(temp_dir, "existing_file.txt", "content")
        old_path = File.join(temp_dir, "old_file.txt")

        term = FFF::Terminal.new
        input_mode = FFF::InputMode.new(term)
        input_mode.start_rename("old_file.txt")

        # Backspace old name then type new name
        "old_file.txt".size.times { input_mode.handle_key("\b") }
        "existing_file.txt".each_char { |c| input_mode.handle_key(c.to_s) }

        result = input_mode.apply_rename(old_path)
        result.should eq("Target exists: existing_file.txt")
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end

    it "renames file successfully" do
      temp_dir = SpecHelper.create_temp_dir("rename_success_test")
      begin
        old_path = File.join(temp_dir, "old_file.txt")
        new_path = File.join(temp_dir, "new_file.txt")
        File.write(old_path, "old content")

        term = FFF::Terminal.new
        input_mode = FFF::InputMode.new(term)
        input_mode.start_rename("old_file.txt")

        # Backspace old name then type new name
        "old_file.txt".size.times { input_mode.handle_key("\b") }
        "new_file.txt".each_char { |c| input_mode.handle_key(c.to_s) }

        result = input_mode.apply_rename(old_path)
        result.should be_nil

        File.exists?(old_path).should be_false
        File.exists?(new_path).should be_true
        File.read(new_path).should eq("old content")
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end

    it "returns error message when FileUtils.mv raises" do
      temp_dir = SpecHelper.create_temp_dir("rename_error_test")
      begin
        old_path = File.join(temp_dir, "old_file.txt")
        File.write(old_path, "content")

        # Target a path whose parent directory does not exist — triggers FileUtils.mv error
        target_name = "nonexistent_dir/out.txt"

        term = FFF::Terminal.new
        input_mode = FFF::InputMode.new(term)
        input_mode.start_rename("old_file.txt")

        "old_file.txt".size.times { input_mode.handle_key("\b") }
        target_name.each_char { |c| input_mode.handle_key(c.to_s) }

        result = input_mode.apply_rename(old_path)
        result.should_not be_nil
        result.as(String).size.should be > 0
      ensure
        SpecHelper.cleanup_temp_dir(temp_dir)
      end
    end
  end

  describe "#end" do
    it "resets to default state" do
      term = FFF::Terminal.new
      input_mode = FFF::InputMode.new(term)
      input_mode.start_search(["file1.txt"])
      "search text".each_char { |c| input_mode.handle_key(c.to_s) }

      input_mode.end

      input_mode.active.should be_false
      input_mode.mode.should eq(:none)
      input_mode.text.should eq("")
      input_mode.original_list.should be_empty
    end
  end

  describe "#cursor_pos" do
    it "starts at end of text in rename mode" do
      term = FFF::Terminal.new
      input_mode = FFF::InputMode.new(term)
      input_mode.start_rename("hello.txt")

      input_mode.cursor_pos.should eq(9)
    end

    it "moves left with left arrow" do
      term = FFF::Terminal.new
      input_mode = FFF::InputMode.new(term)
      input_mode.start_rename("hello.txt")

      input_mode.handle_key("\e[D")
      input_mode.cursor_pos.should eq(8)

      input_mode.handle_key("\e[D")
      input_mode.cursor_pos.should eq(7)
    end

    it "moves right with right arrow" do
      term = FFF::Terminal.new
      input_mode = FFF::InputMode.new(term)
      input_mode.start_rename("hello.txt")
      3.times { input_mode.handle_key("\e[D") }

      input_mode.cursor_pos.should eq(6)

      input_mode.handle_key("\e[C")
      input_mode.cursor_pos.should eq(7)
    end

    it "stays at 0 when moving left at start" do
      term = FFF::Terminal.new
      input_mode = FFF::InputMode.new(term)
      input_mode.start_rename("hi")

      5.times { input_mode.handle_key("\e[D") }
      input_mode.cursor_pos.should eq(0)
    end

    it "stays at end when moving right at end" do
      term = FFF::Terminal.new
      input_mode = FFF::InputMode.new(term)
      input_mode.start_rename("hi")

      5.times { input_mode.handle_key("\e[C") }
      input_mode.cursor_pos.should eq(2)
    end

    it "inserts text at cursor position" do
      term = FFF::Terminal.new
      input_mode = FFF::InputMode.new(term)
      input_mode.start_rename("hllo.txt")

      7.times { input_mode.handle_key("\e[D") }
      input_mode.handle_key("e")

      input_mode.text.should eq("hello.txt")
      input_mode.cursor_pos.should eq(2)
    end

    it "deletes character before cursor with backspace" do
      term = FFF::Terminal.new
      input_mode = FFF::InputMode.new(term)
      input_mode.start_rename("hello.txt")

      input_mode.handle_key("\b")
      input_mode.text.should eq("hello.tx")
      input_mode.cursor_pos.should eq(8)

      input_mode.handle_key("\b")
      input_mode.text.should eq("hello.t")
      input_mode.cursor_pos.should eq(7)
    end

    it "deletes character at cursor with delete key" do
      term = FFF::Terminal.new
      input_mode = FFF::InputMode.new(term)
      input_mode.start_rename("hello.txt")

      input_mode.handle_key("\e[D")
      input_mode.handle_key("\e[3~")

      input_mode.text.should eq("hello.tx")
      input_mode.cursor_pos.should eq(8)
    end
  end
end
