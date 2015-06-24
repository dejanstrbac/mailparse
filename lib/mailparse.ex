defmodule MailParse do

  defmacro __using__(_) do
    quote do
      alias MailParse.MailReader
    end
  end

end
