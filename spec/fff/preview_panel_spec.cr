require "../../src/fff/preview_panel.cr"
require "spec"
require "../spec_helper.cr"

describe FFF::PreviewPanel do
  describe ".new" do
    it "creates preview panel with default state" do
      panel = FFF::PreviewPanel.new
      panel.should be_a(FFF::PreviewPanel)
    end
  end

  describe "#panel_width" do
    it "returns 0 when terminal is too narrow" do
      panel = FFF::PreviewPanel.new
      panel.panel_width(70).should eq(0)
    end

    it "returns 0 at exactly MIN_WIDTH - 1" do
      panel = FFF::PreviewPanel.new
      panel.panel_width(79).should eq(0)
    end

    it "returns non-zero at MIN_WIDTH" do
      panel = FFF::PreviewPanel.new
      panel.panel_width(80).should be > 0
    end

    it "caps at MAX_PANEL_W for very wide terminals" do
      panel = FFF::PreviewPanel.new
      panel.panel_width(200).should eq(50)
    end

    it "scales proportionally" do
      panel = FFF::PreviewPanel.new
      w100 = panel.panel_width(100)
      w200 = panel.panel_width(200)
      w200.should be > w100
    end

    it "uses absolute value from config" do
      panel = FFF::PreviewPanel.new("30")
      panel.panel_width(120).should eq(30)
    end

    it "uses percentage from config" do
      panel = FFF::PreviewPanel.new("50%")
      panel.panel_width(100).should eq(50)
    end

    it "caps percentage result at MAX_PANEL_W" do
      panel = FFF::PreviewPanel.new("60%")
      panel.panel_width(120).should eq(50)
    end

    it "falls back to default ratio when config is nil" do
      panel = FFF::PreviewPanel.new(nil)
      panel.panel_width(100).should eq(40)
    end
  end

  describe "#list_width" do
    it "returns full width when preview is inactive" do
      panel = FFF::PreviewPanel.new
      panel.list_width(60).should eq(60)
    end

    it "returns term_width - panel_width - 1 when active" do
      panel = FFF::PreviewPanel.new
      pw = panel.panel_width(100)
      expected = 100 - pw - 1
      panel.list_width(100).should eq(expected)
    end
  end

  describe "#active?" do
    it "returns false when terminal is too narrow" do
      panel = FFF::PreviewPanel.new
      panel.active?(70).should be_false
    end

    it "returns false at exactly 79 columns" do
      panel = FFF::PreviewPanel.new
      panel.active?(79).should be_false
    end

    it "returns true at 80 columns" do
      panel = FFF::PreviewPanel.new
      panel.active?(80).should be_true
    end
  end

  describe "#entries_for" do
    it "returns empty array for non-directory path" do
      panel = FFF::PreviewPanel.new
      temp_file = SpecHelper.create_temp_file(Dir.tempdir, "preview_test_file.txt", "content")
      panel.entries_for(temp_file).should be_empty
      SpecHelper.cleanup_temp_file(temp_file)
    end

    it "caches directory entries on second call" do
      panel = FFF::PreviewPanel.new
      temp_dir = SpecHelper.create_temp_dir("preview_cache_test")
      SpecHelper.create_temp_file(temp_dir, "a.txt", "alpha")
      SpecHelper.create_temp_file(temp_dir, "b.txt", "beta")

      first = panel.entries_for(temp_dir)
      second = panel.entries_for(temp_dir)

      first.should eq(second)
      first.size.should eq(2)
      SpecHelper.cleanup_temp_dir(temp_dir)
    end

    it "invalidates cache when path changes" do
      panel = FFF::PreviewPanel.new
      dir1 = SpecHelper.create_temp_dir("preview_dir1")
      dir2 = SpecHelper.create_temp_dir("preview_dir2")
      SpecHelper.create_temp_file(dir1, "only_in_1.txt", "x")
      SpecHelper.create_temp_file(dir2, "only_in_2.txt", "y")

      panel.entries_for(dir1)
      entries2 = panel.entries_for(dir2)

      entries2.should contain(File.join(dir2, "only_in_2.txt"))
      entries2.should_not contain(File.join(dir1, "only_in_1.txt"))
      SpecHelper.cleanup_temp_dir(dir1)
      SpecHelper.cleanup_temp_dir(dir2)
    end

    it "sorts directories before files" do
      panel = FFF::PreviewPanel.new
      temp_dir = SpecHelper.create_temp_dir("preview_sort_test")
      SpecHelper.create_temp_file(temp_dir, "z_file.txt", "z")
      Dir.mkdir_p(File.join(temp_dir, "a_subdir"))
      SpecHelper.create_temp_file(temp_dir, "m_file.txt", "m")

      entries = panel.entries_for(temp_dir)
      dir_entries = entries.select { |e| File.directory?(e) }
      file_entries = entries.select { |e| File.file?(e) }

      dir_entries.size.should eq(1)
      file_entries.size.should eq(2)
      SpecHelper.cleanup_temp_dir(temp_dir)
    end
  end

  describe "#read_file_lines" do
    it "reads all lines from a small file" do
      panel = FFF::PreviewPanel.new
      temp_file = SpecHelper.create_temp_file(Dir.tempdir, "preview_lines_test.txt", "line1\nline2\nline3\n")
      lines = panel.read_file_lines(temp_file, 10)
      lines.size.should eq(3)
      SpecHelper.cleanup_temp_file(temp_file)
    end

    it "truncates at max_lines" do
      panel = FFF::PreviewPanel.new
      content = (1..100).map { |i| "line#{i}" }.join("\n")
      temp_file = SpecHelper.create_temp_file(Dir.tempdir, "preview_truncate_test.txt", content)
      lines = panel.read_file_lines(temp_file, 5)
      lines.size.should eq(5)
      SpecHelper.cleanup_temp_file(temp_file)
    end
  end

  describe "#draw" do
    it "returns immediately when preview is inactive" do
      panel = FFF::PreviewPanel.new
      theme = FFF::Theme.new
      panel.draw(70, 24, "/tmp", theme, 0, 24)
    end

    it "returns immediately when path is nil" do
      panel = FFF::PreviewPanel.new
      theme = FFF::Theme.new
      panel.draw(100, 24, nil, theme, 0, 24)
    end

    it "handles nonexistent file path without raising" do
      panel = FFF::PreviewPanel.new
      theme = FFF::Theme.new
      nonexistent = File.join(Dir.tempdir, "preview_nonexistent_#{Random::Secure.hex(8)}.txt")
      panel.draw(100, 24, nonexistent, theme, 0, 24)
    end

    it "handles unreadable text file gracefully" do
      panel = FFF::PreviewPanel.new
      theme = FFF::Theme.new
      temp_file = SpecHelper.create_temp_file(Dir.tempdir, "preview_unreadable.txt", "secret")
      File.chmod(temp_file, 0)
      begin
        panel.draw(100, 24, temp_file, theme, 0, 24)
      ensure
        File.chmod(temp_file, 0o644) rescue nil
        SpecHelper.cleanup_temp_file(temp_file)
      end
    end
  end
end
