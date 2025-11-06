# InfoFinder

A Jaclang-based search application that uses Gemini AI to provide intelligent responses to user queries.

## Features
- Interactive command-line interface
- AI-powered responses using Google Gemini
- Node/walker architecture implementation
- Handles information queries, programming questions, and general knowledge

## Prerequisites
- Python 3.8+
- Jaclang installed
- Google Gemini API key

## Installation

1. ### **Clone this repository**

   - git clone https://github.com/willan5/infofinder.git



2. ### **Setup environment**
   ```bash
   - python -m venv yourenv

   - source yourenv/bin/activate
     


3. ### **Install dependencies**
   ```bash
   - pip install -r requirements.txt



4. ### **Setup API Key**
   ```bash
    Option A: Temporary (current session only)
   
   - export GEMINI_API_KEY="your_gemini_api_key_here"



   Option B: Permanent (add to bashrc)

   - echo 'export GEMINI_API_KEY="your_gemini_api_key_here"' >> ~/.bashrc
   - source ~/.bashrc



   Option C: Using .env file

   - echo 'GEMINI_API_KEY="your_gemini_api_key_here"' > .env



## Usage

   - jac run search.jac



Enter your query when prompted.

## Project Structure
- `search.jac` - Main program definition
- `search.impl.jac` - Implementation logic
- `requirements.txt` - Python dependencies

## Getting a Gemini API Key
1. Visit [Google AI Studio](https://aistudio.google.com/)
2. Sign in with your Google account
3. Create a new API key
4. Use it in the setup steps above

## Example Queries
- "explain photosynthesis"
- "write a python program to add two numbers"
- "who is uhuru kenyatta"
- "how to create a GitHub repository"
