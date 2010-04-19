module Views
  class Results < Layout
    def id
      @poll['id']
    end
    
    def rand_username
      rand(10_000).to_s
    end
    
    def question
      @poll['question']
    end
    
    def options
      [
        {'option' => '0', 'text' => @poll['options']['0'], 'votes' => @votes[0]},
        {'option' => '1', 'text' => @poll['options']['1'], 'votes' => @votes[1]},
        {'option' => '2', 'text' => @poll['options']['2'], 'votes' => @votes[2]},
        {'option' => '3', 'text' => @poll['options']['3'], 'votes' => @votes[3]}
      ]
    end
    
    def flot_data
      Yajl::Encoder.encode([
        {:data => [[0,3], [@votes[0],3]]},
        {:data => [[0,2], [@votes[1],2]]},
        {:data => [[0,1], [@votes[2],1]]},
        {:data => [[0,0], [@votes[3],0]]},
      ])
    end
    
    def flot_options
      Yajl::Encoder.encode({
        :legend => { :show => false },
        :bars => { :show => true, :horizontal => true, :barWidth => 1, :fill => true, :lineWidth => 1 },
        :xaxis => { :tickDecimals => 0, :min => 0 },
        :yaxis => { :min => 0, :max => 4, :labelWidth => nil, 
            :ticks => [[0.5, @poll['options']['3']], [1.5, @poll['options']['2']], [2.5, @poll['options']['1']], [3.5, @poll['options']['0']]]
        }
      })
    end
    
    def voters
      [
        @voters[0].collect {|voter| {:name => voter}},
        @voters[1].collect {|voter| {:name => voter}},
        @voters[2].collect {|voter| {:name => voter}},
        @voters[3].collect {|voter| {:name => voter}},
      ]
    end
  end
end
