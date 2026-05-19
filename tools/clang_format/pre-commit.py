#!/usr/bin/env python
import subprocess
import sys
import platform
import os
def format_cpp_files(format_files):
    run_format_files = []
    for file_path in format_files:
        if file_path.endswith(('.cpp', '.hpp', '.h', '.c')):
            format_cpp_file(file_path)
            run_format_files.append(file_path)
    return run_format_files
def format_cpp_file(file_path):
    if platform.system().lower() == 'windows':
        clang_format_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "./clang-format.exe"))
    elif platform.system().lower() == 'linux':
        clang_format_path = 'clang-format'

    try:
        subprocess.run([clang_format_path, '-i','-style=file', file_path], check=True)
        print(f"Formatted: {file_path}")
    except subprocess.CalledProcessError as e:
        print(f"Error formatting {file_path}: {e}")

def git_get_staged_files(root_dir,exclude_paths):
    git_cmd = ['git', 'diff', '--cached', '--name-only']
    result = subprocess.run(git_cmd, stdout=subprocess.PIPE, text=True)
    diff_files = result.stdout.splitlines()
    # print("staged_files: ", diff_files)
    pre_staged_files = [os.path.abspath(os.path.join(root_dir, staged_file)) for staged_file in diff_files]
    staged_files = []
    for staged_file in pre_staged_files:
        if all((exclude_path not in staged_file)
                and os.path.isfile(staged_file)
                for exclude_path in exclude_paths):
            staged_files.append(staged_file)
    return staged_files, pre_staged_files

def git_stage_files(files):
    git_add_cmd = ['git', 'add'] + files
    # print("git_add_cmd: ", git_add_cmd)
    # print(git_add_cmd)
    subprocess.run(git_add_cmd, check=True)
def git_save_commit_id_to_file(log_file):
    git_cmd_list = [['git', 'config', 'user.name'],
                    ['git', 'rev-parse', '--abbrev-ref', 'HEAD'],
                    ['git', 'rev-parse', 'HEAD'],
                    ['git', 'submodule', 'foreach', 'git', 'rev-parse', '--abbrev-ref', 'HEAD'],
                    ['git', 'submodule', 'foreach', 'git', 'rev-parse', 'HEAD']]
    git_log = ''
    for git_cmd in git_cmd_list:
        result = subprocess.run(git_cmd, stdout=subprocess.PIPE, text=True)
        git_log += result.stdout + '--------------------------------------------------------------------------------\n'
    # print(git_log)
    with open(log_file, "w") as f:
        f.write(git_log)
def format_commit_files(staged_files, log_file):
    if not staged_files:
        return

    try:
        format_files = format_cpp_files(staged_files)
        # format_files.append(log_file)
        add_files = [(os.path.relpath(staged_file,root_dir)).replace('\\', '/') for staged_file in format_files]
        git_stage_files(add_files)
    except subprocess.CalledProcessError:
        print("Error: clang-format failed. Please check the formatting.")
        sys.exit(1)

def file_in_paths(paths, files):
    for file in files:
        for path in paths:
            if path in file:
                return True, file
    return False, None

def files_in_target_files(files, target_files):
    real_target_files = [target_file for target_file in target_files if os.path.isfile(target_file)]
    for file in files:
        if file not in real_target_files:
            return False
    return True


if __name__ == "__main__":
    root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../"))
    git_commit_id_file = os.path.abspath(os.path.join(root_dir, "git_commit_id.txt"))
    exclude_paths = [os.path.join(root_dir, "./.vscode"),
                    os.path.join(root_dir, "./Drivers"),
                    os.path.join(root_dir, "./Middlewares"),
                    os.path.join(root_dir, "./toolchains"),
                    os.path.join(root_dir, "./tools"),
                ]
    absolute_exclude_paths = [os.path.abspath(exclude_path) for exclude_path in exclude_paths]
    # git_save_commit_id_to_file(git_commit_id_file)
    format_files,commit_files  = git_get_staged_files(root_dir, absolute_exclude_paths)
    print("commit_files: ", commit_files)
    format_commit_files(format_files, git_commit_id_file)