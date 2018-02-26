require "formula"

class Utfcpp < Formula
  homepage "http://utfcpp.sourceforge.net/"
  url "http://downloads.sourceforge.net/project/utfcpp/utf8cpp_2x/Release%202.3.4/utf8_v2_3_4.zip"
  sha256 "3373cebb25d88c662a2b960c4d585daf9ae7b396031ecd786e7bb31b15d010ef"

  def install
    doc.install Dir['doc/*']
    include.install Dir['source/*']
  end
end
