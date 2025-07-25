import os
import time
from datetime import datetime
import argparse
from ollama import chat

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

# Parse command line arguments
parser = argparse.ArgumentParser(description="Run Ollama LLM prompt with dynamic cell and disease context.")
parser.add_argument('--cell', type=str, default='astrocyte-excitatory neuron', 
                   help='Cell-cell communication type (e.g., astrocyte-excitatory neuron)')
parser.add_argument('--disease', type=str, default="Alzheimer's disease", 
                   help='Disease context (e.g., Alzheimer\'s disease)')
parser.add_argument('--model', type=str, default='llama3.2',
                   help='Ollama model to use (default: llama3.2). Examples: gemma3:1b, qwq, deepseek-r1, llama4:scout, llama3.2-vision, phi4, mistral, etc.')
parser.add_argument('--significant-branches-file', type=str, default='./LLM_significant_branches.csv',
                   help='Path to significant_branches.txt file')
parser.add_argument('--example1-file', type=str, default='./prompt/example1.txt',
                   help='Path to example1.txt file')
parser.add_argument('--example2-file', type=str, default='./prompt/example2.txt',
                   help='Path to example2.txt file')
parser.add_argument('--example3-file', type=str, default='./prompt/example3.txt',
                   help='Path to example3.txt file')
parser.add_argument('--temperature', type=float, default=0.7,
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

args = parser.parse_args()

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
example1_path = "./prompt/example1.txt"
example2_path = "./prompt/example2.txt"
example3_path = "./prompt/example3.txt"
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
output_file = f"llm_report_ollama_{cell_sanitized}_{disease_sanitized}_{model_sanitized}_{args.algorithm}_{timestamp}.txt"

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
example1_content = ""
example1_size = 0
example2_content = ""
example2_size = 0
example3_content = ""
example3_size = 0
lr_content = ""
lr_size = 0
lt_content = ""
lt_size = 0

# Read files based on algorithm
if args.algorithm == "s2c2":
    print(f"Reading files for s2c2 algorithm:")
    print(f"  - Significant branches file: {file2_path}")
    print(f"  - Example files: {example1_path}, {example2_path}, {example3_path}")
    
    significant_branches_content, file2_size = read_file_content(file2_path)
    example1_content, example1_size = read_file_content(example1_path)
    example2_content, example2_size = read_file_content(example2_path)
    example3_content, example3_size = read_file_content(example3_path)
    
    total_content = significant_branches_content + example1_content + example2_content + example3_content
    context_ok = check_context_limits(total_content, "", max_context=context_size)
    
elif args.algorithm == "lianaplus":
    print(f"Reading files for lianaplus algorithm:")
    print(f"  - Significant branches file: {file2_path}")
    
    significant_branches_content, file2_size = read_file_content(file2_path)
    
    total_content = significant_branches_content
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
if args.algorithm == "s2c2":
    print(f"\nsignificant_branches.txt preview (first 300 chars):\n{significant_branches_content[:300]}...")
    print(f"\nexample1.txt preview (first 200 chars):\n{example1_content[:200]}...")
    print(f"\nexample2.txt preview (first 200 chars):\n{example2_content[:200]}...")
    print(f"\nexample3.txt preview (first 200 chars):\n{example3_content[:200]}...")
elif args.algorithm == "lianaplus":
    print(f"\nsignificant_branches.txt preview (first 300 chars):\n{significant_branches_content[:300]}...")
elif args.algorithm == "nichenet":
    print(f"\nLR.csv preview (first 300 chars):\n{lr_content[:300]}...")
    print(f"\nLT.csv preview (first 300 chars):\n{lt_content[:300]}...")

# Check for errors in read files
error_files = []
if args.algorithm == "s2c2":
    if "Error" in significant_branches_content:
        error_files.append("significant_branches.txt")
    if "Error" in example1_content:
        error_files.append("example1.txt")
    if "Error" in example2_content:
        error_files.append("example2.txt")
    if "Error" in example3_content:
        error_files.append("example3.txt")
elif args.algorithm == "lianaplus":
    if "Error" in significant_branches_content:
        error_files.append("significant_branches.txt")
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
    user_content = f"""Here are the actual contents of my cell-cell crosstalk data files and example files:

## LLM_significant_branches.csv Content ({file2_size:,} characters)
{significant_branches_content}

## Example 1 ({example1_size:,} characters)
{example1_content}

=== Example 2 ({example2_size:,} characters) ===
{example2_content}

=== Example 3 ({example3_size:,} characters) ===
{example3_content}

# Analysis Request

## Ligand–Receptor Hypothesis Generation Prompt 
**{cell}-{disease}**

You are provided with a cell–cell crosstalk data file: `LLM_significant_branches.csv`

This file contains predicted **ligand–receptor (LR)** interactions and their downstream **Branch_path** signaling cascades between **{sender_var} (sender)** and **{receiver_var} (receiver)** in **{disease}**.

Your task is to generate **three distinct, biologically meaningful hypotheses**. Each hypothesis must be based on:

- A unique **ligand–receptor pair** (from the data)
- A valid **Branch_path** (from the data)
- A fully developed downstream mechanistic explanation, grounded in **{disease} biology**

## Step-by-Step Instructions

### Step 1: Filter Valid Ligand–Receptor Pairs

- Load LLM_significant_branches.csv Content.
- Extract only LR pairs that meet the following criteria:
  - The pair is present in the file.
  - The pair has a **non-null Pathway Activity Score (PAS)**.
  - The pair has a valid downstream **Branch_path** (genes separated by `___`).
- Then prioritize candidate LR pairs using composite ranking:
  - Compute a composite score:
    - Rank(**PAS score** descending) + Rank(**p_val** ascending)
  - Sort by this composite score (ascending).
- Select the **top 3 unique ligand–receptor pairs**, each with their **best-scoring Branch_path**.
  - Enforce uniqueness using:
    ```python
    assert len(set(top_3[["ligand", "receptor"]].itertuples(index=False))) == 3
    ```
  - First prefer 3 unique LR pairs, each with the best Branch_path.
  - If <3 unique LR pairs exist, select multiple Branch_path values from the same LR pair, as long as:
    - Each (ligand, receptor, Branch_path) is unique
    - Each is among the top-ranked composite scores
- **You must not generate hypotheses using any ligand–receptor pair unless it appears in this filtered list.**

### Step 2: Select One Valid LR Pair

For each of the **three selected LR pairs**, generate one hypothesis using **only** the corresponding `Branch_path` from the filtered top 3.

- Enforce validation before generating:
  ```python
  assert (ligand, receptor, branch_path) in set(top_3[["ligand", "receptor", "Branch_path"]].itertuples(index=False))
  ```

1. **Must Exist in Data with PAS**
   - The LR–Branch_path must appear in the filtered DataFrame.
   - **Never invent or substitute** a biologically plausible pair that is not in the file.

2. **Biological Relevance**
   - The pair should be plausibly linked to **{disease}** mechanisms (e.g., inflammation, oxidative stress, synaptic loss, glial activation).

3. **Unique Branch Path**
   - The LR pair must map to a **distinct** `Branch_path` not used for another hypothesis.
   - You must only generate hypotheses from three distinct ligand–receptor pairs, each using their best-scoring Branch_path.

4. **Exclude Examples**
   - Do **not** use LR pairs already described in the analogical reasoning examples.

**Report the following for each selection:**
- Ligand and receptor
- Full `Branch_path`
- PAS and p_val
- A brief rationale for selecting this pair

### Step 3: Generate a Mechanistic Hypothesis

For the selected ligand–receptor pair, write a **comprehensive mechanistic hypothesis** covering the following:

1. The **{disease}**-related cellular stressors that induce the ligand in the sender cell type.
2. The biological function of the receptor in the receiver cell type.
3. A **gene-by-gene breakdown** of the full Branch_path.
4. The final gene's effect on the receiver cell type function.
5. The broader implication of this signaling cascade on **{disease}** pathology.
6. Follow similar logic structure shown in the **reference analogical examples**.

Be mechanistic, multi-step, and emphasize **directional causality** from ligand to phenotype. Do not summarize; fully elaborate all six elements for each hypothesis.

## Repeat Until You Have Three Hypotheses

Repeat **Steps 2–3** until you have generated:

- Each with a **unique, distinct ligand–receptor pair**
- Each with a **distinct Branch_path**
- All derived strictly from the data
- All biologically grounded in **{disease}** mechanisms

Ensure the output is continuous and structured step-by-step, **without skipping validation or reusing branches**.

## Forbidden Actions

- Do **not** hallucinate or invent ligand–receptor pairs
- Do **not** use any pair lacking a PAS in the file
- Do **not** reuse any `Branch_path`
- Do **not** reference external knowledge as justification for including missing data
- Do **not** include:
  - `display_dataframe_to_user`, `print()`, `open()`, or any display/output command
  - Any pauses, intermediate summaries, or confirmations
  - Any message not part of the **three final hypotheses**

## Auto-continue until all three hypotheses are generated without pausing or awaiting user confirmation.

> The final output must be a **continuous block** of:
> - Step-by-step generation of all 3 hypotheses
> - No breaks, no tool invocations, no outputs aside from hypothesis content
"""

elif args.algorithm == "lianaplus":
    user_content = f"Based on the provided cell-cell crosstalk data file {significant_branches_content} between {cell} communication in {disease}, generate three biologically meaningful hypotheses to investigate by predicting the top 3 ligand-receptor pairs with an associated downstream pathway branch to target based on the data, and your background biological knowledge."

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
if args.algorithm == "s2c2":
    total_chars = file2_size + example1_size + example2_size + example3_size
elif args.algorithm == "lianaplus":
    total_chars = file2_size
elif args.algorithm == "nichenet":
    total_chars = lr_size + lt_size
print(f"Total content size: {total_chars:,} characters")
print(f"Request build time: {time.time() - request_start_time:.2f} seconds")

print("\n=== Sending request to Ollama (Python library) ===")
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

    files_read_successfully = (file2_size > 0 and 
                             example1_size > 0 and example2_size > 0 and example3_size > 0)
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
        
        # Write the response with metadata
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write("=" * 80 + "\n")
            f.write("OLLAMA LLM HYPOTHESIS GENERATION REPORT\n")
            f.write("=" * 80 + "\n\n")
            f.write(f"Generated at: {end_datetime.strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write(f"Cell communication type: {cell}\n")
            f.write(f"Disease context: {disease}\n")
            f.write(f"Model: {model_name}\n")
            f.write(f"Temperature: {temperature}\n")
            f.write(f"Max tokens: {max_tokens}\n")
            f.write(f"Context size: {context_size:,} tokens\n")
            f.write(f"Seed: {seed}\n")
            f.write(f"Algorithm: {args.algorithm}\n")
            f.write(f"Processing time: {ollama_duration:.2f} seconds\n")
            f.write(f"Response length: {response_length:,} characters\n")
            f.write(f"Estimated tokens: {estimated_response_tokens:,}\n")
            f.write("\n" + "=" * 80 + "\n")
            f.write("INPUT FILES PROCESSED:\n")
            f.write("=" * 80 + "\n")
            if args.algorithm == "s2c2":
                f.write(f"Significant branches file: {file2_path} ({file2_size:,} chars)\n")
                f.write(f"Example files: {example1_path} ({example1_size:,} chars)\n")
                f.write(f"               {example2_path} ({example2_size:,} chars)\n")
                f.write(f"               {example3_path} ({example3_size:,} chars)\n")
            elif args.algorithm == "lianaplus":
                f.write(f"Significant branches file: {file2_path} ({file2_size:,} chars)\n")
            elif args.algorithm == "nichenet":
                f.write(f"LR file: {lr_file} ({lr_size:,} chars)\n")
                f.write(f"LT file: {lt_file} ({lt_size:,} chars)\n")
            f.write(f"Total content processed: {total_chars:,} characters\n")
            f.write("\n" + "=" * 80 + "\n")
            f.write("OLLAMA LLM RESPONSE:\n")
            f.write("=" * 80 + "\n\n")
            f.write(result)
            f.write("\n\n" + "=" * 80 + "\n")
            f.write("END OF REPORT\n")
            f.write("=" * 80 + "\n")
        
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
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write("LLM REQUEST FAILED - OLLAMA ERROR\n")
            f.write("=" * 50 + "\n")
            f.write(f"Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write(f"Error type: {type(e).__name__}\n")
            f.write(f"Error: {e}\n")
            f.write(f"Model: {model_name}\n")
            f.write(f"Algorithm: {args.algorithm}\n")
            f.write(f"Context size: {context_size:,} tokens\n")
            f.write(f"Max tokens: {max_tokens}\n")
    except:
        pass

print(f"\n=== Analysis Summary ===")
print(f"Start time: {start_datetime.strftime('%Y-%m-%d %H:%M:%S')}")
print(f"End time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
print(f"Total duration: {time.time() - start_time:.2f} seconds")
print(f"Files processed: ")
if args.algorithm == "s2c2":
    print(f"  - {os.path.basename(file2_path)} ({file2_size:,} chars)")
    print(f"  - {os.path.basename(example1_path)} ({example1_size:,} chars)")
    print(f"  - {os.path.basename(example2_path)} ({example2_size:,} chars)")
    print(f"  - {os.path.basename(example3_path)} ({example3_size:,} chars)")
elif args.algorithm == "lianaplus":
    print(f"  - {os.path.basename(file2_path)} ({file2_size:,} chars)")
elif args.algorithm == "nichenet":
    print(f"  - {os.path.basename(lr_file)} ({lr_size:,} chars)")
    print(f"  - {os.path.basename(lt_file)} ({lt_size:,} chars)")
print(f"  - Total: {total_chars:,} characters")
print(f"Algorithm: {args.algorithm}")
print(f"Output file: {output_file}")
