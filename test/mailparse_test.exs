defmodule MailParseTest do
  use ExUnit.Case

  test "one PGP attachment" do
    {:ok, mail} = File.read("test/data/email1.eml")
    {:ok, parsed_mail} = MailParse.parse_mail(mail)
    [{"msg.asc", attachment}] = parsed_mail.attachments
    assert byte_size(attachment) == 95196
    assert parsed_mail.from.email == "ojos@gmx.ch"
    assert hd(parsed_mail.to).email == "me@dejanstrbac.com"
    assert parsed_mail.subject == "Suggestion for pricing..."
  end


  test "bcc and cc headers" do
    {:ok, mail} = File.read("test/data/email2.eml")
    assert MailParse.parse_mail(mail) == {:ok,
      %{bcc: "dejan@advite.ch",
        cc: [%{email: "me@dejanstrbac.com", name: "Dejan Strbac"}],
        date: "Sun, 21 Jun 2015 09:28:43 +0200",
        from: %{email: "dejan.strbac@gmail.com", name: "Dejan Strbac"},
        subject: "Hello subject", text: "Hello body\r\n",
        to: [%{email: "dejan.strbac@me.com", name: "Дејан Штрбац"}]}}
  end


  test "normal HTML mail" do
    {:ok, mail} = File.read("test/data/email3.eml")
    {:ok, parsed_mail} = MailParse.parse_mail(mail)
    assert %{email: "tl@ifj.ch", name: "IFJ Newsletter"} == parsed_mail.from
    assert [%{email: "dejan.strbac@gmail.com", name: "Dejan"}] == parsed_mail.to
    assert parsed_mail.subject == "Fünf Tipps für entspanntes Arbeiten von unterwegs"
    assert Map.has_key?(parsed_mail, :html)
    assert Map.has_key?(parsed_mail, :text)
  end


  test "multiple attachments" do
    {:ok, mail} = File.read("test/data/email4.eml")
    {:ok, parsed_mail} = MailParse.parse_mail(mail)
    [{"Thinking in Erlang.pdf", first_attachment},
     {"De%CC%81claration%20d'accident_LAMal_LCA.pdf", second_attachment}] = parsed_mail.attachments

    assert byte_size(first_attachment) == 220042
    assert byte_size(second_attachment) == 83899

    assert parsed_mail.from == %{email: "dejan.strbac@gmail.com", name: "Dejan Strbac"}
    assert hd(parsed_mail.to) == %{email: "me@dejanstrbac.com", name: "Dejan Strbac"}
    assert parsed_mail.subject == "Fwd: lamal"
  end


  test "larger attachment" do
    {:ok, mail} = File.read("test/data/email5.eml")
    {:ok, parsed_mail} = MailParse.parse_mail(mail)
    [{"Cat. Gullà n°102-2015.pdf", attachment}] = parsed_mail.attachments

    assert byte_size(attachment) == 1254072

    assert parsed_mail.from.email == "info@libreriadellarocca.com"
    assert hd(parsed_mail.to).email == "info@libreriadellarocca.com"
    assert parsed_mail.subject == "Catalogo Libreria Gullà Carmen Rosetta"
    assert parsed_mail."delivered-to" == "dejan.strbac@gmail.com"
  end

end
