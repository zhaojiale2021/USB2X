import os
import sys
import platform

def create_pre_commit_hook(script_path):
    root_dir = os.path.join(os.path.dirname(__file__), "../../")
    hook_path = os.path.join(root_dir,".git", "hooks", "pre-commit")
    python_cmd = ''
    if platform.system() == 'Linux':
        python_cmd = 'python3'
    else:
        # hook_content = f"#!/bin/sh\n{get_python_interpreter_path()} {script_path}\n"
        python_cmd = get_python_interpreter_path()
        script_path = script_path.replace('\\','/')
        python_cmd = python_cmd.replace('\\','/')
    hook_content = (
        '#!/bin/sh\n'
        'if [ -z "{script_path}" ]; then\n'
        '    {python_cmd} {script_path}\n'
        'else\n'
        '    echo "{script_path} not found"\n'
        'fi\n'
        ).format(script_path=script_path, python_cmd=python_cmd)


    print("current working directory: ", hook_path)
    with open(hook_path, "w") as hook_file:
        hook_file.write(hook_content)
    if platform.system() == 'Linux':
        os.chmod(hook_path, 0o755)  # Add execute permission on Unix-like systems

def get_python_interpreter_path():
    interpreter_path = sys.executable
    print(f"Python Interpreter Path: {interpreter_path}")
    return interpreter_path
    
if __name__ == "__main__":
    script_path = os.path.join("tools", "clang_format", "pre-commit.py")
    create_pre_commit_hook(script_path)
    print("pre-commit hook created successfully.")
    # get_python_interpreter_path()
    