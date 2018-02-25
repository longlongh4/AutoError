defmodule AutoError do
  @moduledoc ~S"""
  ***AutoError*** helps you to pipe between functions returning `{:ok, _}` or `{:error, _}` easily.

  ## Usage
  ```elixir
  import AutoError
  ```

  AutoError is easy to use, it provides two new operators `~>` and `~>>`, `~>` is called a **chain** and `~>>` is called a **functor**, 
  don't need to concern about the new concept. Let's learn by some examples.

  ## Examples

      iex> {:ok, 1} ~>> fn x -> x + 1 end.()
      {:ok, 2}

      iex> {:error, 1} ~>> fn x -> x + 1 end.()
      {:error, 1}

      iex> {:ok, 1} ~> fn x -> x + 1 end.()
      2

      iex> {:error, 1} ~> fn x -> x + 1 end.()
      {:error, 1}

  In this example, we pipe a value to an anonymous function which will add the value by one, if you pass it a value with `:ok`, it will add one, but if you pass `:error`,
  it will not call the anonymous function and just return the original value.

  Let's explain in detail, the basic pattern is like `parameter ~> func`.
  
  `~>` is a macro, when `parameter` is kind of `{:ok, value}`, it will extract value and pass it to 
  `func` like `func(value)`, when `parameter` is kind of `{:error, value}`, `~>` will not call `func` and just return the `{:error, value}` without modification.

  `~>>` is also a macro, when `parameter` is kind of `{:error, value}`, `~>>` behaves the same as `~>`, when `parameter` is kind of `{:ok, value}`, it will call `func` 
  as `~>` does, but in the end, it will package the value into a new `{:ok, value}` format, then you can pipe the result to another function.

  Seems interesting, but how this can help us to simplify error handling? Let's see a more complex example.
      
      iex> {:ok, 1} ~>> (&(&1 + 1)).() ~>> (&(&1 + 1)).() ~>> (&(&1 + 1)).()
      {:ok, 4}

      iex> {:ok, 1} ~> (&({:error, "Whoops:#{&1}"})).() ~>> (&(&1 + 1)).() ~> (&(&1 + 1)).()
      {:error, "Whoops:1"}

      iex> {:ok, 1} ~>> (&(&1 + 1)).() ~> (&({:error, "Whoops:#{&1}"})).() ~>> 
      ...> (&(&1 + 1)).() ~> (&(&1 + 1)).()
      {:error, "Whoops:2"}

      iex> {:ok, 1} ~>> (&(&1 + 1)).() |> IO.inspect() ~> (&({:error, "Whoops:#{&1}"})).() ~>> 
      ...> (&(&1 + 1)).() |> IO.inspect() ~>> (&(&1 + 1)).()
      {:ok, 2}
      {:error, "Whoops:2"}
      {:error, "Whoops:2"}

  ## Why using AutoError

  There will be a lot of errors in a production environment, which we need to handle carefully. Even though
  we can handle error processing with Case, Cond, [Railway Oriented Programming](https://medium.com/elixirlabs/railway-oriented-programming-in-elixir-with-pattern-matching-on-function-level-and-pipelining-e53972cede98)
  or [With Syntax](https://hexdocs.pm/elixir/Kernel.SpecialForms.html#with/1).
  But they all bring some boilerplate code, that will confuse our eyes when we want to check the workflow or leave some errors unhandled by mistake.

  To simplify error handling in Elixir, we can borrow some ideas from [Monad](https://en.wikipedia.org/wiki/Monad_(functional_programming)). There is already
  a Monad library in Elixir called [WitchCraft](https://github.com/expede/witchcraft), but there are some disadvantages when using it.

  1. This library has many dependencies which will add compiling time and code complexity.
  2. It uses `%Left{}` and `%Right{}` to handle error, which conflicts with the `{:ok, _}` and `{:error, _}` idiom in Elixir ecosystem.
  3. Doesn't support passing first function's result as next function's first argument just as what `|>` does, 
      so you must write `%Algae.Either.Right{right: 1} >>> fn x -> IO.inspect(x) end` instead of using `{:ok, 1} ~> IO.inspect()`, 
  4. Bring in some warnings when using with Credo.  
  5. Doesn't work well with `mix format`, actually I think this is a bug in `mix format`, because it can format both `~>` and `~>>`, 
      but can't recognize `>>>` which is also a [valid operator](https://github.com/elixir-lang/elixir/blob/master/lib/elixir/pages/Operators.md) in Elixir.
  6. Hard to learn, ***WitchCraft*** supports more concept in Monad, and it even brings in a new `TypeClass`, if you want to use a lot of Monad related operations, 
      this is great, but if you just want to solve error handling, this seems overhead, you need to learn a lot before you start. 
  
  ## Thanks

  Special thanks to [Falood](https://github.com/falood), he helps me a lot when designing this library.
      
  """

  @error_msg "AutoError can only support processing {:ok, any()} or {:error, any()} with function"

  defp unpipe(expr), do: unpipe(expr, []) |> Enum.reverse()
  defp unpipe({:~>, _, [left, right]}, acc), do: unpipe(right, unpipe({:chain, left}, acc))
  defp unpipe({:~>>, _, [left, right]}, acc), do: unpipe(right, unpipe({:functor, left}, acc))
  defp unpipe(other, acc), do: [other | acc]

  @doc """
  chain function
  """
  @spec chain({:ok, any()} | {:error, any()}, fun()) :: any()
  def chain({:error, _} = value, _), do: value

  def chain({:ok, value}, func) do
    func.(value)
  rescue
    e ->
      {:error, e}
  catch
    e ->
      {:error, e}
  end

  def chain(_, _), do: raise(@error_msg)

  @doc """
  functor function
  """
  @spec functor({:ok, any()} | {:error, any()}, fun()) :: {:ok, any()} | {:error, any()}
  def functor({:error, _} = value, _), do: value

  def functor({:ok, value}, func) do
    {:ok, func.(value)}
  rescue
    e ->
      {:error, e}
  catch
    e ->
      {:error, e}
  end

  def functor(_, _), do: raise(@error_msg)

  defp pipe(left, {func, line, nil}) do
    pipe(left, {func, line, []})
  end

  defp pipe({:chain, left}, {func, _, args}) do
    quote do
      AutoError.chain(unquote(left), fn value -> unquote(func)(value, unquote_splicing(args)) end)
    end
  end

  defp pipe({:functor, left}, {func, _, args}) do
    quote do
      AutoError.functor(unquote(left), fn value ->
        unquote(func)(value, unquote_splicing(args))
      end)
    end
  end

  @doc """
  ~>
  """
  defmacro left ~> right, do: unpipe({:~>, [], [left, right]}) |> reduce_pipe()
  
  @doc """
  ~>>
  """
  defmacro left ~>> right, do: unpipe({:~>>, [], [left, right]}) |> reduce_pipe()

  defp reduce_pipe([h | t]) do
    Enum.reduce(t, h, fn expr, acc ->
      pipe(acc, expr)
    end)
  end
end
