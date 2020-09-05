defmodule News do
   require Logger

   alias News.HackerNewsClient

   @lang_of_interest ~w(elixir erlang haskell clojure scala f# idris ocaml)
   @label_padding 7
   @telemetry_event_id "finch-timings"

   def generate_report(parent_id) do
     # Setup telemetry events and agent to store timings
    {:ok, http_timing_agent} = Agent.start_link(fn -> [] end)
    start_time = System.monotonic_time()
    attach_telemetry_event(http_timing_agent)
    {:ok, child_ids} = HackerNewsClient.get_child_ids(parent_id)
    # Logger.info(inspect child_ids)

    child_ids
    |> Task.async_stream(&HackerNewsClient.get_child_item/1, max_concurrency: HackerNewsClient.pool_size())
    |> Enum.reduce([], fn {:ok, text}, acc -> 
        [text | acc]
    end)
    |> Enum.map(&count_lang_occurences/1)
    |> Enum.reduce(%{}, &sum_lang_occurences/2)
    |> print_table_results()

    average_time = calc_average_req_time(http_timing_agent)
    total_time = System.convert_time_unit(System.monotonic_time() - start_time, :native, :millisecond)

    :ok = Agent.stop(http_timing_agent)
    :ok = :telemetry.detach(@telemetry_event_id)

    IO.puts("Average request time to Hacker News Firebase API: #{average_time}ms")
    IO.puts("Total time to fetch all #{length(child_ids)} child posts: #{total_time}ms")
   end

   defp attach_telemetry_event(http_timing_agent) do
     :telemetry.attach(
       @telemetry_event_id,
       [:finch, :response, :stop],
       fn _event, %{duration: duration}, _metatdata, _config -> 
          Agent.update(http_timing_agent, fn timings -> [duration | timings] end)
       end,
       nil
     )
   end

   defp count_lang_occurences(text) do
     Map.new(@lang_of_interest, fn string_of_interest ->
        count = if String.contains?(text, string_of_interest), do: 1, else: 0

        {string_of_interest, count}
    end)
   end

   defp sum_lang_occurences(counts, acc) do
     Map.merge(acc, counts, fn _lang, count_1, count_2 ->
        count_1 + count_2
    end)
   end

   defp print_table_results(results) do
     results
     |> Enum.sort(fn {_lang_1, count_1}, {_lang_2, count_2} -> 
        count_1 > count_2
     end)
     |> Enum.each(fn {language, count} -> 
        label = String.pad_trailing(language, @label_padding)
        bars = String.duplicate("█", count)

        IO.puts("#{label} |#{bars}")
    end)
   end

   defp calc_average_req_time(http_timing_agent) do
     http_timing_agent
     |> Agent.get(fn timing -> timing end)
     |> Enum.reduce({0, 0}, fn timing, {sum, count} -> 
        {sum + timing, count + 1}
    end)
    |> case  do
      {_, 0} ->
        "0"
      {sum, count} -> 
        sum
        |> System.convert_time_unit(:native, :millisecond)
        |> Kernel./(count)
        |> :erlang.float_to_binary(decimals: 2)
    end
   end
end
