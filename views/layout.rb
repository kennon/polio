module Views
  class Layout < Mustache
    def title
      "POLIO"
    end
    
    def username
      @username
    end
  end
end
