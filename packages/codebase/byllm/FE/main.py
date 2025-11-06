import streamlit as st
import os
import subprocess

# Absolute path to the Jac backend folder
be_path = "/home/willan/codebase/byllm/BE"

st.title("ByLLM Repo Analyzer 🌲")

# User input
github_url = st.text_input("Enter a GitHub repo URL:")

if st.button("Analyze Repo"):
    if not github_url:
        st.warning("Please provide a GitHub URL")
    elif not github_url.startswith("https://github.com/"):
        st.warning("Invalid GitHub URL")
    else:
        # Set environment variable for Jac runtime
        os.environ["GITHUB_URL"] = github_url

        st.info(f"Running analysis on: {github_url}")

        # Call Jac runtime from BE folder
        try:
            result = subprocess.run(
                ["jac", "run", "mainn.jac"],  # just the filename
                cwd=be_path,                  # set working directory to BE
                capture_output=True,
                text=True,
                check=True
            )
            st.success("Analysis complete!")
            st.code(result.stdout, language="text")

        except subprocess.CalledProcessError as e:
            st.error("Jac runtime failed:")
            st.code(e.stderr, language="text")

        # Optionally read generated README
        repo_name = github_url.rstrip("/").split("/")[-1]
        readme_path = f"readme_files/{repo_name}/README.md"
        if os.path.exists(readme_path):
            st.markdown("### Generated README")
            with open(readme_path, "r", encoding="utf-8") as f:
                st.code(f.read())
        else:
            st.warning("No README generated yet.")
