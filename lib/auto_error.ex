defmodule AutoError do
  @error_msg "AutoError can only support processing {:ok, term} or {:error, term} with function"

  defp unpipe(expr) do
    unpipe(expr, []) |> Enum.reverse()
  end

  defp unpipe({:~>, _, [left, right]}, acc) do
    unpipe(right, unpipe(left, acc))
  end

  defp unpipe(other, acc) do
    [other | acc]
  end

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

  defp pipe(left, {func, line, nil}) do
    pipe(left, {func, line, []})
  end

  defp pipe(left, {func, _, args}) do
    quote do
      AutoError.chain(unquote(left), fn value -> unquote(func)(value, unquote_splicing(args)) end)
    end
  end

  defmacro left ~> right do
    [h | t] = unpipe({:~>, [], [left, right]})

    Enum.reduce(t, h, fn expr, acc ->
      pipe(acc, expr)
    end)
  end

  # Chain
  # defmacro {:ok, value} ~> {f, metadata, nil}, do: {f, metadata, [value]}
  # defmacro {:ok, value} ~> {f, metadata, args}, do: {f, metadata, [value | args]}
  # defmacro {:error, err} ~> {_f, _metadata, _args}, do: {:error, err}
  # defmacro _ ~> _, do: quote(do: raise(unquote(@error_msg)))

  # # Chain
  # defmacro {:ok, value} ~> {f, metadata, nil}, do: {f, metadata, [value]}
  # defmacro {:ok, value} ~> {f, metadata, args}, do: {f, metadata, [value | args]}
  # defmacro {:error, err} ~> {_f, _metadata, _args}, do: {:error, err}
  # defmacro _ ~> _, do: quote(do: raise(unquote(@error_msg)))

  # # Functor
  # defmacro {:ok, value} ~>> {f, metadata, args}, do: {:ok, {f, metadata, [value]}}
  # defmacro {:ok, value} ~>> {f, metadata, args}, do: {:ok, {f, metadata, [value | args]}}
  # defmacro {:error, err} ~>> {_f, _metadata, _args}, do: {:error, err}
  # defmacro _ ~>> __, do: quote(do: raise(unquote(@error_msg)))
end
