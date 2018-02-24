defmodule AutoErrorTest do
  use ExUnit.Case
  import AutoError

  def add_one(x), do: x + 1
  def fail_test(_), do: {:error, "fail"}
  def exception_test(_), do: raise("crased, haha")

  test "test chain" do
    assert 1 == {:ok, 1} ~> (fn x -> x end).()
    assert 2 == {:ok, 1} ~> add_one()
    assert 2 == {:ok, 1} ~> add_one
    assert {:error, 1} = {:error, 1} ~> add_one
    assert {:error, "fail"} == {:ok, 1} ~> fail_test() ~> add_one()

    assert {:error, %RuntimeError{message: "crased, haha"}} ==
             {:ok, 1} ~> exception_test ~> add_one()
  end

  test "test functor" do
  end
end
