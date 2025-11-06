# ================================
# Imports and Configuration
# ================================
import from byllm.llm { Model }
import from dotenv { load_dotenv }
import re;
import os;

# Configure the LLM
glob llm = Model(model_name="gemini/gemini-2.0-flash", verbose=False);

# ================================
# Nodes Definitions
# ================================
node UserUrl{
    has github_url: str = '';  
}

node RepoInfoNode{
    has repo_url: str = '';
    has repo_name: str = '';
    has project_path: str = '';
    has project_summary: str = '';
    has clone_status: str = ''; 
    has summary_file_path: str = '';
    has json_file_path: str = ''; 
}

node FileTree{
    
    has file_tree: str = '';
    has repo_url: str = '';
    has file_name: str='';
    has file_path: str='';
}

node RepoDataSummary{
    has repo_name: str = "";
    has repo_url: str = "";
    has project_path: str = "";
    has json_file_path: str = "";
    has readme_file_path: str = "";
}


# ================================
# Walker: GetRepoDetail
# Clones repo and generates a summary
# ================================
walker GetRepoDetail {
    has info_url: str = '';
    has repo_data: dict = {};  # changed [] → {} for dictionary

    can start with `root entry{
        # Look for UserUrl node
        if not [root -->(`?UserUrl)]{
            print("Node Missing");
        }
        else{
            next = [root --> (`?UserUrl)][0];
        }
        print(f'Visiting {next}');
        visit next;
    }

    can useurl with UserUrl entry{
        self.info_url = here.github_url;
        print(f'Data from UserUrl present: {self.info_url}');
        print('====Using Python to process info_url gotten from UserUrl');

        ::py::
        from byllm.lib import Model, by
        import subprocess

        llm = Model(model_name="gemini/gemini-2.0-flash")

        # Generate repo summary using Gemini
        @by(model=llm)
        def get_repo_summary(readmedata: str) -> str:
            try:
                # directly ask the model, not return the prompt itself
                return llm.chat(f"Summarize this README:\n {readmedata}")
            except Exception as e:
                return f"Error summarizing README: {str(e)}"

        def count_files(path, skip_dirs=None):
            if skip_dirs is None:
                skip_dirs = {'.git', '__pycache__', '.vscode', '.venv', 
                            '.idea', '.github', 'node_modules', 'dist', 'build'}
            count = 0
            for root, dirs, files in os.walk(path):
                dirs[:] = [d for d in dirs if d not in skip_dirs]
                count += len(files)
            return count

        def generate_summary(path):
            try:
                summary = "No README file found in the repo"
                skip_dirs = {'.git', '__pycache__', '.vscode', '.venv', 
                            '.idea', '.github', 'node_modules', 'dist', 'build'}

                for root, dirs, files in os.walk(path):
                    dirs[:] = [d for d in dirs if d not in skip_dirs]
                    for file in files:
                        if file.lower().startswith('readme'):
                            readme_file = os.path.join(root, file)
                            with open(readme_file, 'r', encoding='utf-8', errors='ignore') as f:
                                content = f.read(3000)
                                summary = get_repo_summary(content)
                                return f"Summary of {os.path.basename(readme_file)}:\n{summary}"

                # fallback
                file_count = count_files(path, skip_dirs)
                return f"{summary} | Total files: {file_count}"

            except Exception as e:
                return f"Summary generation failed: {str(e)}"


        # Prepare repo info and clone it
        root_dir = "cloned_projects"
        os.makedirs(root_dir, exist_ok=True)

        # Extract clean repo name from the URL
        repo_name = self.info_url.rstrip("/").split("/")[-1].replace(".git", "")

        # Define the correct destination path inside cloned_projects
        destination = os.path.join(root_dir, repo_name)
        os.makedirs(destination, exist_ok=True)

        # Clone logic
        if not os.path.exists(os.path.join(destination, ".git")):
            try:
                print(f"Cloning {repo_name} into {destination}...")
                subprocess.run(
                    ["git", "clone", "--depth", "1", self.info_url, destination],
                    check=True,
                    text=True
                )
                clone_status = "success"
            except subprocess.CalledProcessError as e:
                clone_status = "failed"
                print(f"Git clone failed: {e}")
        else:
            print(f"Repository '{repo_name}' already exists at {destination}")
            clone_status = "already_exists"

        # Always create repo_data even if clone failed
        self.repo_data = {
            "repo_name": repo_name,
            "repo_url": self.info_url,
            "local_path": destination if os.path.exists(destination) else None,
            "clone_status": clone_status,
            "project_summary": generate_summary(destination) if os.path.exists(destination) else "No summary - clone failed"
        }
        ::py::

        print('===Creating RepoInfoNode to store the processed data===');

        # Create and link RepoInfoNode
        repo_data = RepoInfoNode(
            repo_url=self.info_url,
            repo_name=self.repo_data["repo_name"],
            clone_status=self.repo_data["clone_status"],
            project_path=self.repo_data["local_path"],
            project_summary=self.repo_data["project_summary"]
        );

        here ++> repo_data;
        print(f"RepoInfoNode created for: {repo_data.repo_name}");
        disengage;
    }
}
# ================================
# Walker: GetRepoData
# Creates README + JSON summaries
# ================================
walker GetRepoData{
    has repo_url: str = '';
    has repo_name: str = '';
    has clone_status: str = '';
    has project_path: str = '';
    has project_summary: str = '';

   can start with UserUrl entry{
        print('================Creating walker to confirm RepoInfoNode data==========');
        visit[-->];
    }

    can getdata with RepoInfoNode entry{
        # pull data from RepoInfoNode
        self.repo_url = here.repo_url;
        self.repo_name = here.repo_name;
        self.clone_status = here.clone_status;
        self.project_path = here.project_path;
        self.project_summary = here.project_summary;

        ::py::
        import os, re, json, textwrap
        from datetime import datetime

        repo_name = self.repo_name or "unknown"
        cleaned_repo_name = re.sub(r"[^A-Za-z0-9\-_]", "_", repo_name)
        project_summary = self.project_summary or ""

        # Create root folders
        root_readme = "readme_files"
        root_json = "json_files"
        os.makedirs(root_readme, exist_ok=True)
        os.makedirs(root_json, exist_ok=True)

        # Create subfolders per repo
        readme_dir = os.path.join(root_readme, cleaned_repo_name)
        json_dir = os.path.join(root_json, cleaned_repo_name)
        os.makedirs(readme_dir, exist_ok=True)
        os.makedirs(json_dir, exist_ok=True)

        # Define output paths
        readme_file = os.path.join(readme_dir, "README.md")
        json_file = os.path.join(json_dir, f"{cleaned_repo_name}.json")

        # Extract JSON block if present in summary
        json_data = None
        try:
            json_match = re.search(r"```json\s*(\{.*?\})\s*```", project_summary, flags=re.S)
            if json_match:
                json_data = json.loads(json_match.group(1))
            else:
                start = project_summary.find("{")
                end = project_summary.rfind("}")
                if start != -1 and end != -1:
                    candidate = project_summary[start:end + 1]
                    json_data = json.loads(candidate)
        except Exception as e:
            print(f"JSON extraction failed: {e}")
            json_data = None

        # Clean markdown from code fences
        cleaned_summary = project_summary
        if "```" in cleaned_summary:
            cleaned_summary = re.sub(r"^.*?```(?:json)?\s*", "", cleaned_summary, flags=re.S)
            cleaned_summary = re.sub(r"\s*```.*$", "", cleaned_summary, flags=re.S)
        cleaned_summary = cleaned_summary.strip()

        # Build json content
        structured_json = {
        "repo_name": repo_name,
        "repo_url": getattr(self, "repo_url", None),
        "clone_status": getattr(self, "clone_status", None),
        "local_path": getattr(self, "project_path", None),
        "generated_at": datetime.utcnow().isoformat() + "Z",
        "generated_by": "Gemini LLM",
        "summary": json_data or {"overview": cleaned_summary}
        }
        #Build README content
        sections = []
        summary_section = structured_json["summary"]

        if isinstance(summary_section, dict):
            overview = summary_section.get("overview", "")
            features = summary_section.get("features", [])
            usage = summary_section.get("usage", "")
        else:
            overview, features, usage = cleaned_summary, [], ""
        readme_content = textwrap.dedent(f"""\
            # Project Summary of: {repo_name}
            **Repository URL:** {self.repo_url}  
            **Clone Status:** {self.clone_status}  
            **Local Path:** {self.project_path}

            ---
            ## AI Summary

            {cleaned_summary}

            ---
        """)
        if features:
            readme_content += "## Key Features\n" + "\n".join(f"- {f}" for f in features) + "\n\n"

        if usage:
            readme_content += f"## 🚀 Quick Start\n```bash\n{usage.strip()}\n```\n\n"

        readme_content += f"*Generated automatically by Gemini AI — {structured_json['generated_at']}*\n"


        # Write README file
        try:
            if not os.path.exists(readme_file):
                with open(readme_file, "w", encoding="utf-8") as f:
                    f.write(readme_content)
                print(f"README created at: {readme_file}")
            else:
                print(f"README already exists at: {readme_file}")
        except Exception as e:
            print(f"Failed to write README: {e}")

        # Write JSON summary
        try:
            if not os.path.exists(json_file):
                with open(json_file, "w", encoding="utf-8") as f:
                    json.dump(json_data or {"Summary": cleaned_summary}, f, indent=2, ensure_ascii=False)
                print(f"JSON summary saved at: {json_file}")
            else:
                print(f"JSON summary already exists at: {json_file}")
        except Exception as e:
            print(f"Failed to write JSON summary: {e}")

        # Update node paths
        self.summary_file_path = readme_file
        self.json_file_path = json_file

        self.repo_data_summary = {
            "repo_name": self.repo_name,
            "repo_url": self.repo_url,
            "project_path": self.project_path,
            "json_file" : self.summary_file_path,
            "readme_file" : self.json_file_path
        }
        ::py::
       #* print('===Creating RepoInfoNode to store the processed data===');
        
        #Create FileTree node and link
        repo_data_summary = RepoDataSummary(
            repo_url = repo_data_summary ['repo_url'],
            repo_name = repo_data_summary ['repo_name'],
            readme_file_path= repo_data_summary['summary_file_path'],
            json_file_path=repo_data_summary['json_file_path']

        );
        here++> repo_data_summary;
        #print(f"Linked FileTree node for: {file_tree.file_name}");*#
        disengage;
    }
   
   
}

# ==================================================
# - Walker: CodeAnalyzer
# - Gets the cloned repo and analyzes code structure
# ==================================================
walker CodeAnalyzer {
    has repo_name: str = '';
    has repo_path: str = '';
    has ccg_path: str = "";

   #*can start with `root entry{
        # Look for UserUrl node
        if not [root -->(`?UserUrl)]{
            print("Node Missing");
        }
        else{
            next = [root --> (`?UserUrl)][0];
        }
        print(f'Visiting {next}');
        visit next;
    }*#
    can useurl with UserUrl entry{
        print('================Creating CodeAnalyzer walker to analyze codebase==========');
        visit[-->];
    }

    can visit with RepoInfoNode entry{
        self.repo_name = here.repo_name;
        self.repo_path = here.project_path;
        print(f'Analyzing repo: {self.repo_name} at {self.repo_path}');
        self.analyze_repo();

        
        # Placeholder for code analysis logic
        # This is where you would implement the logic to analyze the codebase,
        # extract modules, entities, functions, and create corresponding nodes.
    }
    def analyze_repo(){
        ::py::
        import os, ast, json, re
        from tree_sitter import Language, Parser
        from byllm.lib import Model, by

        repo_path = self.repo_path
        repo_name = self.repo_name
        print(f"🔍 Starting code analysis for repo: {repo_name} at {repo_path}")

    
        # ===== LLM setup =====*#
        llm = Model(model_name="gemini/gemini-2.0-flash")

        # ===== result containers =====
        result = {
            "modules": [],
            "entities": [],
            "functions": [],
            "edges": []
        }

        # ===== main traversal =====
        for root, dirs, files in os.walk(repo_path):
            dirs[:] = [d for d in dirs if d not in {'.git', '__pycache__', 'node_modules', '.venv', '.vscode'}]

            for file in files:
                file_path = os.path.join(root, file)

                # =====================================
                #               PYTHON
                # =====================================
                if file.endswith(".py"):
                    module_name = os.path.relpath(file_path, repo_path).replace(os.sep, '.')[:-3]
                    result["modules"].append({
                        "module_name": module_name,
                        "language": "Python",
                        "file_path": file_path
                    })
                    try:
                        with open(file_path, "r", encoding="utf-8") as f:
                            tree = ast.parse(f.read(), filename=file_path)

                        for node in ast.walk(tree):
                            # --- classes ---
                            if isinstance(node, ast.ClassDef):
                                entity_node = {
                                    "name": node.name,
                                    "type": "class",
                                    "base_entities": [b.id for b in node.bases if isinstance(b, ast.Name)],
                                    "associated_module": [module_name],
                                    "language": "Python",
                                    "file_path": file_path
                                }
                                if not any(e["name"] == node.name and e["file_path"] == file_path for e in result["entities"]):
                                    result["entities"].append(entity_node)

                                # inheritance edges
                                for base in node.bases:
                                    if isinstance(base, ast.Name):
                                        if not any(e["from"] == node.name and e["to"] == base.id and e["type"] == "inherits" for e in result["edges"]):
                                            result["edges"].append({
                                                "from": node.name,
                                                "to": base.id,
                                                "type": "inherits",
                                                "language": "Python",
                                                "file_path": file_path
                                            })

                            # --- functions ---
                            elif isinstance(node, ast.FunctionDef):
                                calls = {n.func.id for n in ast.walk(node)
                                    if isinstance(n, ast.Call) and isinstance(n.func, ast.Name)}
                                result["functions"].append({
                                    "function_name": node.name,
                                    "parent_entity": "",
                                    "calls": calls,
                                    "language": "Python",
                                    "file_path": file_path
                                })
                                # call edges
                                for c in set(calls):
                                    if not any(
                                        e["from"] == node.name
                                        and e["to"] == c
                                        and e["type"] == "calls"
                                        for e in result["edges"]
                                    ):
                                        result["edges"].append({
                                            "from": node.name,
                                            "to": c,
                                            "type": "calls",
                                            "language": "Python",
                                            "file_path": file_path
                                        })
                    except SyntaxError as e:
                        print(f"Syntax error in {file_path} (line {e.lineno}): {e.text.strip() if e.text else ''}")
                        
                    except Exception as e:
                        print(f"Python parse error in {file_path}: {e}")

                # =====================================
                #                 JAC
                # =====================================
                elif file.endswith(".jac"):
                    module_name = os.path.relpath(file_path, repo_path).replace(os.sep, '.')[:-4]
                    result["modules"].append({
                        "module_name": module_name,
                        "language": "Jac Language",
                        "file_path": file_path
                    })

                    try:
                        with open(file_path, "r", encoding="utf-8") as f:
                            content = f.read()


                        #regex pass for jac constructs
                        node_defs = re.findall(r"\bnode\s+(\w+)", content)
                        walker_defs = re.findall(r"\bwalker\s+(\w+)", content)
                        func_defs = re.findall(r"\bdef\s+(\w+)", content)
                        edge_defs = re.findall(r"\bedge\s+(\w+)", content)
                        inline_edges = re.findall(r"(\w+)\s*-\[?(\w+)?\]?\s*[-=]*>\s*(\w+)", content)

                        for name in node_defs:
                            result["entities"].append({
                                "name": name, "type": "node", "language": "Jac Language",
                                "base_entities": [], "associated_module": [module_name],
                                "file_path": file_path
                            })
                        for name in walker_defs:
                            result["entities"].append({
                                "name": name, "type": "walker", "language": "Jac Language",
                                "base_entities": [], "associated_module": [module_name],
                                "file_path": file_path
                            })
                        for name in func_defs:
                            result["functions"].append({
                                "function_name": name, "parent_entity": "",
                                "calls": [], "language": "Jac Language", "file_path": file_path
                            })
                        for name in edge_defs:
                            result["entities"].append({
                                "name": name, "type": "edge", "language": "Jac Language",
                                "file_path": file_path
                            })
                        for src, etype, dest in inline_edges:
                            result["edges"].append({
                                "from": src, "to": dest,
                                "type": etype or "connects",
                                "language": "Jac Language",
                                "file_path": file_path
                            })
                    except Exception as e:
                            print(f"Jac parse error in {file_path}: {e}")

                # Summarize inline edges
                for edge in result.get("edges", []):
                    if not isinstance(edge, dict):
                        print(f"Skipping malformed edge: {edge}")
                        continue
                    if edge.get("type") == "connects":
                        edge["summary"] = f"{edge.get('from')} connects to {edge.get('to')}"

                    elif edge.get("type") == "calls":
                        edge["summary"] = f"{edge.get('from')} calls {edge.get('to')}"
                    elif edge.get("type") == "connects":
                        edge["summary"] = f"{edge.get('from')} connects to {edge.get('to')}"

                for lang, label in [("Python", "Python"), ("Jac Language", "Jac")]:
                    combined_snippet = ""
                    for module in result.get("modules", []):
                        if module.get("language") == lang:
                            try:
                                with open(module.get("file_path"), "r", encoding="utf-8") as f:
                                    combined_snippet += f.read() + "\n\n"
                            except Exception as e:
                                print(f"Could not read {module.get('file_path')}: {e}")


                #Run LLM only if Jac or python code exists
                if combined_snippet.strip():
                    try:
                        # 3️⃣ LLM semantic inference
                        @by(model=llm)
                        def infer_semantic_edges(entities, edges, snippet):
                            prompt = f"""
                            You are analyzing {lang} code for relationships.
                            Entities: {json.dumps(entities[:10], indent=2)}
                            Current Edges: {json.dumps(edges[:10], indent=2)}
                            Code snippet:
                            ```
                            {snippet[:1000]}
                            ```
                            Analyze the code and infer additional logical edges like:
                            - walker → node (type: "controls" or "visits")
                            - function → function (type: "calls")
                            - node → node (type: "connects")

                            Respond with **only** a JSON array of edge dictionaries, no explanations.
                            Example:
                            [
                            {{"from": "init", "to": "User", "type": "controls", "language": "Jac Language", "file_path": "path/to/file.jac"}},
                            {{"from": "train", "to": "Dataset", "type": "connects", "language": "Jac Language", "file_path": "path/to/file.jac"}}
                            ]
                            """
                            return llm.chat(prompt)
                    
                        # Call Gemini via ByLLM to infer logical relationships
                        print("Running LLM semantic inference across collected Jac and Python code...")
                      
                        inferred = infer_semantic_edges(result["entities"], result["edges"], combined_snippet)
                        inferred = inferred.strip()
                      
                        if not inferred.strip():
                            raise RuntimeError("Empty LLM response — aborting further inference")


                        if not inferred:
                            raise ValueError("Empty LLM response")

                        # Clean up if the model wrapped JSON in Markdown or extra text
                        if "```" in inferred:
                            inferred = re.sub(r"```(?:json)?", "", inferred)
                            inferred = inferred.replace("```", "").strip()

                        # Try to parse JSON safely
                        try:
                            inferred_edges = json.loads(inferred)
                        except json.JSONDecodeError as e:
                            print(f"JSON parse error from LLM: {e}")
                            print("Attempting to recover partial JSON output...")
                            inferred_fixed = re.findall(r"\{[^{}]+\}", inferred)
                            inferred_edges = [json.loads(x) for x in inferred_fixed if x.strip().endswith("}")]

                        # Normalize output shape — handle dicts or lists
                        if isinstance(inferred_edges, dict):
                            # LLM sometimes wraps output like {"entities": [...], "edges": [...]}
                            if "edges" in inferred_edges:
                                inferred_edges = inferred_edges["edges"]
                            elif "relations" in inferred_edges:
                                inferred_edges = inferred_edges["relations"]
                            else:
                                print("Unexpected JSON structure from LLM, no 'edges' key found.")
                                inferred_edges = []

                        # Only keep valid edge dicts
                        if isinstance(inferred_edges, list):
                            valid_edges = [e for e in inferred_edges if isinstance(e, dict)]
                            if valid_edges:
                                print(f"Successfully recovered {len(valid_edges)} semantic Python edges")
                                result["edges"].extend(valid_edges)
                            else:
                                print("No valid JSON edge objects found in LLM output.")
                        else:
                            print(f"Unexpected LLM output type: {type(inferred_edges)} — skipping.")
                    except Exception as e:
                        print(f"LLM inference error for {lang}: {e}")    

                    #Normalize Jac LLM edges to CCG format
                    normalized_edges = []
                    for e in valid_edges:
                        if not isinstance(e, dict):
                            continue

                        from_key = e.get("from") or e.get("source")
                        to_key = e.get("to") or e.get("target")
                        edge_type = e.get("type") or e.get("relation")
                        file_path = e.get("file_path") or file_path 

                        if not (from_key and to_key and edge_type):
                            print(f"Skipping malformed edge: {e}")
                            continue

                        normalized_edges.append({
                            "from": from_key,
                            "to": to_key,
                            "type": edge_type,
                            "language": "Jac Language",
                            "file_path": file_path,
                            "summary": f"{from_key} {edge_type} {to_key}"
                        })

                    if normalized_edges:
                        print(f"Normalized {len(normalized_edges)} Jac edges to CCG schema")
                        result["edges"].extend(normalized_edges)
                    else:
                        print("No valid Jac edges to extend after normalization.")
           

        # ===== Save analysis =====
        #Final cleanup: remove duplicates and non-informative edges
        cleaned_edges = []
        seen = set()

        for e in result["edges"]:
            if not isinstance(e, dict):
                continue

            # Skip malformed or incomplete edges
            if not all(k in e for k in ("from", "to", "type")):
                continue

            # Skip edges inferred from non-code files
            if any(e.get("file_path", "").endswith(ext) for ext in (".md", ".txt")):
                continue

            # Skip generic meaningless edges
            if e["type"].lower() in {"edge", "link", "relation"}:
                continue

            key = (e["from"], e["to"], e["type"])
            if key not in seen:
                cleaned_edges.append(e)
                seen.add(key)

        result["edges"] = cleaned_edges
        print(f"Cleaned and deduplicated to {len(cleaned_edges)} valid Jac edges")

        # ===== Save analysis =====
        root_dir = "code_analysis"
        os.makedirs(root_dir, exist_ok=True)

        repo_dir = os.path.join(root_dir, repo_name)
        os.makedirs(repo_dir, exist_ok=True)

        analysis_file = os.path.join(repo_dir, f"{repo_name}_ccg.json") 

        #Check if file exists before saving
        if not os.path.exists(analysis_file):
            try:
                with open(analysis_file, "w", encoding="utf-8") as f:
                    json.dump(result, f, indent=2, ensure_ascii=False)
                print(f"Code analysis saved at: {analysis_file}")
            except Exception as e:
                print(f"Failed to save code analysis: {e}")
        else:
            print(f"Code analysis already exists at: {analysis_file}")

        #Always store the path reference
        self.ccg_path = analysis_file
        ::py::


        print(f"Code analysis completed for repo: {self.repo_name}");
        disengage;
    }

}


# ================================
# Walker: GetFileTree
# Builds file structure JSON
# ================================
walker GetFileTree{
    has file_repo_url: str = '';
    has file_name: str = '';
    has file_path: str = '';

    can start with UserUrl entry{
        print('================Creating walker to get FileTree info==========');
        visit[-->];
    }
    can getfiletree with RepoInfoNode entry{
        self.file_repo_url = here.repo_url;
        self.file_name = here.repo_name;
        self.file_path = here.project_path; 
        print(f"📁 Working on repo: {self.file_name} at {self.file_path}");

        ::py::
        import os, json

        base_path = self.file_path
        repo_name = self.file_name or os.path.basename(base_path.rstrip(os.sep))
        
        skip_dirs = {
            '.git', '__pycache__', '.vscode', '.venv',
            '.idea', '.github', 'node_modules', 'dist', 'build'
        }

        def build_tree(path, skip_dirs=None):
            import os
            if skip_dirs is None:
                skip_dirs = {
                    '.git', '__pycache__', '.vscode', '.venv',
                    '.idea', '.github', 'node_modules', 'dist', 'build'
                }
            tree = {}

            try:
                for root, dirs, files in os.walk(path):
                    # Skip unwanted directories
                    dirs[:] = [d for d in dirs if d not in skip_dirs]

                    # Figure out where we are relative to the base path
                    rel_path = os.path.relpath(root, path)
                    parts = rel_path.split(os.sep) if rel_path != "." else []
                    
                    # Navigate through the nested dict to the current level
                    sub_tree = tree
                    for part in parts:
                        sub_tree = sub_tree.setdefault(part, {})

                    # Add files under the current directory
                    for file in sorted(files):
                        sub_tree[file] = "file"

            except Exception as e:
                tree["__error__"] = str(e)

            return tree


        file_tree = {repo_name: build_tree(base_path)}

        # Define root directory for storing file trees
        root_dir = "filetree"
        os.makedirs(root_dir, exist_ok=True)

        # Create a subfolder for this specific repository
        project_dir = os.path.join(root_dir, repo_name)
        os.makedirs(project_dir, exist_ok=True)

        # Define the destination JSON file inside that folder
        destination = os.path.join(project_dir, f"{repo_name}_tree.json")

        # Save the file tree as JSON
        if os.path.exists(destination):
            print(f"File tree already exists at: {destination}")
            self.generated_tree_path = destination
        else:
            try:
                with open(destination, "w", encoding="utf-8") as f:
                    json.dump(file_tree, f, indent=2, ensure_ascii=False)
                self.generated_tree_path = destination
                print(f"File tree saved at: {destination}")
            except Exception as e:
                print(f"Failed to save file tree for {repo_name}: {e}")
        ::py::

        # Link FileTree node
        file_tree_node = FileTree(
            repo_url=self.file_repo_url,
            file_name=self.file_name,
            file_path=self.file_path,
            file_tree=self.generated_tree_path
        );
        here ++> file_tree_node;
        print(f"Linked FileTree node for repo: {file_tree_node.file_name}");
        print(f"FileTree generated for {file_tree_node.file_name}");
        print("Spawning CodeAnalyzer for repo analysis...");
        analyzer = here spawn CodeAnalyzer();
        print(f"Code analysis completed, saved at: {analyzer.ccg_path}"); 
        print(f"Code analysis complete for: {analyzer.repo_name} — file saved at: {analyzer.ccg_path}");
        disengage;
    }
}

# ================================
# Entry Walker: RepoMapper
# - Handles user input and orchestrates the flow
# ================================
walker RepoMapper {

    can start with `root entry {

        # === Python block: handle GitHub URL input ===
        ::py::
        import os
        import re
        from dotenv import load_dotenv

        load_dotenv()  # load environment variables

        if "GITHUB_URL" in os.environ:
            user_query_url = os.environ["GITHUB_URL"]
        else:
            while True:
                user_query_url = input("Kindly provide a valid GitHub repo URL: ").strip()

                if not user_query_url:
                    print("Kindly input a string.")
                    continue

                if not re.match(
                    r"^https?://(www\.)?github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/?$",
                    user_query_url,
                ):
                    print("This isn’t a valid GitHub URL. Try again.")
                    continue

                break
        print("=======Starting Codebase===========")
        print("=================Creating UserUrl node=====================")
        ::py::

        # === Jac block: create nodes and spawn walkers ===
        userurl_node = UserUrl(github_url=user_query_url);
        root ++> userurl_node;
        spawned_gitrepo = userurl_node spawn GetRepoDetail();
        d = userurl_node spawn GetRepoData();
        tree = userurl_node spawn GetFileTree();
    }
}

with entry:__main__ {
    load_dotenv();
    root spawn RepoMapper();
}

