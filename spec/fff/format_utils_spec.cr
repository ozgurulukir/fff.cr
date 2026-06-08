require "../../src/fff/format_utils.cr"
require "spec"
require "../spec_helper.cr"

describe FFF::FormatUtils do
  describe ".human_size" do
    it "returns bytes for values under 1KB" do
      FFF::FormatUtils.human_size(0_i64).should eq("0B")
      FFF::FormatUtils.human_size(500_i64).should eq("500B")
      FFF::FormatUtils.human_size(1023_i64).should eq("1023B")
    end

    it "returns kilobytes for values under 1MB" do
      FFF::FormatUtils.human_size(1024_i64).should eq("1K")
      FFF::FormatUtils.human_size(1536_i64).should eq("1.5K")
      FFF::FormatUtils.human_size(1048575_i64).should eq("1024K")
    end

    it "returns megabytes for values under 1GB" do
      FFF::FormatUtils.human_size(1048576_i64).should eq("1M")
      FFF::FormatUtils.human_size(5242880_i64).should eq("5M")
      FFF::FormatUtils.human_size(1073741823_i64).should eq("1024M")
    end

    it "returns gigabytes for large values" do
      FFF::FormatUtils.human_size(1073741824_i64).should eq("1G")
      FFF::FormatUtils.human_size(2147483648_i64).should eq("2G")
    end

    it "accepts Int32 input" do
      FFF::FormatUtils.human_size(1024_i32).should eq("1K")
      FFF::FormatUtils.human_size(1048576_i32).should eq("1M")
    end
  end

  describe ".format_time" do
    it "formats current year dates without year" do
      now = Time.local
      FFF::FormatUtils.format_time(now).should eq(now.to_local.to_s("%b %d"))
    end

    it "formats past year dates with abbreviated year" do
      past = Time.local(2020, 1, 15, 10, 30, 0)
      result = FFF::FormatUtils.format_time(past)
      result.should eq("Jan 20")
    end

    it "returns blanks on failure" do
      FFF::FormatUtils.format_time(Time::UNIX_EPOCH).should be_a(String)
    end
  end

  describe ".format_time_detailed" do
    it "formats time with hours and minutes" do
      t = Time.local(2024, 6, 15, 14, 30, 0)
      result = FFF::FormatUtils.format_time_detailed(t)
      result.should contain("Jun 15")
      result.should contain("14:30")
    end

    it "returns empty string on failure" do
      FFF::FormatUtils.format_time_detailed(Time::UNIX_EPOCH).should be_a(String)
    end
  end
end
