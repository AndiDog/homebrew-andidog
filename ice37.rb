class Ice37 < Formula
  desc "Comprehensive RPC framework"
  homepage "https://zeroc.com"
  url "https://github.com/zeroc-ice/ice/archive/v3.7.1.tar.gz"
  sha256 "b1526ab9ba80a3d5f314dacf22674dff005efb9866774903d0efca5a0fab326d"

  option "with-additional-compilers", "Build additional Slice compilers (slice2py, slice2js, slice2rb)"
  option "with-java", "Build Ice for Java and the IceGrid GUI app"
  option "without-python", "Build without Ice for Python"

  depends_on "lmdb"
  depends_on :macos => :mavericks
  depends_on "mcpp"
  depends_on :java => ["1.8+", :optional]
  depends_on "python@2"

  patch do
    url "https://github.com/zeroc-ice/ice/compare/v3.7.1..v3.7.1-xcode10.patch?full_index=1"
    sha256 "28eff5dd6cb6065716a7664f3973213a2e5186ddbdccb1c1c1d832be25490f1b"
  end

  def install
    ENV.O2 # Os causes performance issues
    # Ensure Gradle uses a writable directory even in sandbox mode
    ENV["GRADLE_USER_HOME"] = "#{buildpath}/.gradle"

    args = [
      "prefix=#{prefix}",
      "V=1",
      "MCPP_HOME=#{Formula["mcpp"].opt_prefix}",
      "LMDB_HOME=#{Formula["lmdb"].opt_prefix}",
      "CONFIGS=shared cpp11-shared xcodesdk cpp11-xcodesdk",
      "PLATFORMS=all",
      # We don't build slice2py, slice2js, slice2rb by default to prevent clashes with
      # the translators installed by the PyPI/GEM/npm packages.
      "SKIP=slice2confluence #{build.without?("python") && build.without?("additional-compilers") ? "slice2py" : ""} #{build.without?("additional-compilers") ? "slice2rb slice2js" : ""}",
      "LANGUAGES=cpp objective-c #{build.with?("java") ? "java java-compat" : ""} #{build.with?("python") ? "python" : ""}",
    ]

    if build.with? "python"
      args << "PYTHON_LIB_NAME=-Wl,-undefined,dynamic_lookup"
      cd "python" do
        inreplace "config/install_dir", "print(e.install_dir)", "print('#{lib}/python2.7/site-packages')"
      end

      # If building Python support, slice2py is required to generate Python code from slices. However if additional
      # compilers should not be installed, we must skip installation of slice2py
      # => patch Makefile macro `define create-translator-project`
      if build.without?("additional-compilers")
        inreplace "config/Make.project.rules",
                  /(define create-translator-project.*?\$1_install_platforms\s*:=.*?)endef/m,
                  "\\1\n" \
                  "ifeq ($(notdir $1),slice2py)\n" \
                  "$1_install_platforms := \n" \
                  "endif\n" \
                  "endef"
      end
    end

    system "make", "install", *args
  end

  test do
    (testpath / "Hello.ice").write <<~EOS
      module Test
      {
          interface Hello
          {
              void sayHello();
          }
      }
    EOS
    (testpath / "Test.cpp").write <<~EOS
      #include <Ice/Ice.h>
      #include <Hello.h>

      class HelloI : public Test::Hello
      {
      public:
        virtual void sayHello(const Ice::Current&) override {}
      };

      int main(int argc, char* argv[])
      {
        Ice::CommunicatorHolder ich(argc, argv);
        auto adapter = ich->createObjectAdapterWithEndpoints("Hello", "default -h localhost -p 10000");
        adapter->add(std::make_shared<HelloI>(), Ice::stringToIdentity("hello"));
        adapter->activate();
        return 0;
      }
    EOS
    system "#{bin}/slice2cpp", "Hello.ice"
    system ENV.cxx, "-DICE_CPP11_MAPPING", "-std=c++11", "-c", "-I#{include}", "-I.", "Hello.cpp"
    system ENV.cxx, "-DICE_CPP11_MAPPING", "-std=c++11", "-c", "-I#{include}", "-I.", "Test.cpp"
    system ENV.cxx, "-L#{lib}", "-o", "test", "Test.o", "Hello.o", "-lIce++11"
    system "./test"
  end
end
