def PastryAPI do
    use Genserver

    def handle_call({:newLeafs, leafset}) do
        #node will send the message here whenever its leaf set changes
        #applicaiton wide changes will be made here
    end

    def handle_cast({:handleDelivery, hopCount}, state) do
        {_, requestsReceived} = Map.get_and_update(state, :requestsReceived, fn currentVal -> {currentVal, currentVal + 1} end)
        state = Map.merge(state, requestsReceived)
        {_, hopCount} = Map.get_and_update(state, :hopCount, fn currentVal -> {currentVal, currentVal+hopCount} end)
        state = Map.merge(state, hopCount)

        mapReq = state[:numReq] * state[:numNodes]
        if(state[:requestsReceived] >= (mapReq)) do
            hopCountMean = state[:hopCount]/mapReq
            IO.puts "Mean hop count is: #{inspect hopCountMean}"
            Process.exit(self(), :normal)
        end
        {:noreply, state}
    end

    def handle_cast({:updatePastry, numReq, listOfNodes, numNode}, state) do
        {_, listOfNodes} = Map.get_and_update(state,:listOfNodes, fn currentVal -> {currentVal, listOfNodes} end)
        {_, currentNumNodes} = Map.get_and_update(state, :numNode, fn currentVal ->{currentVal, numNode} end)
        {_, hopCount} = Map.get_and_update(state, :hopCount, fn currentVal -> {currentVal, 0} end)
        {_, currentNumReq} = Map.get_and_update(state, :currentNumReq, fn currentVal -> {currentVal, currentNumReq} end)
        {_, requestsReceived} = Map.get_and_update(state, :requestsReceived, fn currentVal -> {currentVal, 0} end)

        state = Map.merge(state, listOfNodes)
        state = Map.merge(state, currentNumNodes)
        state = Map.merge(state, hopCount)
        state = Map.merge(state, currentNumReq)
        state = Map.merge(state, requestsReceived)

        {:noreply, state}
    end

    def pastryInit(nodeList, numReq) do
        Enum.each(Enum.with_index(nodeList), fn(x) ->
                        routingTable = PastryNode.constructNodeRouteTable(elem(elem(x,0),1),nodeList, @b)
                        leafUpper = PastryNode.computeLeafUpper([], elem(x, 1), nodeList, @b)
                        leafLower = PastryNode.computeLeafLower([], elem(x, 1), nodeList, @b)
                        neighbourSet = PastryNode.computeNeighbourSet(0, nodeList, elem(x,1), [])
                        numRows = round(:math.log(length(list_of_nodes_with_pids))/:math.log(:math.pow(2,@b)))
                        numCols = trunc(:math.pow(2,@b)-1)
                        Genserver.cast(elem(elem(x,0),0), {:updateAllSets, numReq, numRows, numCols, leafUpper, leafLower, neighbourSet, routingTable})
        end)
    end

    def startAlgo(numNode, numReq) do
        {:ok, _} = Genserver.start_link(__MODULE__, :ok, name: Daddy)
        rangeOfNum = 1..numNode

        # return the idx_hashid map, hashid_dval map and hashid sorted tuple.
        #only generates the node ids and maps doesn't spawn yet.
        {idx_to_hashid_map,hashid_dval_map,sorted_hashid_tup} = genNodeIds(range)
        
        buildNetwork(idx_to_hashid_map,hashid_dval_map,sorted_hashid_tup)

        nodeList = spawnNodesAndGetPidList(Enum.to_list(rangeOfNum), numNode, [], [], 1)
        nodeList = Enum.sort(nodeList, fn(m,n) -> elem(m,2) < elem(n,2) end)
        Genserver.cast(Daddy, {:updatePastry, numReq, nodeList, numNode})
        pastryInit(nodeList, numReq)
        sendDataNow(numNode, 0, nodeList)
    end

    def buildNetwork(idx_to_hashid_map,hashid_dval_map,sorted_hashid_tup,numNodes, numReq) do

            leafUpper = PastryNode.computeLeafUpper([], elem(x, 1), nodeList, @b)
            leafLower = PastryNode.computeLeafLower([], elem(x, 1), nodeList, @b)

    end

    def genNodeIds(range) do

        # generate the hashids for the range 1..nodenum.
        idx_to_hashid_map=Enum.reduce(range, %{}, fn (idx,acc_idx_hashid_map) -> (
            hashid= :crypto.hash(:md5,"#{idx}") |> Base.encode16()
            Map.put(acc_idx_hashid_map,idx, hashid)
        )end)

        hashrange=Map.values(idx_to_hashid_map)
    
        #hashid to decimal value map.
        hashid_dval_map=Enum.reduce(hashrange, %{}, fn (hashid,acc_hashid_dval_map) -> (
            dval=Integer.parse(hashid,16)
            Map.put(acc_hashid_dval_map, hashid,dval)
        )end)

        #sorted hashid map for leaf set generation
        sorted_hashid_tup =  Enum.sort(hashrange, fn(x,y) -> (hashid_dval_map[x]<hashid_dval_map[y])end) |> List.to_tuple

        {idx_to_hashid_map,hashid_dval_map,sorted_hashid_tup}
    end


    def sendDataNow(numNode, currentCount, nodeList) do
        if (currentCount < numNode) do
            nodeRandom = Enum.random(nodeList)
            updatedList = nodeList -- [nodeRandom]
            currentCount = currentCount + 1
            nodeId = elem(nodeRandom, 2)
            pId = elem(nodeRandom, 0)
            hashCode = elem(nodeRandom, 1)
            Genserver.cast(pId,{recieveReq, nodeId, 0, numNode, pId, hashCode, @b})
            sendDataNow(numNode, currentCount, nodeList)
        end
    end

end