defmodule FibSolver do
    
    def fib(scheduler) do
        send scheduler, { :ready, self }
        receive do
            { :fib, n, client } ->
                send client, {:answer, n, fib_calc(n), self }
                fib scheduler
            { :shutdown } -> 
                exit(:normal)
        end    
    end

    # Very inefficient on purpose
    defp fib_calc(0), do: 0
    defp fib_calc(1), do: 1
    defp fib_calc(n), do: fib_calc(n-1) + fib_calc(n-2)

end


defmodule Scheduler do
    
    def run(nodes, num_processes, module, func, to_calculate) do

        nodes
        |> Enum.take(num_processes)
        |> Enum.map(fn(cluster_node) -> Node.spawn(cluster_node, module, func, [self]) end)
        |> schedule_processes(to_calculate, [])
    end

    defp schedule_processes(processes, queue, results) do
        receive do
            {:ready, pid} when length(queue) > 0 -> 
                [next | tail ] = queue
                send pid, {:fib, next, self}
                schedule_processes(processes, tail, results)
            {:ready, pid} ->
                send pid, {:shutdown}
                if length(processes) > 1 do
                    schedule_processes(List.delete(processes, pid), queue, results)
                else
                    Enum.sort(results, fn {n1,_}, {n2,_} -> n1 <= n2 end)
                end
            {:answer, number, result, _pid} ->
                schedule_processes(processes, queue, [{number, result} | results])
        end
    end

end


defmodule FibRunner do
    
    def run() do
        
        to_process = List.duplicate(39, 20)
        all_nodes = [Node.self()] ++ Node.list()

        core_nodes = 
            Enum.flat_map(all_nodes, fn(node) -> List.duplicate(node, 4) end )

        len = length core_nodes

        Enum.each 1..len, fn num_processes ->
        {time, result} = :timer.tc(
            Scheduler, :run,
            [core_nodes, num_processes, FibSolver, :fib, to_process]
        )

        if num_processes == 1 do
            IO.puts inspect result
            IO.puts "\n #   time (s)"
        end
        :io.format "~2B     ~.2f~n", [num_processes, time/1000000.0]
        end

    end

end

