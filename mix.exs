defmodule Mix.Tasks.Readme do
  use Mix.Task

  @shortdoc "Build README.md by including module docs"

  @moduledoc """
  Imagine a README.md that contains

      # Overview

      <!-- moduledoc: Earmark -->

      # Typical calling sequence

      <!-- doc: Earmark.to_html

  Run this task, and the README will be updated with the appropriate
  documentation. Markers are also added, so running it again
  will update the doc in place.
  """

  def run([]) do
    File.read!("README.md")
    |> remove_old_doc
    |> add_updated_doc
    |> write_back
  end

  @new_doc ~R/\n (\s* <!-- \s+ (module)?doc: \s* (\S+?) \s+ -->).*\n/x

  @existing_doc ~R/(\n \s* <!-- \s+ (module)?doc: \s* (\S+?) \s+ -->).*\n
                   (?: .*?\n )+?
                   \s* <!-- \s end\2doc: \s+ \3 \s+ --> \s*?
  /x

  defp remove_old_doc(readme) do
    Regex.replace(@existing_doc, readme, fn (_, hdr, _, _) -> hdr end)
  end

  defp add_updated_doc(readme) do
    Regex.replace(@new_doc, readme, fn (_, hdr, type, name) -> 
      "\n" <> hdr <> "\n" <> 
      doc_for(type, name) <> 
      Regex.replace(~r/!-- /, hdr, "!-- end") <> "\n"
    end)
  end

  defp doc_for("module", name) do
    module = String.to_atom("Elixir." <> name)

    docs = case Code.ensure_loaded(module) do
      {:module, _} ->
        if function_exported?(module, :__info__, 1) do
          case Code.get_docs(module, :moduledoc) do
            {_, docs} when is_binary(docs) ->
              docs
            _ -> nil
          end
        else
          nil
        end
      _ -> nil
    end

    docs # || "No module documentation available for #{name}\n"
  end

  defp doc_for("", name) do
    names = String.split(name, ".")
    [ func | modules ] = Enum.reverse(names)
    module = Enum.reverse(modules) |> Enum.join(".")
    module = String.to_atom("Elixir." <> module)
    func   = String.to_atom(func)

    markdown = case Code.ensure_loaded(module) do
      {:module, _} ->
        if function_exported?(module, :__info__, 1) do
          docs = Code.get_docs(module, :docs)
          doc = Enum.find(docs, fn ({{fun, _}, _line, _kind, _args, _doc}) ->
            fun == func
          end)
          {_fun, _line, _kind, _args, documentation} = doc
          documentation
        else
          nil
        end
      _ -> nil
    end

    markdown || "No function documentation available for #{name}\n"
  end

                                                      
  defp write_back(readme) do
    IO.puts :stderr,
      (case File.write("README.md", readme) do
        :ok -> "README.md updated"
        {:error, reason} ->
           "README.ms: #{:file.explain_error(reason)}"
      end)
  end
end


defmodule Earmark.Mixfile do
  use Mix.Project

  def project do
    [app: :earmark,
     version: "0.0.1",
     elixir: "~> 0.14",
     escript: escript_config,
     deps: deps]
  end

  def application do
    [applications: []]
  end

  defp deps do
    []
  end

  defp escript_config do
    [ main_module: Earmark.CLI ]
  end
end
