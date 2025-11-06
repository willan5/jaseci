impl SearchQuery.start {
    if not [root --> (`?info_node)] {
        next = root ++> info_node(self.user_query);
    } else {
        next = [root --> (`?info_node)];
    }
    visit next;
}

impl SearchQuery.process_query {
    here.processed_query = self.user_query;
    
    # Use LLM's knowledge 
    self.article_results = get_comprehensive_info(self.user_query);
    
    if not [here --> (`?results_node)] {
        next = here ++> results_node(self.article_results);
    } else {
        next = [here --> (`?results_node)];
    }
    
    visit next;
}

impl SearchQuery.show_results {
    here.articles = self.article_results;
    
    formatted_output = format_info_results(self.article_results);
    #print(formatted_output);
    report(formatted_output);
    
    disengage;
}