require File.expand_path("../../test_helper", __FILE__)

module Unit
  class TestMass < MiniTest::Unit::TestCase

    describe Mass do
      before do
        class Foo
          attr_accessor :foo
          class Bar
            attr_accessor :fool
          end
        end
        class Thing
          attr_accessor :food
        end
        class OneMoreThing
          attr_accessor :thing
        end
      end

      after do
        GC.start
      end

      it "should be able to return the object corresponding to the passed object_id" do
        f = Foo.new
        o = Mass[f.object_id]

        assert_equal true, f.object_id == o.object_id

        f = nil
        o = nil
      end

      it "should be able to index objects" do
        assert_equal({}, Mass.index(Foo))

        f = Foo.new
        b1 = Foo::Bar.new
        b2 = Foo::Bar.new
        t = Thing.new

        assert_equal({"Unit::TestMass::Foo" => [f.object_id], "Unit::TestMass::Foo::Bar" => [b1.object_id, b2.object_id].sort}, Mass.index(Foo))
        assert_equal({"Unit::TestMass::Foo::Bar" => [b1.object_id, b2.object_id].sort}, Mass.index(Foo::Bar))
        assert_equal({"Unit::TestMass::Thing" => [t.object_id]}, Mass.index(Thing))
        assert_equal({"Unit::TestMass::Foo::Bar" => [b1.object_id, b2.object_id].sort, "Unit::TestMass::Thing" => [t.object_id]}, Mass.index(Foo::Bar, Thing))
        assert_equal({}, Mass.index(OneMoreThing))

        index = Mass.index
        assert_equal true, index.keys.include?("String")
        assert_equal true, index.keys.include?("Array")
        assert_equal true, index.keys.include?("Hash")
        assert_equal true, index["String"].size > 1000

        f = nil
        b1 = nil
        b2 = nil
        t = nil
      end

      it "should be able to count objects" do
        assert_equal({}, Mass.count(Foo))

        f = Foo.new
        b1 = Foo::Bar.new
        b2 = Foo::Bar.new
        t = Thing.new

        assert_equal({"Unit::TestMass::Foo" => 1, "Unit::TestMass::Foo::Bar" => 2}, Mass.count(Foo))
        assert_equal({"Unit::TestMass::Foo::Bar" => 2}, Mass.count(Foo::Bar))
        assert_equal({"Unit::TestMass::Thing" => 1}, Mass.count(Thing))
        assert_equal({"Unit::TestMass::Foo::Bar" => 2, "Unit::TestMass::Thing" => 1}, Mass.count(Foo::Bar, Thing))
        assert_equal({}, Mass.count(OneMoreThing))

        count = Mass.count
        assert_equal true, count.keys.include?("String")
        assert_equal true, count.keys.include?("Array")
        assert_equal true, count.keys.include?("Hash")
        assert_equal true, count["String"] > 1000

        f = nil
        b1 = nil
        b2 = nil
        t = nil
      end

      # NOTE: The first assertion fails sometimes (maybe multiple test runs related?). If so, retry running the tests.
      it "should be able to locate object references" do
        f1 = Foo.new
        assert_equal({}, Mass.references(f1))

        f2 = Foo.new
        f2.foo = f1

        assert_equal({"Unit::TestMass::Foo##{f2.object_id}" => ["@foo"]}, Mass.references(f1))
        assert_equal({"Unit::TestMass::Foo##{f2.object_id}" => ["@foo"]}, Mass.references(f1, Foo))
        assert_equal({}, Mass.references(f1, Foo::Bar))
        assert_equal({}, Mass.references(f1, Foo::Bar, OneMoreThing))

        b = Foo::Bar.new
        b.fool = f1

        t = Thing.new
        t.food = f1

        assert_equal({
          "Unit::TestMass::Foo##{f2.object_id}" => ["@foo"],
          "Unit::TestMass::Foo::Bar##{b.object_id}" => ["@fool"],
          "Unit::TestMass::Thing##{t.object_id}" => ["@food"]
        }, Mass.references(f1))

        assert_equal({
          "Unit::TestMass::Foo##{f2.object_id}" => ["@foo"],
          "Unit::TestMass::Foo::Bar##{b.object_id}" => ["@fool"]
        }, Mass.references(f1, Foo))

        assert_equal({
          "Unit::TestMass::Foo##{f2.object_id}" => ["@foo"],
          "Unit::TestMass::Foo::Bar##{b.object_id}" => ["@fool"]
        }, Mass.references(f1, Foo, Foo::Bar))

        assert_equal({
          "Unit::TestMass::Foo::Bar##{b.object_id}" => ["@fool"]
        }, Mass.references(f1, Foo::Bar))

        assert_equal({
          "Unit::TestMass::Thing##{t.object_id}" => ["@food"]
        }, Mass.references(f1, Thing))

        assert_equal({}, Mass.references(f1, Hash, OneMoreThing))

        f1 = nil
        f2 = nil
        b = nil
        t = nil
      end

      describe "using simple objects" do
        # NOTE: I don't know why the last assertion fails (maybe test environment related?) as the same steps to succeed within script/console (see contents of the file)
        it "should be able to detach objects" do
          f1 = Foo.new
          object_id = f1.object_id

          assert_equal({}, Mass.references(f1))

          f2 = Foo.new
          f2.foo = f1
          b = Foo::Bar.new
          b.fool = f1
          t = Thing.new
          t.food = f1

          assert_equal({
            "Unit::TestMass::Foo" => [object_id, f2.object_id].sort,
            "Unit::TestMass::Foo::Bar" => [b.object_id]
          }, Mass.index(Foo))
          assert_equal({
            "Unit::TestMass::Foo##{f2.object_id}" => ["@foo"],
            "Unit::TestMass::Foo::Bar##{b.object_id}" => ["@fool"],
            "Unit::TestMass::Thing##{t.object_id}" => ["@food"]
          }, Mass.references(f1))

          assert_equal(false, Mass.detach(f1, OneMoreThing){ f1 = nil })

          assert_equal({
            "Unit::TestMass::Foo" => [object_id, f2.object_id].sort,
            "Unit::TestMass::Foo::Bar" => [b.object_id]
          }, Mass.index(Foo))
          assert_equal({
            "Unit::TestMass::Foo##{f2.object_id}" => ["@foo"],
            "Unit::TestMass::Foo::Bar##{b.object_id}" => ["@fool"],
            "Unit::TestMass::Thing##{t.object_id}" => ["@food"]
          }, Mass.references(f1))

          assert_equal(false, Mass.detach(f1, OneMoreThing, Thing){ f1 = nil })

          assert_equal({
            "Unit::TestMass::Foo" => [object_id, f2.object_id].sort,
            "Unit::TestMass::Foo::Bar" => [b.object_id]
          }, Mass.index(Foo))
          assert_equal({
            "Unit::TestMass::Foo##{f2.object_id}" => ["@foo"],
            "Unit::TestMass::Foo::Bar##{b.object_id}" => ["@fool"]
          }, Mass.references(f1))

          assert_equal(false, Mass.detach(f1, Foo::Bar){ f1 = nil })

          assert_equal({
            "Unit::TestMass::Foo" => [object_id, f2.object_id].sort,
            "Unit::TestMass::Foo::Bar" => [b.object_id]
          }, Mass.index(Foo))
          assert_equal({
            "Unit::TestMass::Foo##{f2.object_id}" => ["@foo"]
          }, Mass.references(f1))

          assert_equal(true, Mass.detach(f1){f1 = nil})

          Mass.gc!(f1)
          assert_equal({
            "Unit::TestMass::Foo" => [f2.object_id],
            "Unit::TestMass::Foo::Bar" => [b.object_id]
          }, Mass.index(Foo))
        end
      end

      describe "using complex objects" do
        it "should be able to detach objects" do
          # TODO
        end
      end
    end

  end
end