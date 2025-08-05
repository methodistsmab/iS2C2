import os
import time
from datetime import datetime
import argparse
from ollama import chat
import markdown
from html import escape

def read_file_content(filepath):
    """Read file content with detailed error reporting"""
    print(f"Attempting to read: {filepath}")
    
    if not os.path.exists(filepath):
        error_msg = f"File does not exist: {filepath}"
        print(error_msg)
        return error_msg, 0
    
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
            file_size = len(content)
            print(f"Successfully read {file_size} characters from {os.path.basename(filepath)}")
            return content, file_size
    except Exception as e:
        error_msg = f"Error reading {filepath}: {e}"
        print(error_msg)
        return error_msg, 0

def estimate_tokens(text):
    """Estimate token count (rough approximation: 1 token ≈ 4 characters for English)"""
    return len(text) // 4

def check_context_limits(content1, content2, max_context=131072):
    """Check if content fits within context limits"""
    total_chars = len(content1) + len(content2)
    estimated_tokens = estimate_tokens(content1 + content2)
    
    print(f"\n=== Context Analysis ===")
    print(f"Total content characters: {total_chars:,}")
    print(f"Estimated tokens: {estimated_tokens:,}")
    print(f"Context limit: {max_context:,} tokens")
    print(f"Context usage: {(estimated_tokens/max_context)*100:.1f}%")
    
    if estimated_tokens > max_context:
        print("⚠️  WARNING: Content may exceed context limit!")
        return False
    else:
        print("✅ Content should fit within context limit")
        return True

def chatgpt_response_to_html(text, support_markdown=True):
    """
    Convert ChatGPT API response to HTML.
    Args:
        text (str): Raw ChatGPT response.
        support_markdown (bool): Whether to parse markdown or just escape HTML.
    Returns:
        str: HTML formatted content.
    """
    if support_markdown:
        html = markdown.markdown(text, extensions=["fenced_code", "tables"])
    else:
        html = f"<pre>{escape(text)}</pre>"
    return html

# Parse command line arguments
parser = argparse.ArgumentParser(description="Run Ollama LLM prompt with dynamic cell and disease context.")
parser.add_argument('--cell', type=str, default='astrocyte-excitatory neuron', 
                   help='Cell-cell communication type (e.g., astrocyte-excitatory neuron)')
parser.add_argument('--disease', type=str, default="Alzheimer's disease", 
                   help='Disease context (e.g., Alzheimer\'s disease)')
parser.add_argument('--model', type=str, default='llama3.2',
                   help='Ollama model to use (default: llama3.2). Examples: gemma3:1b, qwq, deepseek-r1, llama4:scout, llama3.2-vision, phi4, mistral, etc.')
parser.add_argument('--significant-branches-file', type=str, default='./LLM_significant_branches.csv',
                   help='Path to significant_branches.txt file (for s2c2 algorithm)')
parser.add_argument('--liana-result', type=str, default='./liana_result.csv',
                   help='Path to liana result file (for lianaplus algorithm)')
parser.add_argument('--temperature', type=float, default=0.4,
                   help='Model temperature (default: 0.7)')
parser.add_argument('--max-tokens', type=int, default=1500,
                   help='Maximum tokens to generate (default: 1500)')
parser.add_argument('--context-size', type=int, default=131072,
                   help='Context window size (default: 131072)')
parser.add_argument('--seed', type=int, default=512,
                   help='Random seed for reproducible outputs (default: 512)')
parser.add_argument('--prompt', type=str, default='enhanced-few-shot', help='Prompt type: enhanced-few-shot (default) or simple-zero-shot')
parser.add_argument('--algorithm', type=str, default='s2c2', choices=['s2c2', 'lianaplus', 'nichenet'],
                   help='Algorithm to use for hypothesis generation: s2c2 (default), lianaplus, or nichenet')
parser.add_argument('--lr-file', type=str, default=None, help='Path to LR.csv file (for nichenet algorithm)')
parser.add_argument('--lt-file', type=str, default=None, help='Path to LT.csv file (for nichenet algorithm)')
parser.add_argument('--results-dir', type=str, default='.',
                   help='Directory to save output files (default: current directory)')

args = parser.parse_args()

# ============================================================================
# STRICT PARAMETER VALIDATION
# ============================================================================

# Validate required parameters
if not args.cell:
    print("❌ Error: --cell parameter is required")
    exit(1)

if not args.disease:
    print("❌ Error: --disease parameter is required")
    exit(1)

# Validate algorithm-specific required parameters
if args.algorithm == "s2c2":
    if not args.significant_branches_file:
        print("❌ Error: --significant-branches-file is required for s2c2 algorithm")
        exit(1)
elif args.algorithm == "lianaplus":
    if not args.liana_result:
        print("❌ Error: --liana-result is required for lianaplus algorithm")
        exit(1)
elif args.algorithm == "nichenet":
    if not args.lr_file:
        print("❌ Error: --lr-file is required for nichenet algorithm")
        exit(1)
    if not args.lt_file:
        print("❌ Error: --lt-file is required for nichenet algorithm")
        exit(1)

# Validate file existence for algorithm-specific files
if args.algorithm == "s2c2":
    if not os.path.exists(args.significant_branches_file):
        print(f"❌ Error: File not found: {args.significant_branches_file}")
        exit(1)
elif args.algorithm == "lianaplus":
    if not os.path.exists(args.liana_result):
        print(f"❌ Error: File not found: {args.liana_result}")
        exit(1)
elif args.algorithm == "nichenet":
    if not os.path.exists(args.lr_file):
        print(f"❌ Error: File not found: {args.lr_file}")
        exit(1)
    if not os.path.exists(args.lt_file):
        print(f"❌ Error: File not found: {args.lt_file}")
        exit(1)

print("✅ All required parameters validated successfully!")

# Get parameters from arguments
model_name = args.model
temperature = args.temperature
max_tokens = args.max_tokens
context_size = args.context_size
seed = args.seed

# Determine context limit based on model (similar to Gemini script)
# Note: These are approximate limits for common Ollama models
context_limits = {
    'llama3.2': 131072,
    'llama3.2-vision': 131072,
    'llama4:scout': 131072,
    'llama4': 131072,
    'llama3.1': 131072,
    'llama3.1-vision': 131072,
    'gemma3:1b': 8192,
    'gemma3:2b': 8192,
    'gemma3:7b': 8192,
    'deepseek-r1': 32768,
    'deepseek-coder': 32768,
    'phi4': 32768,
    'mistral': 32768,
    'mixtral': 32768,
    'codellama': 32768,
    'qwq': 131072,
    'qwen': 32768,
    'yi': 32768
}

# Use model-specific context limit if available, otherwise use provided context_size
if model_name in context_limits:
    suggested_context = context_limits[model_name]
    if context_size > suggested_context:
        print(f"⚠️  Warning: Requested context size ({context_size:,}) exceeds suggested limit for {model_name} ({suggested_context:,})")
        print(f"   Using requested context size: {context_size:,}")
    else:
        print(f"✅ Context size ({context_size:,}) is within suggested limit for {model_name} ({suggested_context:,})")
else:
    print(f"ℹ️  No specific context limit found for model '{model_name}', using provided context size: {context_size:,}")

# Get file paths from arguments
file2_path = args.significant_branches_file
lr_file = args.lr_file
lt_file = args.lt_file

# Get cell and disease context from arguments
cell = args.cell
disease = args.disease

# Generate dynamic output filename
def sanitize_filename_component(component):
    """Sanitize a component for use in filename by replacing problematic characters"""
    # Replace spaces, special characters, and other problematic characters
    sanitized = component.replace(' ', '_').replace('-', '_').replace("'", '').replace('"', '')
    sanitized = sanitized.replace('(', '').replace(')', '').replace('[', '').replace(']', '')
    sanitized = sanitized.replace('{', '').replace('}', '').replace('/', '_').replace('\\', '_')
    sanitized = sanitized.replace(':', '').replace(';', '').replace(',', '').replace('.', '')
    return sanitized

# Generate the dynamic output filename
cell_sanitized = sanitize_filename_component(cell)
disease_sanitized = sanitize_filename_component(disease)
model_sanitized = sanitize_filename_component(model_name)
temperature_str = str(temperature).replace('.', 'p')  # Convert 0.7 to 0p7
max_tokens_str = str(max_tokens)
seed_str = str(seed) if seed is not None else "random"

# Add timestamp to filename
timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")  # Format: 20241201_143052

# Always include algorithm in output file name
output_file = f"llm_report_ollama_{cell_sanitized}_{disease_sanitized}_{model_sanitized}_{args.algorithm}_{timestamp}.html"

# Use results-dir if provided, otherwise create timestamp directory
if args.results_dir and args.results_dir != '.':
    output_file = os.path.join(args.results_dir, os.path.basename(output_file))
else:
    # Create timestamp directory in results folder
    timestamp_dir = f"results/run_{timestamp}"
    os.makedirs(timestamp_dir, exist_ok=True)
    output_file = os.path.join(timestamp_dir, os.path.basename(output_file))
    print(f"Created timestamp directory: {timestamp_dir}")
    print(f"Output file will be saved to: {output_file}")

# Parse cell type to extract sender and receiver
def parse_cell_type(cell_string):
    """Parse cell type string to extract sender and receiver cell types"""
    if '-' in cell_string:
        parts = cell_string.split('-', 1)  # Split on first '-' only
        sender_var = parts[0].strip()
        receiver_var = parts[1].strip()
        return sender_var, receiver_var
    else:
        # If no '-' found, treat the whole string as sender and use a default receiver
        print(f"Warning: No '-' found in cell type '{cell_string}'. Using default receiver.")
        return cell_string.strip(), "receiver cell"
    
sender_var, receiver_var = parse_cell_type(cell)
print(f"Parsed cell types - Sender: '{sender_var}', Receiver: '{receiver_var}'")

start_time = time.time()
start_datetime = datetime.now()
print(f"=== Analysis Started at {start_datetime.strftime('%Y-%m-%d %H:%M:%S')} ===\n")

print("Reading files...")
print(f"Algorithm: {args.algorithm}")
print(f"Model: {model_name}")
print(f"Temperature: {temperature}")
print(f"Max tokens: {max_tokens}")
print(f"Context size: {context_size}")
print(f"Seed: {seed}")
print(f"Output file: {output_file}")
print("")

# Initialize variables
significant_branches_content = ""
file2_size = 0
liana_result_content = ""
liana_result_size = 0
lr_content = ""
lr_size = 0
lt_content = ""
lt_size = 0

# Read files based on algorithm
if args.algorithm == "s2c2":
    print(f"Reading files for s2c2 algorithm:")
    print(f"  - Significant branches file: {file2_path}")
    
    significant_branches_content, file2_size = read_file_content(file2_path)
    
    total_content = significant_branches_content
    context_ok = check_context_limits(total_content, "", max_context=context_size)
    
elif args.algorithm == "lianaplus":
    print(f"Reading files for lianaplus algorithm:")
    print(f"  - Liana result file: {args.liana_result}")
    
    liana_result_content, liana_result_size = read_file_content(args.liana_result)
    
    total_content = liana_result_content
    context_ok = check_context_limits(total_content, "", max_context=context_size)
    
elif args.algorithm == "nichenet":
    print(f"Reading files for nichenet algorithm:")
    print(f"  - LR file: {lr_file}")
    print(f"  - LT file: {lt_file}")
    
    if not lr_file or not lt_file:
        print("❌ Error: --lr-file and --lt-file must be provided for nichenet algorithm")
        exit(1)
    
    lr_content, lr_size = read_file_content(lr_file)
    lt_content, lt_size = read_file_content(lt_file)
    
    total_content = lr_content + lt_content
    context_ok = check_context_limits(total_content, "", max_context=context_size)

print("\n=== File Content Preview ===")
if args.algorithm in ["s2c2", "lianaplus"]:
    print(f"\nsignificant_branches.txt preview (first 300 chars):\n{significant_branches_content[:300]}...")
elif args.algorithm == "nichenet":
    print(f"\nLR.csv preview (first 300 chars):\n{lr_content[:300]}...")
    print(f"\nLT.csv preview (first 300 chars):\n{lt_content[:300]}...")

# Check for errors in read files
error_files = []
if args.algorithm == "s2c2":
    if "Error" in significant_branches_content:
        error_files.append("significant_branches.txt")
elif args.algorithm == "lianaplus":
    if "Error" in liana_result_content:
        error_files.append("liana_result.csv")
elif args.algorithm == "nichenet":
    if "Error" in lr_content:
        error_files.append("LR.csv")
    if "Error" in lt_content:
        error_files.append("LT.csv")

if error_files:
    print(f"\n❌ Error reading files: {', '.join(error_files)}. Aborting...")
    exit(1)

request_start_time = time.time()

# Prepare the content for Ollama API based on algorithm
system_prompt = "You are a systems biologist specializing in cell-cell communication and neurodegenerative diseases."

if args.algorithm == "s2c2":
    user_content = f"Based on the provided cell-cell crosstalk data file {significant_branches_content} between {cell} communication in {disease}, generate three biologically meaningful hypotheses to investigate by predicting the top 3 ligand-receptor pairs with an associated downstream pathway branch to target based on the data, and your background biological knowledge."

elif args.algorithm == "lianaplus":
    user_content = f"Based on the provided cell-cell crosstalk data file {liana_result_content} between {cell} communication in {disease}, generate three biologically meaningful hypotheses to investigate by predicting the top 3 ligand-receptor pairs with an associated downstream pathway branch to target based on the data, and your background biological knowledge."

elif args.algorithm == "nichenet":
    user_content = (
        f"Based on the provided cell-cell crosstalk data files {os.path.basename(lr_file)}, {os.path.basename(lt_file)} "
        f"between {cell} communication in {disease}, generate three biologically meaningful hypotheses to investigate "
        f"by predicting the top 3 ligand-receptor pairs with an associated downstream pathway branch to target based on the data, "
        f"and your background biological knowledge.\n\n"
        f"=== {os.path.basename(lr_file)} Content ({lr_size:,} characters) ===\n{lr_content}\n\n"
        f"=== {os.path.basename(lt_file)} Content ({lt_size:,} characters) ===\n{lt_content}\n"
    )

messages = [
    {
        "role": "system",
        "content": system_prompt
    },
    {
        "role": "user",
        "content": user_content
    }
]

print(f"\n=== Request Details ===")
print(f"Model: {model_name}")
print(f"Context size: {context_size:,} tokens")
print(f"Temperature: {temperature}")
print(f"Max tokens: {max_tokens}")
print(f"Seed: {seed}")
print(f"Algorithm: {args.algorithm}")
print(f"Cell type: {cell}")
print(f"Disease context: {disease}")

# Calculate total content size based on algorithm
if args.algorithm == "s2c2":
    total_chars = file2_size
elif args.algorithm == "lianaplus":
    total_chars = liana_result_size
elif args.algorithm == "nichenet":
    total_chars = lr_size + lt_size

print(f"Total content size: {total_chars:,} characters")
print(f"Request build time: {time.time() - request_start_time:.2f} seconds")

print(f"\n=== Sending request to Ollama {model_name} ===")
ollama_start_time = time.time()

try:
    response = chat(
        model=model_name,
        messages=messages,
        options={
            "temperature": temperature,
            "num_predict": max_tokens,
            "num_ctx": context_size,
            "seed": seed
        },
        stream=False
    )
    ollama_end_time = time.time()
    ollama_duration = ollama_end_time - ollama_start_time

    # Enhanced response validation and diagnostics
    if not response:
        raise Exception("Received empty response from Ollama API")
    
    # The response object supports both dict and attribute access
    if hasattr(response, 'message'):
        result = response.message.content
    else:
        result = response['message']['content']
    
    if not result:
        print("\n⚠️  Warning: Ollama returned an empty response")
        print("This is likely due to:")
        print("1. Model unable to process the request")
        print("2. Input too long for the model")
        print("3. Model configuration issues")
        print("4. Temporary service issues")
        result = f"No content generated by Ollama API. Check the model configuration and input size."

    total_time = time.time() - start_time
    end_datetime = datetime.now()

    print(f"\n=== Timing Results ===")
    print(f"File reading time: {request_start_time - start_time:.2f} seconds")
    print(f"Ollama processing time: {ollama_duration:.2f} seconds")
    print(f"Total execution time: {total_time:.2f} seconds")
    print(f"Analysis completed at: {end_datetime.strftime('%Y-%m-%d %H:%M:%S')}")

    response_length = len(result)
    estimated_response_tokens = estimate_tokens(result)

    print(f"\n=== Response Quality Check ===")
    print(f"Response length: {response_length:,} characters")
    print(f"Estimated response tokens: {estimated_response_tokens:,}")
    print(f"Response seems complete: {'✅ Yes' if response_length > 1000 else '⚠️  Possibly truncated or empty'}")

    print(f"\n=== Content Inclusion Verification ===")
    pathway_mentioned = "pathway" in result.lower() or "branch" in result.lower()
    hypothesis_mentioned = "hypothesis" in result.lower() or "hypotheses" in result.lower()
    pas_mentioned = "pas" in result.lower() or "pathway activity score" in result.lower()
    step_mentioned = "step" in result.lower()

    print(f"Pathway data referenced: {'✅ Yes' if pathway_mentioned else '❌ No'}")
    print(f"Hypotheses generated: {'✅ Yes' if hypothesis_mentioned else '❌ No'}")
    print(f"PAS scores mentioned: {'✅ Yes' if pas_mentioned else '❌ No'}")
    print(f"Step-by-step analysis: {'✅ Yes' if step_mentioned else '❌ No'}")

    # Check if files were read successfully based on algorithm
    if args.algorithm == "s2c2":
        files_read_successfully = (file2_size > 0)
    elif args.algorithm == "lianaplus":
        files_read_successfully = (liana_result_size > 0)
    elif args.algorithm == "nichenet":
        files_read_successfully = (lr_size > 0 and lt_size > 0)
    else:
        files_read_successfully = False
    
    print(f"All files successfully read: {'✅ Yes' if files_read_successfully else '❌ Check file paths'}")

    # Save the LLM response to file
    try:
        print(f"\n=== Saving LLM Response ===")
        print(f"Writing response to: {output_file}")
        
        # Create output directory if it doesn't exist
        output_dir = os.path.dirname(output_file)
        if output_dir and not os.path.exists(output_dir):
            os.makedirs(output_dir, exist_ok=True)
            print(f"Created output directory: {output_dir}")
        
        # Convert the LLM response to HTML
        html_content = chatgpt_response_to_html(result, support_markdown=True)
        
        # Create HTML document with metadata
        html_document = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="Content-Security-Policy" content="style-src 'self' 'unsafe-inline';">
    <title>Ollama LLM Hypothesis Generation Report</title>
    <style>
        body {{
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            line-height: 1.6;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
        }}
        .container {{
            max-width: 1200px;
            margin: 0 auto;
            background-color: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }}
        h1 {{
            text-align: center;
            color: #2c3e50;
            border-bottom: 3px solid #3498db;
            padding-bottom: 10px;
            margin-bottom: 30px;
        }}
        h2 {{
            color: #34495e;
            border-left: 4px solid #3498db;
            padding-left: 15px;
            margin-top: 30px;
        }}
        h3 {{
            color: #2c3e50;
            margin-top: 25px;
        }}
        .metadata {{
            background-color: #ecf0f1;
            padding: 20px;
            border-radius: 8px;
            margin-bottom: 30px;
            border-left: 4px solid #3498db;
        }}
        .metadata h3 {{
            margin-top: 0;
            color: #2c3e50;
        }}
        .metadata-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 10px;
        }}
        .metadata-item {{
            background-color: white;
            padding: 10px;
            border-radius: 5px;
            border: 1px solid #bdc3c7;
        }}
        .metadata-label {{
            font-weight: bold;
            color: #7f8c8d;
            font-size: 0.9em;
        }}
        .metadata-value {{
            color: #2c3e50;
            margin-top: 5px;
        }}
        .content {{
            background-color: white;
            padding: 20px;
            border-radius: 8px;
            border: 1px solid #ecf0f1;
        }}
        pre {{
            background-color: #f8f9fa;
            padding: 15px;
            border-radius: 5px;
            overflow-x: auto;
            border: 1px solid #e9ecef;
        }}
        code {{
            background-color: #f8f9fa;
            padding: 2px 4px;
            border-radius: 3px;
            font-family: 'Courier New', monospace;
        }}
        table {{
            border-collapse: collapse;
            width: 100%;
            margin: 20px 0;
        }}
        th, td {{
            border: 1px solid #ddd;
            padding: 12px;
            text-align: left;
        }}
        th {{
            background-color: #f2f2f2;
            font-weight: bold;
        }}
        tr:nth-child(even) {{
            background-color: #f9f9f9;
        }}
        .file-info {{
            background-color: #e8f5e8;
            padding: 15px;
            border-radius: 5px;
            margin: 20px 0;
            border-left: 4px solid #27ae60;
        }}
        .timestamp {{
            text-align: center;
            color: #7f8c8d;
            font-style: italic;
            margin-top: 30px;
            padding-top: 20px;
            border-top: 1px solid #ecf0f1;
        }}
    </style>
</head>
<body>
    <div class="container">
        <h1>Ollama LLM Hypothesis Generation Report</h1>
        
        <div class="metadata">
            <h3>Analysis Parameters</h3>
            <div class="metadata-grid">
                <div class="metadata-item">
                    <div class="metadata-label">Generated at</div>
                    <div class="metadata-value">{end_datetime.strftime('%Y-%m-%d %H:%M:%S')}</div>
                </div>
                <div class="metadata-item">
                    <div class="metadata-label">Cell communication type</div>
                    <div class="metadata-value">{cell}</div>
                </div>
                <div class="metadata-item">
                    <div class="metadata-label">Disease context</div>
                    <div class="metadata-value">{disease}</div>
                </div>
                <div class="metadata-item">
                    <div class="metadata-label">Model</div>
                    <div class="metadata-value">{model_name}</div>
                </div>
                <div class="metadata-item">
                    <div class="metadata-label">Temperature</div>
                    <div class="metadata-value">{temperature}</div>
                </div>
                <div class="metadata-item">
                    <div class="metadata-label">Max tokens</div>
                    <div class="metadata-value">{max_tokens}</div>
                </div>
                <div class="metadata-item">
                    <div class="metadata-label">Context size</div>
                    <div class="metadata-value">{context_size:,} tokens</div>
                </div>
                <div class="metadata-item">
                    <div class="metadata-label">Seed</div>
                    <div class="metadata-value">{seed}</div>
                </div>
                <div class="metadata-item">
                    <div class="metadata-label">Algorithm</div>
                    <div class="metadata-value">{args.algorithm}</div>
                </div>
                <div class="metadata-item">
                    <div class="metadata-label">Processing time</div>
                    <div class="metadata-value">{ollama_duration:.2f} seconds</div>
                </div>
                <div class="metadata-item">
                    <div class="metadata-label">Response length</div>
                    <div class="metadata-value">{response_length:,} characters</div>
                </div>
                <div class="metadata-item">
                    <div class="metadata-label">Estimated tokens</div>
                    <div class="metadata-value">{estimated_response_tokens:,}</div>
                </div>
            </div>
        </div>

        <div class="file-info">
            <h3>Input Files Processed</h3>"""
        
        if args.algorithm == "s2c2":
            html_document += f"""
            <p><strong>Significant branches file:</strong> {file2_path} ({file2_size:,} chars)</p>"""
        elif args.algorithm == "lianaplus":
            html_document += f"""
            <p><strong>Liana result file:</strong> {args.liana_result} ({liana_result_size:,} chars)</p>"""
        elif args.algorithm == "nichenet":
            html_document += f"""
            <p><strong>LR file:</strong> {lr_file} ({lr_size:,} chars)</p>
            <p><strong>LT file:</strong> {lt_file} ({lt_size:,} chars)</p>"""
        
        html_document += f"""
            <p><strong>Total content processed:</strong> {total_chars:,} characters</p>
        </div>

        <div class="content">
            <h2>Ollama LLM Response</h2>
            {html_content}
        </div>

        <div class="timestamp">
            Report generated on {end_datetime.strftime('%Y-%m-%d at %H:%M:%S')}
        </div>
    </div>
</body>
</html>"""
        
        # Write the HTML document
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(html_document)
        
        print(f"✅ Successfully saved LLM response to: {output_file}")
        print(f"   File size: {os.path.getsize(output_file):,} bytes")
        
    except Exception as e:
        print(f"❌ Error saving LLM response to file: {e}")
        print("   Response will only be displayed in console")
    
    print("\n=== Ollama Response ===")
    print(result)

except Exception as e:
    print(f"❌ Error communicating with Ollama: {e}")
    print(f"Error type: {type(e).__name__}")
    print(f"Error details: {str(e)}")
    
    # Provide more specific error guidance
    if "Connection" in str(e) or "timeout" in str(e).lower():
        print("\n💡 Troubleshooting suggestions:")
        print("1. Check if Ollama service is running: ollama serve")
        print("2. Verify the model is installed: ollama list")
        print("3. Check network connectivity")
    elif "model" in str(e).lower():
        print("\n💡 Troubleshooting suggestions:")
        print("1. Verify the model name is correct: ollama list")
        print("2. Install the model if needed: ollama pull <model_name>")
        print("3. Check model compatibility with your Ollama version")
    elif "context" in str(e).lower() or "token" in str(e).lower():
        print("\n💡 Troubleshooting suggestions:")
        print("1. Reduce the context size or input length")
        print("2. Try a model with larger context window")
        print("3. Split the input into smaller chunks")
    
    # Save error message to file
    try:
        error_html = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="Content-Security-Policy" content="style-src 'self' 'unsafe-inline';">
    <title>Ollama LLM Error Report</title>
    <style>
        body {{
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            line-height: 1.6;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
        }}
        .container {{
            max-width: 800px;
            margin: 0 auto;
            background-color: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }}
        h1 {{
            text-align: center;
            color: #e74c3c;
            border-bottom: 3px solid #e74c3c;
            padding-bottom: 10px;
            margin-bottom: 30px;
        }}
        .error-info {{
            background-color: #fdf2f2;
            padding: 20px;
            border-radius: 8px;
            margin-bottom: 30px;
            border-left: 4px solid #e74c3c;
        }}
        .error-item {{
            margin-bottom: 15px;
        }}
        .error-label {{
            font-weight: bold;
            color: #c0392b;
        }}
        .error-value {{
            color: #2c3e50;
            margin-top: 5px;
            font-family: 'Courier New', monospace;
            background-color: #f8f9fa;
            padding: 5px;
            border-radius: 3px;
        }}
        .timestamp {{
            text-align: center;
            color: #7f8c8d;
            font-style: italic;
            margin-top: 30px;
            padding-top: 20px;
            border-top: 1px solid #ecf0f1;
        }}
    </style>
</head>
<body>
    <div class="container">
        <h1>❌ LLM Request Failed - Ollama Error</h1>
        
        <div class="error-info">
            <div class="error-item">
                <div class="error-label">Timestamp</div>
                <div class="error-value">{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}</div>
            </div>
            <div class="error-item">
                <div class="error-label">Error Type</div>
                <div class="error-value">{type(e).__name__}</div>
            </div>
            <div class="error-item">
                <div class="error-label">Error Message</div>
                <div class="error-value">{str(e)}</div>
            </div>
            <div class="error-item">
                <div class="error-label">Model</div>
                <div class="error-value">{model_name}</div>
            </div>
            <div class="error-item">
                <div class="error-label">Algorithm</div>
                <div class="error-value">{args.algorithm}</div>
            </div>
            <div class="error-item">
                <div class="error-label">Context Size</div>
                <div class="error-value">{context_size:,} tokens</div>
            </div>
            <div class="error-item">
                <div class="error-label">Max Tokens</div>
                <div class="error-value">{max_tokens}</div>
            </div>
        </div>

        <div class="timestamp">
            Error report generated on {datetime.now().strftime('%Y-%m-%d at %H:%M:%S')}
        </div>
    </div>
</body>
</html>"""
        
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(error_html)
    except:
        pass

print(f"\n=== Analysis Summary ===")
print(f"Start time: {start_datetime.strftime('%Y-%m-%d %H:%M:%S')}")
print(f"End time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
print(f"Total duration: {time.time() - start_time:.2f} seconds")
print(f"Files processed: ")
if args.algorithm == "s2c2":
    print(f"  - {os.path.basename(file2_path)} ({file2_size:,} chars)")
elif args.algorithm == "lianaplus":
    print(f"  - {os.path.basename(args.liana_result)} ({liana_result_size:,} chars)")
elif args.algorithm == "nichenet":
    print(f"  - {os.path.basename(lr_file)} ({lr_size:,} chars)")
    print(f"  - {os.path.basename(lt_file)} ({lt_size:,} chars)")
print(f"  - Total: {total_chars:,} characters")
print(f"Algorithm: {args.algorithm}")
print(f"Output file: {output_file}")
