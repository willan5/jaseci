# ByLLM Project

A **Jac + Python-based system** for automating GitHub repository analysis.  
This project clones repositories, generates structured README summaries, builds file trees, and performs semantic code analysis using **Gemini LLM**.

---

## Table of Contents

- [Features](#features)  
- [Installation](#installation)  
- [Configuration](#configuration)  
- [Usage](#usage)  
- [File Structure](#file-structure)  
- [LLM Integration](#llm-integration)  
- [Output](#output)  

---

## Features

- Clone GitHub repositories automatically.
- Generate concise README summaries using **Gemini LLM**.
- Build a nested JSON file tree of the repository.
- Analyze code to extract Python and Jac entities, functions, and call relationships.
- Infer semantic edges using LLM for better understanding of code structure.
- Save outputs as JSON for downstream usage.

---

## Installation

1. Clone this repository:

```bash
git clone <this-repo-url>
cd byllm/BE
cd byllm/FE

    Install required Python dependencies (recommended in a virtual environment):

pip install -r requirements.txt

    Requirements include byllm, dotenv, Gemini API, and Python >= 3.10.

Configuration

    Create a .env file in the BE folder:

touch .env

    Add your Gemini LLM API key:

GEMINI_API_KEY=<your_api_key_here>


    Load environment variables automatically in the program.

    You can get an API key by signing up on the Gemini LLM platform

    or from your ByLLM provider.

Usage
Backend (BE) – Data Processing

cd byllm/BE
jac run main.jac

    The program will prompt for a GitHub repository URL .

    It will:

        Clone the repo into cloned_projects/

        Generate a structured summary (README + JSON) into readme_files/ and json_files/

        Build a nested file tree in filetree/

        Run semantic code analysis with CodeAnalyzer and save *_ccg.json in code_analysis/

Frontend (FE) – Visualization (optional)

cd byllm/FE
jac run main.py

    Only required if you want to interact with the node/tree visualization frontend.

File Structure

byllm/
├─ BE/
│  ├─ main.jac          # Main Jac workflow
│  ├─ walkers/          # Jac walkers (RepoMapper, GetRepoDetail, etc.)
│  ├─ cloned_projects/  # Cloned GitHub repositories
│  ├─ readme_files/     # Generated README.md
│  ├─ json_files/       # Structured JSON summaries
│  ├─ filetree/         # File tree JSON
│  └─ code_analysis/    # LLM-based code analysis (CCG JSON)
├─ FE/
│  ├─ main.py            # Frontend walker
│                     # Visualization and UI logic

LLM Integration

    Uses Gemini 2.0 Flash via ByLLM.

    The LLM is used for:

        Summarizing README files

        Inferring semantic edges (function calls, node relationships, etc.)

        Enriching code analysis for better structural insight

Setting up API Key

    Sign up for Gemini LLM or your ByLLM provider.

    Obtain your API key.

    Add it to .env:

GEMINI_API_KEY=your_api_key_here

    The program automatically reads the key and initializes the model.

Output

After running the program, you will get:

    README summary per repository:

readme_files/<repo_name>/README.md

    Structured JSON summary:

json_files/<repo_name>/<repo_name>.json

    File tree JSON:

filetree/<repo_name>/<repo_name>_tree.json

    Semantic code analysis:

code_analysis/<repo_name>/<repo_name>_ccg.json

Each file contains structured information about the repository, making it easy to integrate with dashboards, documentation systems, or AI agents.
Example Workflow

cd byllm/BE
jac run main.jac
# Input GitHub URL: https://github.com/user/repo
# ✅ Cloning repo...
# ✅ Generating README summary...
# ✅ Building file tree...
# ✅ Running code analysis...

Example used in the project: https://github.com/jaseci-labs/littleX

    After execution, check readme_files/, json_files/, and code_analysis/ for outputs.