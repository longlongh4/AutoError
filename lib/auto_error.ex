defmodule AutoError do
  @error_msg "AutoError can only support processing {:ok, term} or {:error, term} with function"

  defp unpipe(expr), do: unpipe(expr, []) |> Enum.reverse()
  defp unpipe({:~>, _, [left, right]}, acc), do: unpipe(right, unpipe({:chain, left}, acc))
  defp unpipe({:~>>, _, [left, right]}, acc), do: unpipe(right, unpipe({:functor, left}, acc))
  defp unpipe(other, acc), do: [other | acc]

  def chain({:error, _} = error, _), do: error

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

  def functor({:error, _} = error, _), do: error

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

  defmacro left ~> right, do: unpipe({:~>, [], [left, right]}) |> reduce_pipe()
  defmacro left ~>> right, do: unpipe({:~>>, [], [left, right]}) |> reduce_pipe()

  defp reduce_pipe([h | t]) do
    Enum.reduce(t, h, fn expr, acc ->
      pipe(acc, expr)
    end)
  end
end
