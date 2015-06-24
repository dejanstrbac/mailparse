defmodule MailParse.MailReader do

  def read(path) do
    try do
      {:ok, mail} = File.read(path)
      {:ok, :mimemail.decode(mail) |> parse_mail_data()}
    rescue
      _ -> :error
    end
  end


  defp parse_mail_data({"multipart", _, headers, _, bodies}) do
    parse_mail_bodies(bodies, %{})
    |> Map.merge parse_headers(headers)
  end


  defp parse_mail_data({"text", content_subtype_name, headers, _, body})
    when content_subtype_name == "plain" or content_subtype_name == "html" do

    meta_data = parse_headers(headers)
    case content_subtype_name do
      "html"  -> %{ :html => body }
      "plain" -> %{ :text => body }
    end
    |> Map.merge(meta_data)
  end


  defp parse_mail_data({_, _, _, meta, body}) do
    mapped_headers = parse_attachment_headers(meta, %{})

    disposition = Map.fetch(mapped_headers, :disposition)
    filename    = Map.fetch(mapped_headers, :filename)

    case {disposition, filename} do
      {{:ok, _},{:ok, name}} -> %{:attachments => [{ name, body }]}
      _ -> %{}
    end
  end


  defp parse_attachment_headers([header | remaining_headers], collector) do
    phed = parse_header(header, collector)
    new_collected = Map.merge(collector, phed)
    parse_attachment_headers(remaining_headers, new_collected)
  end

  defp parse_attachment_headers([], collected), do: collected


  defp parse_header({"disposition", disposition}, _), do: %{:disposition => disposition}

  defp parse_header({"content-type-params", params}, _) do
    filename = :proplists.get_value("name", params)
    case filename do
      :undefined -> %{}
      _ -> %{:filename => filename}
    end
  end

  defp parse_header(_, _), do: %{}


  defp parse_headers(mail_meta) do
    fields = ["From", "To", "Cc", "Bcc", "Subject", "Date", "Delivered-To", "Message-ID"]
    Enum.reduce fields, %{}, fn(field, data)->
      case :proplists.get_value(field, mail_meta) do
        :undefined -> data
        value ->
          formatted_value = format_field_value(field, value)
          Map.put(data, String.to_atom(String.downcase(field)), formatted_value)
      end
    end
  end



  defp parse_mail_bodies([], collected), do: collected

  defp parse_mail_bodies([body | bodies], collected) do
    conflict_res = fn(_, v1, v2) ->
      if is_map(v1) and is_map(v2) do
        Map.merge(v1, v2)
      else
        if is_list(v1) and is_list(v2) do
          v1 ++ v2
        else
          v2
        end
      end
    end

    new_collected = Map.merge(collected, parse_mail_data(body), conflict_res)
    parse_mail_bodies(bodies, new_collected)
  end




  defp format_field_value("To", value) do
    parse_participants(value)
  end

  defp format_field_value("From", value) do
    parse_participant(value)
  end

  defp format_field_value("Cc", value) do
    parse_participants(value)
  end

  defp format_field_value(_field, value) do
    value
  end


  defp parse_participants(participants) when is_binary(participants) do
    participant_list = String.split(participants, ",")
    parse_participants(participant_list, [])
  end

  defp parse_participants([], parsed) do
    parsed
  end

  defp parse_participants([participant | participants], parsed) do
    participant = String.strip(participant)
    new_parsed = [ parse_participant(participant) | parsed ]
    parse_participants(participants, new_parsed)
  end


  defp parse_participant(participant) do
    parts = String.split(participant, "<")
    case length(parts) do
      1 -> %{email: participant}
      2 ->
        email = List.last(parts)
        |> String.split(">")
        |> hd
        |> String.strip()
        %{ name:  hd(parts) |> String.strip |> String.strip(?"),
           email: email}
    end
  end


end