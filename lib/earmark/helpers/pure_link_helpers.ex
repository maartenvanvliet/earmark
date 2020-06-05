defmodule Earmark.Helpers.PureLinkHelpers do
  @moduledoc false

  import Earmark.Helpers.StringHelpers, only: [behead: 2]
  import Earmark.Helpers.AstHelpers, only: [render_link: 2]

  @pure_link_rgx ~r{\A\s*(https?://\S+\b)}u
  def convert_pure_link(src) do
    case Regex.run(@pure_link_rgx, src) do
      [ match, link_text ] ->
        out = render_link(link_text, link_text)
        {out, String.length(match)}
        _ -> nil
    end
  end


  def parse_pure_link(link_text, match) do
    IO.inspect {link_text, match}
    link_text1 = String.trim_trailing(")")
    pending_closing_parens = behead(link_text, link_text1) 
    {link_text2, removed} = _remove_superflous_pending_closing_parens(link_text1, pending_closing_parens)
    {link_text2, String.length(match) - removed}
  end

  defp _count_parens(link_text_graphemes) do
    Enum.count(link_text_graphemes, &(&1=="(")) -
    Enum.count(link_text_graphemes, &(&1==")"))
  end

  defp _remove_superflous_pending_closing_parens(link_text, pending_paren)
  defp _remove_superflous_pending_closing_parens(link_text, ""), do: {link_text, 0}
  defp _remove_superflous_pending_closing_parens(link_text, pending_paren) do
    opening_paren_count =
      link_text
      |> String.graphemes
      |> _count_parens()
    if opening_paren_count < 1 do
      {link_text, String.length(pending_paren)}
    else
      add = String.slice(pending_paren, 0..opening_paren_count-1) 
      {link_text <> add, String.length(pending_paren) - String.length(add)}
    end
  end
end
