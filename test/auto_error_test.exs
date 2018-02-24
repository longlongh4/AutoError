defmodule AutoErrorTest do
  use ExUnit.Case
  import AutoError

  doctest AutoError

  def add_one(x), do: x + 1
  def add_one_ok(x), do: {:ok, x + 1}
  def fail_test(_), do: {:error, "fail"}
  def exception_test(_), do: raise("crased, haha")

  test "test chain" do
    assert 1 == {:ok, 1} ~> (fn x -> x end).()
    assert 2 == {:ok, 1} ~> add_one()
    assert 2 == {:ok, 1} ~> add_one
    assert {:ok, 3} == {:ok, 1} ~> add_one_ok ~> add_one_ok
    assert 3 == {:ok, 1} ~> add_one_ok ~> add_one
    assert {:error, 1} = {:error, 1} ~> add_one
    assert {:error, "fail"} == {:ok, 1} ~> fail_test() ~> add_one()

    assert {:error, %RuntimeError{message: "crased, haha"}} ==
             {:ok, 1} ~> exception_test ~> add_one()
  end

  test "test functor" do
    assert {:ok, 3} == {:ok, 1} ~>> add_one() ~>> add_one()
  end

  test "test functor and chain" do
    assert 5 == {:ok, 1} ~>> add_one() ~>> add_one() ~> add_one() |> add_one()
  end

  test "test format error" do
    assert_raise(
      RuntimeError,
      "AutoError can only support processing {:ok, any()} or {:error, any()} with function",
      fn -> 1 ~> add_one() end
    )
  end

  test "test nested condition" do
    assert {:error, "fail"} == 1 |> add_one_ok ~> fail_test() ~> add_one()

    assert {:ok, 5} ==
             0
             |> wake_up()
             ~>> wear_trousers()
             ~> buy_goods()
             ~> cook()

    assert {:error, "alarm clock doesn't ring"} ==
             0
             |> wake_up_fail()
             ~>> wear_trousers()
             ~> buy_goods()
             ~> cook()
  end

  defp wake_up(value), do: {:ok, value + 1}
  defp wake_up_fail(_), do: {:error, "alarm clock doesn't ring"}
  defp wear_trousers(value), do: value + 1

  defmodule TestModule do
    def inner_test(x), do: {:ok, x + 1}
  end

  defp buy_goods(value) do
    value
    |> (fn x -> {:ok, x + 1} end).()
    ~> TestModule.inner_test()
  end

  defp cook(value), do: {:ok, value + 1}
end
