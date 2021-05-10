#!/usr/bin/env ruby

require_relative "Dopo"
require 'test/unit'

class Tester < Test::Unit::TestCase
#to run singular tests : ruby my_test.rb -n test_my_method
  def test_assignments
    p = Dopo.new
    Dopo.clean_scopes
    assert_equal( 5, p.start("(5,x)@"), "wrong assignment variable return")
    p.start("(10,x)@")
    assert_equal(10, p.start("x"), "wrong assignment variable return")
    p.start("(T,z)@\n(-20.33,a)@\n(a,b)@")
    assert_equal(10, p.start("x"), "wrong int var")
    assert_equal( true, p.start("z"), "wrong bool var")
    assert_equal(-20.33, p.start("a"),"wrong float var")
    assert_equal(-20.33, p.start("b"),"wrong copy assignment variable")
  end

  def test_func_assignments_calls
    p = Dopo.new
    Dopo.clean_scopes
    p.start("(\"Funkar\",x)@")
    p.start("(10,x)@")
    assert_equal(5, p.start("(x)@xr{x}\n (5)xr\n"),"wrong function return constant")
    p.start("(45,x)@")
    assert_equal(45, p.start("(x)xr"), "wrong function return variable")
  end

  def test_math_integration
    p = Dopo.new
    Dopo.clean_scopes
    assert_equal(4,p.start("(2,2)+"),"wrong 2+2")
    p.start("((2,2)+,x)@")
    assert_equal(4,p.start("x"),"wrong 2+2")
    p.start("(x)@xr{x}")
    p.start("(2,y)@")
    p.start("(4,z)@")
    assert_equal(4,p.start("((y,2)+)xr"))
    assert_equal(2,p.start("((z,y)/)xr"))
    assert_equal(8,p.start("((y,3)^)xr"))
    assert_equal(12,p.start("((2,6)*)xr"))
    assert_equal(-12,p.start("((y,-6)*)xr"))
    assert_equal(0,p.start("((15,5)%)xr"))
    assert_equal(1,p.start("((5,z)%)xr"))

    str = "(2,w)@\n(3,q)@\n(w,q)+"
    assert_equal(5,p.start(str))
    #test +@ operator
    str = "(2,w)@\n(3,q)@\n(1,w)+@\nw"
    assert_equal(3,p.start(str))
    #test -@ operator
    str = "(2,w)@\n(3,q)@\n(2,w)-@\nw"
    assert_equal(0,p.start(str))
    #test *@ operator
    str = "(2,w)@\n(3,q)@\n(3,w)*@\nw"
    assert_equal(6,p.start(str))
    #test /@ operator
    str = "(10,w)@\n(3,q)@\n(2,w)/@\nw"
    assert_equal(5,p.start(str))
    #test ^@ operator
    str = "(4,w)@\n(3,q)@\n(2,w)^@\nw"
    assert_equal(16,p.start(str))
    #test +@ operator with var
    str = "(10,w)@\n(3,q)@\n(q,w)+@\nw"
    assert_equal(13,p.start(str))
  end

  def test_bools_expr
    p = Dopo.new
    Dopo.clean_scopes

    assert_equal(true,p.start("(5,4)>"))
    assert_equal(false,p.start("(4,5)>"))
    assert_equal(true,p.start("(5,5)>="))
    assert_equal(false,p.start("(1,5)>="))
    assert_equal(true,p.start("(4,5)<="))
    assert_equal(false,p.start("(5,4)<="))
    assert_equal(true,p.start("(5,5)="))
    assert_equal(false,p.start("(4,5)="))
    assert_equal(true,p.start("(4,5)!="))
    assert_equal(true,p.start("(4,5)!="))
    assert_equal(true,p.start("(4,5)!="))

    p.start("(\"Funkar\",y)@\n(T,z)@\n(-20.33,a)@\n(a,b)@\n(T,t)@")
    assert_equal(p.start("a"),p.start("b"))
    assert_equal(true, (p.start("(a,b)=")))
    assert_equal(false, (p.start("(a,b)>")))
    assert_equal(false, (p.start("(a,b)<")))
    assert_equal(true, (p.start("(a,b)>=")))
    assert_equal(true, (p.start("(a,b)<=")))
    assert_equal(false, (p.start("(a,b)!=")))
    assert_equal(false, p.start("(t)!"))
  end

  def test_bools
	p = Dopo.new
	Dopo.clean_scopes
	assert_equal(true,p.start("(T,T,T)&"))
	assert_equal(false,p.start("(T,F)&"))
	assert_equal(true,p.start("(T,T)+"))
	assert_equal(true,p.start("(T,T)*"))
	assert_equal(false,p.start("(F,T,F)*"))
	assert_equal(false,p.start("(T,F)="))
	assert_equal(true,p.start("(T,F)-"))
	assert_equal(false,p.start("(T,T)-"))
	assert_equal(false,p.start("(T,F)="))
	assert_equal(false,p.start("(T,F)->"))
	assert_equal(true,p.start("(T,T)->"))
	assert_equal(false,p.start("(F,F)|"))
	assert_equal(true,p.start("(T,F)|"))
	assert_equal(false,p.start("(T)!"))
  end

  def test_while
    p = Dopo.new
    Dopo.clean_scopes
    #while loops
    p.start("(1,x)@")
    str = "(x,40)<¤
    {
      ((1,x)+,x)@
    }"
    p.start(str)
    assert_equal(40, (p.start("x")), "while loop on outside x counting up")
    str = "(x,-2)>¤
    {
      ((x,1)-,x)@
    }"
    p.start(str)
    assert_equal(-2,(p.start("x")), "while loop on outside x counting down")
    #break before valid list with function in while loop
    p.start("(x)@xr{((1,x)+,x)@}")
    str = "(x,60)!=¤
    {
      (35,x)=?{
        !¤
      }
      ((x)xr,x)@
    }"
    p.start(str)
    assert_equal(35,p.start("x"))
    #break after valid list
    p.start("(x)@xr{((x,1)-,x)@}")
    str = "(x,-40)>=¤
    {
      ((x)xr,x)@
      (-10,x)=?{
        !¤
      }
    }"
    p.start(str)
    assert_equal(-10,p.start("x"))
    str = " (1,c)@

    ([1,3,4,5],e)@
    (0,f)@
    e ¤+ item
    {
      (item,3)=?
      {
        (item,f)+@
        !¤
      }
    }
      f
      T¤
      {
          T¤
          {
            T?
            {
              (10,c)+@
              !¤
            }
          }
          !¤
      }
      f"

    p.start(str)
    assert_equal(3,p.start(str))
  end

  def test_if_statements
    p = Dopo.new
    Dopo.clean_scopes
    p.start("(0,x)@")
    p.start("(x,0)=? {(1,x)@}")
    assert_equal(1, p.start("x"))
    p.start("(0,x)@")
    # one elsif statment is true.
    p.start("(x,1)=?\n{(1,x)@}\n((x,1)+,1)=e? {(2,x)@}")
    assert_equal(2, p.start("x"))
    p.start("(0,x)@")
    # two elsif statements, last one is true an should execute.
    p.start("(x,1)=?\n{((1,x)+,x)@}\n((x,1)+,-1)=e?\n{((2,x)+,x)@}\n((x,1)+,1)=e?\n{(3,x)@}")
    assert_equal(3, p.start("x"))
    p.start("(0,x)@")
    # all if/elsif-statements are true, only first one should execute.
    p.start("(x,0)=?\n{((1,x)+,x)@}\n((x,1)+,1)=e?\n{((2,x)+,x)@}\n((x,1)+,1)=e?\n{((3,x)+,x)@}")
    assert_equal(1, p.start("x"))
    p.start("(0,x)@")
    # runs the else block.
    p.start("(x,-1)=?\n{((1,x)+,x)@}\n((x,1)+,-1)=e?\n{((2,x)+,x)@}\n((x,1)+,-1)=e?\n{((3,x)+,x)@}\ne>{((20,x)+,x)@}")
    assert_equal(20, p.start("x"))

    p.start("(0,x)@")
    # if is true, else dosen't run.
    p.start("(x,0)=?{((1,x)+,x)@}\ne>{((2,x)+,x)@}")
    assert_equal(1, p.start("x"))

    p.start("(0,x)@")
    #if is false, else run.
    p.start("(x,1)=?{((1,x)+,x)@}\ne>{((2,x)+,x)@}")
    assert_equal(2, p.start("x"))

    p.start("(0,x)@")
    # if statment in function, runs else.
    p.start("(x)@foo{(x,-1)=?\n{((1,x)+,x)@}\n((x,1)+,-1)=e?\n{((2,x)+,x)@}\n((x,1)+,-1)=e?\n{((3,x)+,x)@}\ne>{((20,x)+,x)@} x}")
    assert_equal(20, p.start("(x)foo"))
  end

  def test_recursion
    p = Dopo.new
    Dopo.clean_scopes
    str ="(x)@rec{
    (x,5)>?{}
    e>{(((x,1)+)rec,x)@}
    x
    }"
    p.start("(0,i)@")
    p.start(str)
    assert_equal(6,p.start("(i)rec"))
  end

  def test_return
    p = Dopo.new
    Dopo.clean_scopes
    str = "(x)@xr{
    (x,10)=?{x<-}
    76
    }
    "
    p.start(str)
    assert_equal(76,p.start("(6)xr"))
    assert_equal(10,p.start("(10)xr"))

    str ="(x)@rec{
    (x,5)>?{x<-}
    ((x,1)+)rec
    }"
    p.start("(0,i)@")
    p.start(str)
    assert_equal(6,p.start("(i)rec"))
    str = "(x)@foo
    {
        [1,2,3,4] ¤+ item
        {
          (item,2)=?
          {
            item <-
          }
        }
    }
    (3)foo"
    assert_equal(2,p.start(str))

    str = "(x)@foo
    {
        [1,2,3,4] ¤+ item
        {
          T¤
          {
            item <-
          }
        }
    }
    (3)foo"
    assert_equal(1,p.start(str))

    str =
    "
    (1,2)+<-
    2"
    assert_equal(3,p.start(str))

    str = "
    (1,1)=?
    {
      (1,2)+<-
      2
    }
    \"hello\"
    "
    assert_equal(3,p.start(str))
  end

  def test_string_operators

    p = Dopo.new
    Dopo.clean_scopes
    #plus
    str = "(\"HELL\", \"OOOO\")+"
    x = p.start(str)
    assert_equal("HELLOOOO", x)
    #minus
    str = "(\"HELLOTHERE\", \"THERE\")-"
    assert_equal("HELLO", p.start(str))
    str = "(\"HELLOTHERE\", \"THERE\", \"LL\")-"
    assert_equal("HEO", p.start(str))
    #equal
    str = "(\"HELLO\", \"HELLO\")="
    assert_equal(true, p.start(str))

    str = "(\"HELLO\", \"HELL\")="
    assert_equal(false, p.start(str))
    #not equal
    str = "(\"HELLO\", \"HELL\")!="
    assert_equal(true, p.start(str))

    #not equal
    str = "(\"HELLO\", \"HELLO\")!="
    assert_equal(false, p.start(str))
  end

  def test_list
    p = Dopo.new
    Dopo.clean_scopes
    #integers
    str = "([1,2,3],c)@\nc"
    assert_equal([1,2,3], p.start(str))
    #strings
    str = "([\"A\",\"B\",\"C\"],c)@\nc"
    assert_equal(["A","B","C"], p.start(str))
    #mix of datatypes
    str = "([\"A\",T,100],c)@\nc"
    assert_equal(["A",true,100], p.start(str))
    #math addition, function return value and float
    str = "()@foo{(19,x)@\nx}\n([()foo,(5,5)+,3.1415],c)@\nc"
    assert_equal([19, 10, 3.1415], p.start(str))
    #list in lists
    str = "([[1,2,3], [6,8,9], [\"D\"]],c)@\nc"
    assert_equal([[1,2,3], [6,8,9], ["D"]], p.start(str))
  end

  def test_indexing
    p = Dopo.new
    Dopo.clean_scopes
    p.start("([1,2,3],c)@")
    assert_equal(3, p.start("[2]c"))

    p.start("(\"tw5o\",c)@")
    assert_equal("5", p.start("[2]c"))

    p.start("([0]c,a)@")
    assert_equal("t", p.start("a"))

    p.start("(\"123\",c)@")
    p.start("(x)@xr{x}")
    assert_equal("2",p.start("([1]c)xr"))

  end

  def test_for_each
    p = Dopo.new
    Dopo.clean_scopes

    p.start("([2,3,1],c)@")
    assert_equal(1, p.start("(0,ret)@
      c ¤+ wowowo{(wowowo,1)=?{(1,ret)+@}}ret"))

    p.start("([2,3,1],c)@")
    assert_equal(0,p.start("c ¤+ wowowo{wowowo !¤}"))

    str = "([1,2,3,4],l)@
    (0,t)@
    l ¤+ item
    {
        (item,3)>?
        {
            (item,t)+@
            !¤
            (100,t)@
        }
    }
    t"

    assert_equal(4,p.start(str))

    Dopo.clean_scopes

    str =
    "([[1,2],[2,3]],l)@
    (0,t)@
    l ¤+ item
    {
      item ¤+ i
       {
         (i,t)+@
       }
    }
    t
    "
    assert_equal(8,p.start(str))
    Dopo.clean_scopes

  end

  def test_stdlib
    p = Dopo.new
    Dopo.clean_scopes

    p.start("include \"stdlib\"")
    #len
    assert_equal(5, p.start("([1,2,3,4,5])len"))
    assert_equal(11, p.start("(\"Hello World\")len"))
    #last
    assert_equal(5, p.start("([1,23,4,2,5])last"))
    assert_equal("s", p.start("(\"Finders Keepers\")last"))
    #push
    assert_equal([34,56,7], p.start("(34, [56,7])push"))
    assert_equal("hejsan", p.start("(\"hej\",\"san\")push"))
    #del_item
    assert_equal([56,7], p.start("(1, [56,102,7])del_index"))
    assert_equal("hejan", p.start("(3, \"hejsan\")del_index"))
    #get_index
    assert_equal(4, p.start("(17, [56,102,7,1,17])get_index"))
    assert_equal(2, p.start("(\"j\", \"hejsan\")get_index"))
    #del_item
    assert_equal([56,7,102], p.start("(102, [56,102,7,102], F)del_item"))
    assert_equal([56,7], p.start("(102, [56,102,7,102], T)del_item"))
    assert_equal("hejans", p.start("(\"s\", \"hejsans\", F)del_item"))
    assert_equal("hejan", p.start("(\"s\", \"hejsans\", T)del_item"))
    #split
    assert_equal(["hello", "world"], p.start("(\"hello world\", \" \")split"))
    #contains
    assert_equal(true, p.start("(102, [56,102,7,102])contains"))
    assert_equal(false, p.start("(9, [56,102,7,102])contains"))
    assert_equal(true, p.start("( \"a\",\"hejsans\")contains"))
    #first
    assert_equal(56, p.start("([56,102,7,102])first"))
    assert_equal("h", p.start("(\"hejsans\")first"))
    #pop
    assert_equal(102, p.start("(3,[56,102,7,102])pop"))
    assert_equal("s", p.start("(3,\"hejsans\")pop"))
    #append
    assert_equal([56,7,34], p.start("(34, [56,7])append"))
    assert_equal("sanhej", p.start("(\"hej\",\"san\")append"))

  end

  def test_ref_functions
    p = Dopo.new
    Dopo.clean_scopes

    str =
    "(x)@foo*
    {
      (5,x)-@
    }
    (1,y)@
    (y)foo
    y"
    assert_equal(-4, p.start(str))
    Dopo.clean_scopes
    #used to work
    str =
    "(x)@foo*
    {
      (5,y)-@
    }
    (1,y)@
    (y)foo
    y
    "
    assert_equal(1, p.start(str))

    Dopo.clean_scopes
    #not acess to global scope if * is not declared
    str =
    "(x)@foo
    {
      (5,y)-@
    }
    (1,y)@
    (y)foo
    y
    "
    assert_equal(1, p.start(str))

    Dopo.clean_scopes
    #nested funtions
    str =
    "(x)@foo
    {
      (x)@bar
      {
        x
      }
      (x)bar
    }
    (1,y)@
    (y)foo
    y
    "
    assert_equal(1,p.start(str))

    Dopo.clean_scopes
    str =
    "(x)@foo
    {
      (x)@bar
      {
        x
      }
      (x)bar
    }
    (1,y)@
    (y)bar
    y
    "
    assert_raise {p.start(str)}

    Dopo.clean_scopes
    str =
    "(x)@foo
    {
      (1,y)@
      (x)@bar*
      {
        z
      }
      (x)bar
    }
    (1,z)@
    (z)foo
    "
    assert_equal(1, p.start(str))

    Dopo.clean_scopes
    str =
    "(x)@bar
    {
      x
    }
    (x)@foo
    {
      (x)bar
    }
    (1,z)@
    (z)foo
    "
    assert_equal(1,p.start(str))

    Dopo.clean_scopes
    str =
    "
    (x)@foo
    {

      (x)@bar*
      {
        (20,t)+@
      }
      (x)bar
    }
    (1,z)@
    (1,t)@
    (z)foo
    t
    "
    assert_equal(1, p.start(str))

    Dopo.clean_scopes
    str =
    "
    (x)@foo
    {
      (1,y)@
      (x1,y1)@bar*
      {
        (20,y1)+@
        (40,x1)+@
      }
      (x,y)bar
      x
    }
    (1,z)@
    (z)foo
    "
    assert_equal(41, p.start(str))

    Dopo.clean_scopes
    str =
    "
    (x)@foo*
    {
      (10,z)@
      (x1)@bar*
      {
        (40,x1)+@
      }
      (x)bar
    }
    (1,z)@
    (z)foo
    #z#
    "
    assert_equal(41, p.start(str))

    Dopo.clean_scopes
    str =
    "
    (x)@foo
    {
      (1,c)@
      (x)@bar
      {
        c
        x
      }
      (x)@ret
      {
        (x)bar
      }
      #(x)ret#
     (x)bar
    }
    (1,z)@
    (z)foo
    "
    assert_equal(1,p.start(str))
  end

  def test_dictionary
    p = Dopo.new
    Dopo.clean_scopes

    #declare dictionary with all possible datatypes as values for keys
    str =
    "([1 @ \"x\", \"hej\" @ \"y\", 2.2 @ \"z\", [1,2,3,[\"works\" @ \"w\"]] @ \"r\"],r)@
       r"
    assert_equal({"x" => 1, "y" => "hej", "z" => 2.2, "r" => [1,2,3,{"w" => "works"}]}, p.start(str))
    #testing get_value function
    str =
    "[\"x\"]r"
    assert_equal(1,p.start(str))
    str =
    "[\"r\"] r"
    assert_equal([1,2,3,{"w" => "works"}],p.start(str))
    #testing add_pair function
    str =
    "([90 @ \"t\", 100 @ \"j\"], r)+@
      ([500 @ \"d\"],new_hash)@
     (new_hash, r)+@
    r"
    assert_equal({"x" => 1, "y" => "hej", "z" => 2.2, "r" => [1,2,3,{"w" => "works"}], "t" => 90, "j" => 100, "d" => 500}, p.start(str))
    #testing delete_pair
    str =
    "(\"z\", r)-@
    r"
    assert_equal({"x" => 1, "y" => "hej", "r" => [1,2,3,{"w" => "works"}], "t" => 90, "j" => 100, "d" => 500}, p.start(str))
  end

  def test_continue

    p = Dopo.new
    Dopo.clean_scopes

    str = "
    (0,c)@
    [1,2,3] ¤+ item
    {
      (item,2)=?
      {
        (item,2)=?
        {
          ¤+
          (1,c)+@
        }
      }
      (1,c)+@
    }
    c"

    assert_equal(2, p.start(str))

    str = "
    (0,c)@
    (0,i)@
    (c,5)<¤
    {
      (c,3)<?
      {
        (1,c)+@
        ¤+
        (1,c)+@
      }
      (1,c)+@
      !¤
    }
    c"

    assert_equal(4, p.start(str))


    str = "
    (0,c)@
    (1,1)=?
    {
      ¤+
      (19,c)+@
    }
    c"

    assert_equal(0, p.start(str))
  end

#   def test_get_function
#     p = Dopo.new
#     Dopo.clean_scopes

#     #  str = "()g"ret_val == nil
#     #  #type in 100
#     #  assert_equal(100, p.start(str))
#     #  str = "()g"
#     #  #type in 3.1415
#     #  assert_equal(3.1415, p.start(str))
#     #  str = "()g"
#     #  #type in "hello"
#     #  assert_equal("\"hello\"", p.start(str))
#     #  str = "()g"
#     #  #type in "hello"
#     #  assert_equal("\"hello\"", p.start(str))
#     #  str = "()g"
#     #  #type in T
#     #  assert_equal(true, p.start(str))
#     #   str = "()g"
#     #  #type in F
#     #  assert_equal(false, p.start(str))

#     #str = "()g"
#     #type in [1,2,3,4,5]
#    # assert_equal([1,2,3,4,5], p.start(str))
#     #str = "()g"
#     #type in ["hej", 1, 1.2, [1,2,3]]
#     #assert_equal(["hej", 1, 1.2, [1,2,3]], p.start(str))
#     #str = "()g"
#     #type in [1 @ a, "hej" @ b, T @ c]
#     #assert_equal({"a" => 1, "b" => "hej", "c" => true}, p.start(str))
#     #str = "(1,x)@
#     #       (x)g
#     #        x"
#     #type in [1 @ a, "hej" @ b, T @ c]
#     #assert_equal({"a" => 1, "b" => "hej", "c" => true}, p.start(str))



#   end
end
