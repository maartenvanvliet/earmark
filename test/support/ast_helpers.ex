defmodule Support.AstHelpers do
  
  @default %{}
  def ast_from_md(md) do
    with {:ok, ast, []} <- Earmark.as_ast(md), do: ast
  end

  def p(content, atts \\ [])
  def p(content, atts) when is_binary(content),
    do: {"p", atts, [content], @default}
  def p(content, atts),
    do: {"p", atts, content, @default}

  def void_tag(tag, atts \\ []) do
    {to_string(tag), atts, [], @default}
  end
end
