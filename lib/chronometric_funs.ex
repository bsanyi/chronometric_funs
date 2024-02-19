defmodule ChronometricFuns do
  @moduledoc File.read!("README.md")

  def apply(module, function, args) do
    time = Process.get(__MODULE__) || DateTime.to_unix(DateTime.utc_now())
    Process.put(__MODULE__, time)
    Kernel.apply(module, function, [time | args])
  end

  defmacro __using__(_) do
    m = __MODULE__

    quote do
      require unquote(m)
      import unquote(m)
      @clauses %{}
      @before_compile unquote(m)
    end
  end

  defmacro __before_compile__(env) do
    for {_name_arity, clauses} <- Module.get_attribute(env.module, :clauses) do
      clauses
      |> Enum.sort()
      |> Enum.reverse()
      |> Enum.map(fn [_name, _arity, _time, clause] -> clause end)
    end
  end

  defmacro initially(do: {:__block__, _, clauses}) do
    assimilate_clauses(:initially, clauses)
  end

  defmacro initially(do: clause) do
    assimilate_clauses(:initially, [clause])
  end

  defmacro from(timestamp, do: {:__block__, _, clauses}) do
    assimilate_clauses(timestamp, clauses)
  end

  defmacro from(timestamp, do: clause) do
    assimilate_clauses(timestamp, [clause])
  end

  defp assimilate_clauses(timestamp, clauses) do
    {t, _} = Code.eval_quoted(timestamp)
    t = to_unix(t)

    clauses =
      clauses
      |> Enum.map(&add_timestamp_arg(t, &1))
      |> Enum.group_by(fn [name, arity, _, _] -> {name, arity} end)

    quote bind_quoted: [clauses: Macro.escape(clauses)] do
      @clauses Map.merge(@clauses || %{}, clauses, fn _key, v1, v2 -> v1 ++ v2 end)
    end
  end

  defp to_unix(:initially), do: 0

  defp to_unix(%DateTime{} = t), do: DateTime.to_unix(t)

  defp to_unix(%NaiveDateTime{} = t) do
    t
    |> NaiveDateTime.to_erl()
    |> :calendar.datetime_to_gregorian_seconds()
  end

  defp to_unix(%Date{} = date) do
    date
    |> Map.merge(%{
      __struct__: DateTime,
      hour: 0,
      minute: 0,
      second: 0,
      microsecond: {0, 0},
      std_offset: 0,
      utc_offset: 0,
      zone_abbr: "UTC",
      time_zone: "Etc/UTC"
    })
    |> DateTime.to_unix()
  end

  defp add_timestamp_arg(
         t,
         {:def, meta,
          [
            {:when, meta2, [{name, _, args}, guard]},
            implementation
          ]}
       ) do
    [
      name,
      length(args),
      t,
      {:def, meta,
       [
         {:when, meta2,
          [
            {name, [], [{:__timestamp__, [], Elixir} | args]},
            {:and, [],
             [
               {:>=, [], [{:__timestamp__, [], Elixir}, t]},
               guard
             ]}
          ]},
         implementation
       ]}
    ]
  end

  defp add_timestamp_arg(t, {:def, meta, [{name, meta2, args}, implementation]}) do
    [
      name,
      length(args),
      t,
      {:def, meta,
       [
         {:when, meta2,
          [
            {name, [], [{:__timestamp__, [], Elixir} | args]},
            {:>=, [], [{:__timestamp__, [], Elixir}, t]}
          ]},
         implementation
       ]}
    ]
  end

  defp add_timestamp_arg(_t, clause) do
    Process.sleep(500)
    System.halt(1)
    clause
  end
end
