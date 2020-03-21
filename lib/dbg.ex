defmodule Dbg do
  
  # TODO: Remove me
  def dbg(object, label, level \\ 10 ) do
    if _level(level, System.get_env("DEBUG")) do
      IO.inspect(object, label: label)
    end
    object
  end

  defp _level(given, requested)
  defp _level(_, nil), do: false
  defp _level(given, requested) do
    {requested_dbg_level, _} = Integer.parse(requested)
    requested >= given
  end
end
