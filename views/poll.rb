module Views
  class Poll < Layout
    def logged_in
      !!@username
    end
    
    def id
      @poll['id']
    end
    
    def question
      @poll['question']
    end
    
    def voted
      @voted
    end
    
    def options
      [
        {'option' => '0', 'text' => @poll['options']['0']},
        {'option' => '1', 'text' => @poll['options']['1']},
        {'option' => '2', 'text' => @poll['options']['2']},
        {'option' => '3', 'text' => @poll['options']['3']}
      ]
    end
  end
end
