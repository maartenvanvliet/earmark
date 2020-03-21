defmodule Earmark.Context do

  @moduledoc false
  use Earmark.Types
  import Earmark.Helpers

  @type t :: %__MODULE__{
          options: Earmark.Options.t(),
          links: map(),
          rules: Keyword.t() | nil,
          footnotes: map(),
          value: String.t() | [String.t()]
        }

  defstruct options: %Earmark.Options{},
            links: Map.new(),
            rules: nil,
            footnotes: Map.new(),
            unused_fns: MapSet.new(),
            value: []

  ##############################################################################
  # Handle adding option specific rules and processors                         #
  ##############################################################################

  defp noop(text), do: text

  # Convenience method to append to the value list
  # def append(%__MODULE__{value: value} = ctx, prep), do: %{ctx | value: [value | prep]}

  def modify_value(%__MODULE__{value: value}=context, fun) do
    # IO.inspect(value, label: ">>>modify_value")
    nv = fun.(value) #|> IO.inspect(label: "<<<modify_value")
    unless is_list(nv), do: raise "Not a list!!!\n#{inspect nv}"
    %{context | value: nv}
  end


  # Convenience method to prepend to the value list
  def prepend(context, ast, messages \\ [])
  def prepend(%__MODULE__{value: value} = ctx, prep, messages) do
    # TODO: Remove me
    unless is_list(value), do: raise "Not a list!!!\n#{inspect value}"
    options1 = %{ctx.options | messages: Enum.uniq(ctx.options.messages ++ messages)}
    _prepend(%{ctx|options: options1}, prep)
  end

  defp _prepend(ctxt, []), do: ctxt
  defp _prepend(%{value: value}=ctxt, {:comment, _}=ct), do: %{ctxt|value: [ct|value]}
  defp _prepend(%{value: value}=ctxt, tuple) when is_tuple(tuple) do
    %{ctxt|value: [tuple|value] |> List.flatten}
  end
  defp _prepend(%{value: value}=ctxt, string) when is_binary(string), do: %{ctxt|value: [string|value] |> List.flatten}
  defp _prepend(%{value: value}=ctxt, list) when is_list(list), do: %{ctxt|value: List.flatten(list ++ value)}

  @doc """
  Convenience method to prepend to the value list
  """
  def set_value(%__MODULE__{} = ctx, value) do
    # TODO: Remove me
    unless is_list(value), do: raise "Not a list!!!\n#{inspect value}"
    %{ctx | value: value}
  end

  def clear_value(%__MODULE__{} = ctx), do: %{ctx | value: []}
  @doc """
  Convenience method to get a context with cleared value and messages
  """
  def clear(%__MODULE__{} = ctx) do
    with empty_value <- set_value(ctx, []) do
      %{empty_value | options: %{empty_value.options | messages: []}}
    end
  end

  @doc false
  # this is called by the command line processor to update
  # the inline-specific rules in light of any options
  def update_context(footnotes) do
    update_context(%Earmark.Context{}, footnotes)
  end
  def update_context(context = %Earmark.Context{options: options}, footnotes) do
    context = %{context | rules: rules_for(options)}
    context1 = _mk_footnotes(context, footnotes)

    if options.smartypants do
      put_in(context1.options.do_smartypants, &_smartypants/1)
    else
      put_in(context1.options.do_smartypants, &noop/1)
    end
  end

  @doc """
  When a footnote is rendered remove its id from the unused_fns so that there will be no warning at the end
  """
  def use_footnote(context, fn_id), do: %{context|unused_fns: MapSet.delete(context.unused_fns, fn_id)}

  #                 ( "[" .*? "]"n or anything w/o {"[", "]"}* or "]" ) *
  @link_text ~S{(?:\[[^]]*\]|[^][]|\])*}
  # "
  @href ~S{\s*<?(.*?)>?(?:\s+['"](.*?)['"])?\s*}

  @code ~r{^
 (`+)		# $1 = Opening run of `
 (.+?)		# $2 = The code block
 (?<!`)
 \1			# Matching closer
 (?!`)
    }xs

  defp basic_rules do
    [
      escape: ~r{^\\([\\`*\{\}\[\]()\#+\-.!_>])},
      # noop
      url: ~r{\z\A},
      tag: ~r{
          ^<!--[\s\S]*?--> |
          ^<\/?\w+(?: "[^"<]*" | # < inside an attribute is illegal, luckily
          '[^'<]*' |
          [^'"<>])*?>}x,
      inline_ial: ~r<^\s*\{:\s*(.*?)\s*}>,
      link: ~r{^!?\[(#{@link_text})\]\(#{@href}\)},
      reflink: ~r{^!?\[(#{@link_text})\]\s*\[([^]]*)\]},
      nolink: ~r{^!?\[((?:\[[^]]*\]|[^][])*)\]},
      strong: ~r{^__([\s\S]+?)__(?!_)|^\*\*([\s\S]+?)\*\*(?!\*)},
      em: ~r{^\b_((?:__|[\s\S])+?)_\b|^\*((?:\*\*|[\s\S])+?)\*(?!\*)},
      code: @code,
      br: ~r<^ {2,}\n(?!\s*$)>,
      text: ~r<^[\s\S]+?(?=[\\<!\[_*`]| {2,}\n|$)>,
      # noop
      strikethrough: ~r{\z\A}
    ]
  end

  defp rules_for(options) do
    rule_updates =
      if options.gfm do
        rules = [
          escape: ~r{^\\([\\`*\{\}\[\]()\#+\-.!_>~|])},
          url: ~r{^(https?:\/\/[^\s<]+[^<.,:;\"\')\]\s])},
          strikethrough: ~r{^~~(?=\S)([\s\S]*?\S)~~},
          text: ~r{^[\s\S]+?(?=[\\<!\[_*`~]|https?://| \{2,\}\n|$)}
        ]

        if options.breaks do
          break_updates = [
            br: ~r{^ *\n(?!\s*$)},
            text: ~r{^[\s\S]+?(?=[\\<!\[_*`~]|https?://| *\n|$)}
          ]

          Keyword.merge(rules, break_updates)
        else
          rules
        end
      else
        if options.pedantic do
          [
            strong: ~r{^__(?=\S)([\s\S]*?\S)__(?!_)|^\*\*(?=\S)([\s\S]*?\S)\*\*(?!\*)},
            em: ~r{^_(?=\S)([\s\S]*?\S)_(?!_)|^\*(?=\S)([\s\S]*?\S)\*(?!\*)}
          ]
        else
          []
        end
      end

    footnote = if options.footnotes, do: ~r{^\[\^(#{@link_text})\]}, else: ~r{\z\A}
    rule_updates = Keyword.merge(rule_updates, footnote: footnote)

    Keyword.merge(basic_rules(), rule_updates)
    |> Enum.into(%{})
  end

  # Smartypants transformations convert quotes to the appropriate curly
  # variants, and -- and ... to – and …
  defp _smartypants(text) do
    text
    |> replace(~r{--}, "—")
    |> replace(~r{(^|[-—/\(\[\{"”“\s])'}, "\\1‘")
    |> replace(~r{\'}, "’")
    |> replace(~r{(^|[-—/\(\[\{‘\s])\"}, "\\1“")
    |> replace(~r{"}, "”")
    |> replace(~r{\.\.\.}, "…")
  end

  defp _mk_footnotes(context, footnotes) do
    %{context | footnotes: _mk_footnotes_map(footnotes), unused_fns: _mk_footnotes_set(footnotes)}
  end
  defp _mk_footnotes_map(footnotes) do
    footnotes
    |> Enum.reduce(%{}, &Map.put(&2, &1.id, &1))
  end
  defp _mk_footnotes_set(footnotes) do
    footnotes
    |> Enum.reduce(MapSet.new, &MapSet.put(&2, &1.id))
  end
end

# SPDX-License-Identifier: Apache-2.0
