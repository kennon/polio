module Views
  class Index < Layout
    def logged_in
      !!@username
    end
  end
end
