"""Information Finder"""

import from byllm.llm { Model }

# Configure the LLM
glob llm = Model(model_name="gemini/gemini-2.0-flash", verbose=False);

"""You are a helpful AI assistant. Provide comprehensive and useful responses to user queries.
For information requests, give factual details. Give at most 10 key points with factual, verifiable information.
For programming questions, provide working code examples comments and explanation without numbering.
For learning topics, offer clear explanations. For unclear questions, prompt the user to provide more clarity. Always aim to be helpful and informative."""
def get_comprehensive_info(query: str) -> list[str, ...] by llm();

"""Format the response in a natural, readable way without forcing numbered lists for all responses."""
def format_info_results(results: list[str, ...]) -> str by llm();

walker SearchQuery {
    has user_query: str;
    has article_results: list[str, ...] = [];
    
    can start with `root entry;
    can process_query with info_node entry;
    can show_results with results_node entry;
}

node info_node {
    has processed_query: str;
}

node results_node {
    has articles: list[str, ...];
}

# Program ntry point
with entry:__main__ {
    # Get user input from users
    user_input = input("What information are you looking for? ");
    root spawn SearchQuery(user_input);
}