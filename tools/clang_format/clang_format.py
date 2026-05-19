import os
import subprocess
import time
import platform
from concurrent.futures import ThreadPoolExecutor
def format_cpp_files(directory, exclude_paths):

    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith(('.cpp', '.hpp','.h', '.c')):
                file_path = os.path.join(root, file)
                if all(exclude_path not in file_path for exclude_path in exclude_paths):
                    format_cpp_file(file_path)
def format_cpp_files_parallel(directory, exclude_paths):

    # Function to check and format a single file
    def process_file(file_path):
        if all(exclude_path not in file_path for exclude_path in exclude_paths):
            format_cpp_file(file_path)

    # Use ThreadPoolExecutor to parallelize formatting
    with ThreadPoolExecutor() as executor:
        for root, dirs, files in os.walk(directory):
            for file in files:
                if file.endswith(('.cpp', '.hpp', '.h', '.c')):
                    file_path = os.path.join(root, file)
                    executor.submit(process_file, file_path)
def format_cpp_file(file_path):
    try:
        subprocess.run([clang_format_cmd, '-i','-style=file', file_path], check=True)
        print(f"Formatted: {file_path}")
    except subprocess.CalledProcessError as e:
        print(f"Error formatting {file_path}: {e}")

if __name__ == "__main__":
    
    if platform.system().lower() == 'windows':
        clang_format_cmd = os.path.abspath(os.path.join(os.path.dirname(__file__), "./clang-format.exe"))
    elif platform.system().lower() == 'linux':
        clang_format_cmd = 'clang-format'

    root_dir = os.path.join(os.path.dirname(__file__), "../../")
    clang_format_style_file = os.path.join(root_dir, "./.clang-format")
    target_directory = os.path.abspath(root_dir)
    exclude_paths = [os.path.join(target_directory, "./build"),
                        os.path.join(target_directory, "./.git"),
                        os.path.join(target_directory, "./.vscode"),
                        os.path.join(target_directory, "./Drivers"),
                        os.path.join(target_directory, "./Middlewares"),
                    ]  
    start_time = time.time()
    absolute_exclude_paths = [os.path.abspath(exclude_path) for exclude_path in exclude_paths]
    # format_cpp_files(target_directory, absolute_exclude_paths)
    format_cpp_files_parallel(target_directory, absolute_exclude_paths)
    print("path format success!!! ", os.path.abspath(root_dir))
    print(f"Time taken: %.3f s" % (time.time() - start_time))