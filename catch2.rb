require "formula"

class Catch2 < Formula
  homepage "https://github.com/catchorg/Catch2"
  url "https://github.com/catchorg/Catch2/archive/v2.1.2.tar.gz"
  sha256 "29cb20f65275e0b0482fc783ff156e55af855586b74c4f0eb98ab35b8593398f"

  conflicts_with "catch1", :because => "catch1 installs includes to same directory"

  def install
    include.install Dir['single_include/*']
  end
end
