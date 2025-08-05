#!/bin/bash

# Pipeline script for S2C2 analysis followed by LLM-based hypothesis generation
# Supports Ollama (local), Gemini API (cloud), and OpenRouter API (cloud) for LLM analysis
# Usage: ./pipeline.sh [OPTIONS]

set -e  # Exit on any error

# ============================================================================
# WORKING DIRECTORY SETUP
# ============================================================================

# Get the directory where this script is located
# SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# print_info "Script directory: $SCRIPT_DIR"

# # Change to the script directory to ensure all relative paths work correctly
# cd "$SCRIPT_DIR"
# print_info "Changed working directory to: $(pwd)"

# ============================================================================
# DEFAULT VALUES
# ============================================================================

# Required parameters (no defaults)
RDS_FILE=""
CELLTYPE_COLNAME=""
CONDITION_COLNAME=""
CONDITION1=""
CONDITION2=""
SENDER=""
RECEIVER=""

# Optional parameters with defaults
PERCENT_EXP="0.005"
LOGFC_THRESHOLD="0.20"
INTERMEDIATE_DOWNSTREAM_GENE_NUM="2"
PERMUTATION_NUM="1000"
LAMBDA="0.5"
SPECIES="mouse"
ASSAY="RNA"
DISEASE="AD"
RESULTS_DIR="results"  # Fixed to "results", not user-customizable

# Create timestamp for this run
RUN_TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RUN_OUTPUT_DIR="${RESULTS_DIR}/run_${RUN_TIMESTAMP}"

# LLM Parameters with defaults
CELL_TYPE=""  # User input required
DISEASE_CONTEXT=""
LLM_PROVIDER="ollama"  # "ollama", "gemini", or "openrouter"
LLM_MODEL="llama3.2"
TEMPERATURE="0.4"
MAX_TOKENS="100000"
CONTEXT_SIZE="131072"
SEED="512"
API_KEY=""  # Required for Gemini and OpenRouter API
ALGORITHM='s2c2'  # Fixed to s2c2, not user-customizable

# OpenRouter specific parameters
# SITE_URL=""  # Removed
# SITE_NAME=""  # Removed

# File paths
S2C2_SCRIPT="Rscript/S2C2_CLI.R"  # Fixed path
OLLAMA_SCRIPT="python-llm/local-ollama-api.py"  # Fixed path
GEMINI_SCRIPT="python-llm/gemini-api-call.py"  # Fixed path
OPENROUTER_SCRIPT="python-llm/openrouter-api-call.py"  # Fixed path

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

print_header() {
    echo "========================================"
    echo "$1"
    echo "========================================"
}

print_info() {
    echo "[INFO] $1"
}

print_error() {
    echo "[ERROR] $1" >&2
}

print_warning() {
    echo "[WARNING] $1" >&2
}

show_usage() {
    cat << EOF
Pipeline for S2C2 Analysis + LLM Hypothesis Generation
Supports Ollama (local), Gemini API (cloud), and OpenRouter API (cloud) for LLM analysis

USAGE:
    $0 [OPTIONS]

REQUIRED PARAMETERS:
    --rds-file FILE                Seurat RDS file path
    --celltype-colname NAME        Cell type column name in metadata
    --condition-colname NAME       Condition column name in metadata
    --condition1 VALUE             Primary condition value
    --condition2 VALUE             Secondary condition value (use 'NA' for none)
    --sender STRING                Sender cell type
    --receiver STRING              Receiver cell type
    --cell-type STRING             Cell communication type for LLM analysis

LLM CONFIGURATION:
    --llm-provider STRING          LLM provider: "ollama", "gemini", or "openrouter" (default: ollama)
    --model STRING                 Model name (default: llama3.2 for ollama, gemini-2.0-flash for gemini, openai/gpt-4o for openrouter)
    --api-key STRING               API key (required for Gemini and OpenRouter API)
    --disease-context STRING       Disease context for LLM analysis (default: "Alzheimer's disease")


OPTIONAL PARAMETERS:
    --percent-exp FLOAT            Expression percentage threshold (default: 0.005)
    --logfc-threshold FLOAT        Log fold change threshold (default: 0.20)
    --intermediate-downstream-gene-num INT  Intermediate downstream gene number (default: 2)
    --permutation-num INT          Number of permutations (default: 1000)
    --lambda FLOAT                 Lambda parameter (default: 0.0)
    --species STRING               Species: mouse or human (default: mouse)
    --assay STRING                 Assay type: RNA or integrated (default: RNA)
    --disease STRING               Disease context (default: AD)
    --temperature FLOAT            Model temperature for LLM (default: 0.7)
    --max-tokens INT               Maximum tokens for LLM generation (default: 100000)
    --context-size INT             Context window size for LLM (default: 131072)
    --seed INT                     Random seed for LLM (default: 512)


    --help, -h                     Show this help message

EXAMPLES:
    # Basic usage with Ollama (local)
    $0 --rds-file ./example-pbmc3k-data.rds \
       --celltype-colname "seurat_annotations" \
       --condition-colname "condition" \
       --condition1 "control" \
       --condition2 "NA" \
       --sender "Memory CD4 T" \
       --receiver "CD14+ Mono" \
       --species "human" \
       --cell-type "astrocyte-excitatory neuron" \
       --disease-context "Alzheimer's disease" \
       --llm-provider "ollama" \
       --model "llama3.2"

    # Usage with Gemini API (cloud)
    $0 --rds-file ./example-pbmc3k-data.rds \
       --celltype-colname "seurat_annotations" \
       --condition-colname "condition" \
       --condition1 "control" \
       --condition2 "NA" \
       --sender "Memory CD4 T" \
       --receiver "CD14+ Mono" \
       --cell-type "astrocyte-excitatory neuron" \
       --llm-provider "gemini" \
       --model "gemini-2.0-flash" \
       --api-key "your-api-key-here"

    # Usage with OpenRouter API (cloud)
    $0 --rds-file ./example-pbmc3k-data.rds \
       --celltype-colname "seurat_annotations" \
       --condition-colname "condition" \
       --condition1 "control" \
       --condition2 "NA" \
       --sender "astrocyte" \
       --receiver "excitatory neuron" \
       --cell-type "astrocyte-excitatory neuron" \
       --llm-provider "openrouter" \
       --model "openai/gpt-4o" \
       --api-key "your-openrouter-api-key-here"

    # Advanced usage with custom parameters
    $0 --rds-file ./example-pbmc3k-data.rds \
       --celltype-colname "Cell.Types" \
       --condition-colname "condition" \
       --condition1 "tumor" \
       --condition2 "NA" \
       --sender "astrocyte" \
       --receiver "excitatory neuron" \
       --percent-exp 0.01 \
       --logfc-threshold 0.25 \
       --permutation-num 500 \
       --species "mouse" \
       --disease "AD" \
       --disease-context "Alzheimer's disease" \
       --cell-type "astrocyte-excitatory neuron" \
       --llm-provider "openrouter" \
       --model "anthropic/claude-sonnet-4" \
       --api-key "your-openrouter-api-key-here" \
       --temperature 0.3 \
       --max-tokens 100000

Note: All results are automatically saved to the "results" directory in a timestamped subfolder (e.g., results/run_20241201_143052/).

EOF
}

check_file_exists() {
    if [ ! -f "$1" ]; then
        print_error "Required file not found: $1"
        exit 1
    fi
}

sanitize_filename() {
    local input="$1"
    
    # Handle empty or null input
    if [ -z "$input" ] || [ "$input" = "null" ] || [ "$input" = "NA" ]; then
        echo "unknown"
        return
    fi
    
    # Replace all non-alphanumeric characters with underscore
    local result=$(echo "$input" | sed 's/[^A-Za-z0-9]/_/g')
    
    # Replace multiple consecutive underscores with single underscore
    result=$(echo "$result" | sed 's/_\{2,\}/_/g')
    
    # Remove leading and trailing underscores
    result=$(echo "$result" | sed 's/^_*//; s/_*$//')
    
    # Handle empty result
    if [ -z "$result" ]; then
        echo "unknown"
    else
        echo "$result"
    fi
}

validate_numeric() {
    local value="$1"
    local name="$2"
    local min="$3"
    local max="$4"
    
    if ! [[ "$value" =~ ^[0-9]*\.?[0-9]+$ ]]; then
        print_error "$name must be a numeric value, got: $value"
        exit 1
    fi
    
    if [ -n "$min" ] && (( $(echo "$value < $min" | bc -l) )); then
        print_error "$name must be >= $min, got: $value"
        exit 1
    fi
    
    if [ -n "$max" ] && (( $(echo "$value > $max" | bc -l) )); then
        print_error "$name must be <= $max, got: $value"
        exit 1
    fi
}

validate_integer() {
    local value="$1"
    local name="$2"
    local min="$3"
    
    if ! [[ "$value" =~ ^[0-9]+$ ]]; then
        print_error "$name must be an integer, got: $value"
        exit 1
    fi
    
    if [ -n "$min" ] && [ "$value" -lt "$min" ]; then
        print_error "$name must be >= $min, got: $value"
        exit 1
    fi
}

# ============================================================================
# COMMAND LINE ARGUMENT PARSING
# ============================================================================

while [[ $# -gt 0 ]]; do
    case $1 in
        --rds-file)
            RDS_FILE="$2"
            shift 2
            ;;
        --celltype-colname)
            CELLTYPE_COLNAME="$2"
            shift 2
            ;;
        --condition-colname)
            CONDITION_COLNAME="$2"
            shift 2
            ;;
        --condition1)
            CONDITION1="$2"
            shift 2
            ;;
        --condition2)
            CONDITION2="$2"
            shift 2
            ;;
        --sender)
            SENDER="$2"
            shift 2
            ;;
        --receiver)
            RECEIVER="$2"
            shift 2
            ;;
        --percent-exp)
            PERCENT_EXP="$2"
            shift 2
            ;;
        --logfc-threshold)
            LOGFC_THRESHOLD="$2"
            shift 2
            ;;
        --intermediate-downstream-gene-num)
            INTERMEDIATE_DOWNSTREAM_GENE_NUM="$2"
            shift 2
            ;;
        --permutation-num)
            PERMUTATION_NUM="$2"
            shift 2
            ;;
        --lambda)
            LAMBDA="$2"
            shift 2
            ;;
        --species)
            SPECIES="$2"
            shift 2
            ;;
        --assay)
            ASSAY="$2"
            shift 2
            ;;
        --disease)
            DISEASE="$2"
            shift 2
            ;;
        --disease-context)
            DISEASE_CONTEXT="$2"
            shift 2
            ;;
        --cell-type)
            CELL_TYPE="$2"
            shift 2
            ;;
        --llm-provider)
            LLM_PROVIDER="$2"
            shift 2
            ;;
        --model)
            LLM_MODEL="$2"
            shift 2
            ;;
        --api-key)
            API_KEY="$2"
            shift 2
            ;;
        --temperature)
            TEMPERATURE="$2"
            shift 2
            ;;
        --max-tokens)
            MAX_TOKENS="$2"
            shift 2
            ;;
        --context-size)
            CONTEXT_SIZE="$2"
            shift 2
            ;;
        --seed)
            SEED="$2"
            shift 2
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            echo ""
            show_usage
            exit 1
            ;;
    esac
done

# ============================================================================
# VALIDATION SECTION
# ============================================================================

print_header "PIPELINE VALIDATION"

# Check required parameters
if [ -z "$RDS_FILE" ]; then
    print_error "Missing required parameter: --rds-file"
    exit 1
fi

if [ -z "$CELLTYPE_COLNAME" ]; then
    print_error "Missing required parameter: --celltype-colname"
    exit 1
fi

if [ -z "$CONDITION_COLNAME" ]; then
    print_error "Missing required parameter: --condition-colname"
    exit 1
fi

if [ -z "$CONDITION1" ]; then
    print_error "Missing required parameter: --condition1"
    exit 1
fi

if [ -z "$CONDITION2" ]; then
    print_error "Missing required parameter: --condition2"
    exit 1
fi

if [ -z "$SENDER" ]; then
    print_error "Missing required parameter: --sender"
    exit 1
fi

if [ -z "$RECEIVER" ]; then
    print_error "Missing required parameter: --receiver"
    exit 1
fi

if [ -z "$CELL_TYPE" ]; then
    print_error "Missing required parameter: --cell-type"
    exit 1
fi

if [ -z "$DISEASE_CONTEXT" ]; then
    print_error "Missing required parameter: --disease-context"
    exit 1
fi

# Validate LLM provider
if [[ "$LLM_PROVIDER" != "ollama" && "$LLM_PROVIDER" != "gemini" && "$LLM_PROVIDER" != "openrouter" ]]; then
    print_error "LLM provider must be 'ollama', 'gemini', or 'openrouter', got: $LLM_PROVIDER"
    exit 1
fi

# Validate API key for cloud providers
if [[ "$LLM_PROVIDER" == "gemini" && -z "$API_KEY" ]]; then
    print_error "API key is required when using Gemini provider"
    exit 1
fi

if [[ "$LLM_PROVIDER" == "openrouter" && -z "$API_KEY" ]]; then
    print_error "API key is required when using OpenRouter provider"
    exit 1
fi

# Set default model based on provider if not specified
if [[ "$LLM_PROVIDER" == "gemini" && "$LLM_MODEL" == "llama3.2" ]]; then
    LLM_MODEL="gemini-2.0-flash"
    print_info "Using default Gemini model: $LLM_MODEL"
fi

if [[ "$LLM_PROVIDER" == "openrouter" && "$LLM_MODEL" == "llama3.2" ]]; then
    LLM_MODEL="openai/gpt-4o"
    print_info "Using default OpenRouter model: $LLM_MODEL"
fi

# Validate numeric parameters
validate_numeric "$PERCENT_EXP" "percent-exp" "0" "1"
validate_numeric "$LOGFC_THRESHOLD" "logfc-threshold" "0" ""
validate_integer "$INTERMEDIATE_DOWNSTREAM_GENE_NUM" "intermediate-downstream-gene-num" "1"
validate_integer "$PERMUTATION_NUM" "permutation-num" "1"
validate_numeric "$LAMBDA" "lambda" "0" "1"

# Validate LLM parameters
validate_numeric "$TEMPERATURE" "temperature" "0" "2"
validate_integer "$MAX_TOKENS" "max-tokens" "1"
validate_integer "$CONTEXT_SIZE" "context-size" "1024"
validate_integer "$SEED" "seed" "0"

# Validate species parameter
if [[ "$SPECIES" != "mouse" && "$SPECIES" != "human" ]]; then
    print_error "Species must be 'mouse' or 'human', got: $SPECIES"
    exit 1
fi

# Validate assay parameter
if [[ "$ASSAY" != "RNA" && "$ASSAY" != "integrated" ]]; then
    print_error "Assay must be 'RNA' or 'integrated', got: $ASSAY"
    exit 1
fi

# Check if required scripts exist
check_file_exists "$S2C2_SCRIPT"

# Check LLM-specific scripts
if [[ "$LLM_PROVIDER" == "ollama" ]]; then
    check_file_exists "$OLLAMA_SCRIPT"
elif [[ "$LLM_PROVIDER" == "gemini" ]]; then
    check_file_exists "$GEMINI_SCRIPT"
elif [[ "$LLM_PROVIDER" == "openrouter" ]]; then
    check_file_exists "$OPENROUTER_SCRIPT"
fi

# Check if required input files exist
check_file_exists "$RDS_FILE"

# All required parameters validated above, no need for duplicate checks
SENDER_CELLTYPE="$SENDER"
RECEIVER_CELLTYPE="$RECEIVER"

print_info "Configuration validated successfully!"
print_info "Sender cell type: '$SENDER_CELLTYPE'"
print_info "Receiver cell type: '$RECEIVER_CELLTYPE'"
print_info "LLM Provider: '$LLM_PROVIDER'"
print_info "LLM Model: '$LLM_MODEL'"

# Sanitize filenames (same logic as in S2C2_CLI.R)
CLEAN_SENDER=$(sanitize_filename "$SENDER_CELLTYPE")
CLEAN_RECEIVER=$(sanitize_filename "$RECEIVER_CELLTYPE")
CLEAN_CONDITION2=$(sanitize_filename "$CONDITION2")

print_info "Sanitized sender: '$CLEAN_SENDER'"
print_info "Sanitized receiver: '$CLEAN_RECEIVER'"

# Construct expected output directory path
if [ "$CONDITION2" = "NA" ]; then
    EXPECTED_SUBDIR="sender_${CLEAN_SENDER}_receiver_${CLEAN_RECEIVER}_NA"
else
    EXPECTED_SUBDIR="sender_${CLEAN_SENDER}_receiver_${CLEAN_RECEIVER}_${CLEAN_CONDITION2}"
fi

EXPECTED_OUTPUT_DIR="${RUN_OUTPUT_DIR}/${EXPECTED_SUBDIR}"

print_info "Expected output directory: '$EXPECTED_OUTPUT_DIR'"

print_info "Run output directory: '$RUN_OUTPUT_DIR'"
print_info "Cell communication type for LLM analysis: '$CELL_TYPE'"
print_info "Disease context: '$DISEASE_CONTEXT'"
print_info "LLM parameters - Temperature: $TEMPERATURE, Max tokens: $MAX_TOKENS, Seed: $SEED"

# ============================================================================
# S2C2 ANALYSIS SECTION
# ============================================================================

print_header "RUNNING S2C2 ANALYSIS"

# Create output directory for this run
print_info "Creating output directory: $RUN_OUTPUT_DIR"
mkdir -p "$RUN_OUTPUT_DIR"
print_info "✅ Output directory created successfully"

print_info "Starting S2C2_CLI.R with the following parameters:"
echo "  RDS file: $RDS_FILE"
echo "  Cell type column: $CELLTYPE_COLNAME"
echo "  Condition column: $CONDITION_COLNAME"
echo "  Condition 1: $CONDITION1"
echo "  Condition 2: $CONDITION2"
echo "  Sender: $SENDER"
echo "  Receiver: $RECEIVER"
echo "  Percent expression: $PERCENT_EXP"
echo "  LogFC threshold: $LOGFC_THRESHOLD"
echo "  Intermediate downstream genes: $INTERMEDIATE_DOWNSTREAM_GENE_NUM"
echo "  Permutation number: $PERMUTATION_NUM"
echo "  Lambda: $LAMBDA"
echo "  Species: $SPECIES"
echo "  Assay: $ASSAY"
echo "  Disease: $DISEASE"
echo "  Results directory: $RUN_OUTPUT_DIR"
echo ""

# Remove old log file if exists
# [ -f "$LOG_FILE" ] && rm "$LOG_FILE" # This line is removed as per the edit hint.

# Run S2C2 analysis
print_info "Executing S2C2_CLI.R..."
Rscript "$S2C2_SCRIPT" \
    --rds-file "$RDS_FILE" \
    --celltype-colname "$CELLTYPE_COLNAME" \
    --condition-colname "$CONDITION_COLNAME" \
    --condition1 "$CONDITION1" \
    --condition2 "$CONDITION2" \
    --sender "$SENDER" \
    --receiver "$RECEIVER" \
    --percent-exp "$PERCENT_EXP" \
    --logfc-threshold "$LOGFC_THRESHOLD" \
    --intermediate-downstream-gene-num "$INTERMEDIATE_DOWNSTREAM_GENE_NUM" \
    --permutation-num "$PERMUTATION_NUM" \
    --lambda "$LAMBDA" \
    --species "$SPECIES" \
    --assay "$ASSAY" \
    --disease "$DISEASE" \
    --results-dir "$RUN_OUTPUT_DIR"

# Check if S2C2 completed successfully
if [ $? -eq 0 ]; then
    print_info "S2C2 analysis completed successfully!"
else
    print_error "S2C2 analysis failed!"
    exit 1
fi


# ============================================================================
# FILE VERIFICATION SECTION
# ============================================================================

print_header "VERIFYING S2C2 OUTPUT FILES"

# Check if expected output directory exists
if [ ! -d "$EXPECTED_OUTPUT_DIR" ]; then
    print_error "Expected output directory not found: $EXPECTED_OUTPUT_DIR"
    print_info "Available directories in $RUN_OUTPUT_DIR:"
    if [ -d "$RUN_OUTPUT_DIR" ]; then
        ls -la "$RUN_OUTPUT_DIR/"
    else
        print_error "Results directory does not exist: $RUN_OUTPUT_DIR"
    fi
    exit 1
fi

print_info "✅ Output directory found: $EXPECTED_OUTPUT_DIR"

# Define paths to required files
SIGNIFICANT_BRANCHES_FILE="${EXPECTED_OUTPUT_DIR}/LLM_significant_branches.csv"

# Check if required files exist
print_info "Checking for required analysis files..."

if [ ! -f "$SIGNIFICANT_BRANCHES_FILE" ]; then
    print_error "significant_branches.txt not found at: $SIGNIFICANT_BRANCHES_FILE"
    print_info "Files in output directory:"
    ls -la "$EXPECTED_OUTPUT_DIR/"
    exit 1
fi

print_info "✅ significant_branches.txt found: $SIGNIFICANT_BRANCHES_FILE"

# Display file sizes and preview
SIG_SIZE=$(wc -l < "$SIGNIFICANT_BRANCHES_FILE")

print_info "Preview of LR_pairs.txt (first 5 lines):"

print_info "Preview of significant_branches.txt (first 5 lines):"
head -5 "$SIGNIFICANT_BRANCHES_FILE" | sed 's/^/  /'

# ============================================================================
# LLM ANALYSIS SECTION
# ============================================================================

print_header "RUNNING LLM-BASED HYPOTHESIS GENERATION"

print_info "LLM Provider: $LLM_PROVIDER"
print_info "LLM Model: $LLM_MODEL"
print_info "Preparing to run LLM analysis with:"
echo "  Cell type: $CELL_TYPE"
echo "  Disease context: $DISEASE_CONTEXT"
echo "  Temperature: $TEMPERATURE"
echo "  Max tokens: $MAX_TOKENS"
echo "  Context size: $CONTEXT_SIZE"
echo "  Seed: $SEED"
echo "  LLM_Significant branches file: $SIGNIFICANT_BRANCHES_FILE"
echo ""

# LLM Provider-specific setup and execution
if [[ "$LLM_PROVIDER" == "ollama" ]]; then
    # Ollama-specific setup
    print_info "Setting up Ollama (local LLM)..."
    
    # Check if Ollama is running
    print_info "Checking if Ollama service is available..."
    if ! curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
        print_warning "Ollama service may not be running at localhost:11434"
        print_info "Please ensure Ollama is started before proceeding"
        print_info "You can start it with: ollama serve"
        read -p "Press Enter to continue anyway, or Ctrl+C to exit..."
    fi

    # Run the Python script directly with proper arguments
    print_info "Executing local-ollama-api.py..."
    FULL_COMMAND="python3 \"$OLLAMA_SCRIPT\" --cell \"$CELL_TYPE\" --disease \"$DISEASE_CONTEXT\" --model \"$LLM_MODEL\" --significant-branches-file \"$SIGNIFICANT_BRANCHES_FILE\" --temperature \"$TEMPERATURE\" --max-tokens \"$MAX_TOKENS\" --seed \"$SEED\" --results-dir \"$RUN_OUTPUT_DIR\""
    
    print_info " DEBUG: Full Ollama command:"
    echo "    $FULL_COMMAND"
    echo ""

    python3 "$OLLAMA_SCRIPT" --cell "$CELL_TYPE" --disease "$DISEASE_CONTEXT" --model "$LLM_MODEL" --significant-branches-file "$SIGNIFICANT_BRANCHES_FILE" --temperature "$TEMPERATURE" --seed "$SEED" --results-dir "$RUN_OUTPUT_DIR"

    LLM_EXIT_CODE=$?

elif [[ "$LLM_PROVIDER" == "gemini" ]]; then
    # Gemini-specific setup
    print_info "Setting up Gemini API (cloud LLM)..."
    
    # Check internet connectivity
    print_info "Checking internet connectivity for Gemini API..."
    if ! curl -s --connect-timeout 10 https://generativelanguage.googleapis.com > /dev/null 2>&1; then
        print_warning "Cannot reach Gemini API. Please check your internet connection."
        read -p "Press Enter to continue anyway, or Ctrl+C to exit..."
    fi

    # Run Gemini API script
    print_info "Executing gemini-api-call.py..."
    FULL_COMMAND="python3 \"$GEMINI_SCRIPT\" --cell \"$CELL_TYPE\" --disease \"$DISEASE_CONTEXT\" --model \"$LLM_MODEL\" --significant-branches-file \"$SIGNIFICANT_BRANCHES_FILE\" --api-key \"$API_KEY\" --temperature \"$TEMPERATURE\" --max-tokens \"$MAX_TOKENS\" --seed \"$SEED\" --algorithm \"s2c2\" --results-dir \"$RUN_OUTPUT_DIR\""
    
    print_info " DEBUG: Full Gemini command:"
    echo "    $FULL_COMMAND"
    echo ""

    python3 "$GEMINI_SCRIPT" --cell "$CELL_TYPE" --disease "$DISEASE_CONTEXT" --model "$LLM_MODEL" --significant-branches-file "$SIGNIFICANT_BRANCHES_FILE" --api-key "$API_KEY" --temperature "$TEMPERATURE" --max-tokens "$MAX_TOKENS" --seed "$SEED" --algorithm "s2c2" --results-dir "$RUN_OUTPUT_DIR"

    LLM_EXIT_CODE=$?

elif [[ "$LLM_PROVIDER" == "openrouter" ]]; then
    # OpenRouter-specific setup
    print_info "Setting up OpenRouter API (cloud LLM)..."
    
    # Check internet connectivity
    print_info "Checking internet connectivity for OpenRouter API..."
    if ! curl -s --connect-timeout 10 https://openrouter.ai > /dev/null 2>&1; then
        print_warning "Cannot reach OpenRouter API. Please check your internet connection."
        read -p "Press Enter to continue anyway, or Ctrl+C to exit..."
    fi

    # Build OpenRouter command with optional parameters
    OPENROUTER_BASE_CMD="python3 \"$OPENROUTER_SCRIPT\" --cell \"$CELL_TYPE\" --disease \"$DISEASE_CONTEXT\" --model \"$LLM_MODEL\" --significant-branches-file \"$SIGNIFICANT_BRANCHES_FILE\" --api-key \"$API_KEY\" --temperature \"$TEMPERATURE\" --max-tokens \"$MAX_TOKENS\" --algorithm \"s2c2\" --results-dir \"$RUN_OUTPUT_DIR\""
    
    # Run OpenRouter API script
    print_info "Executing openrouter-api-call.py..."
    print_info " DEBUG: Full OpenRouter command:"
    echo "    $OPENROUTER_BASE_CMD"
    echo ""

    eval $OPENROUTER_BASE_CMD

    LLM_EXIT_CODE=$?
fi

# ============================================================================
# COMPLETION SECTION
# ============================================================================

print_header "PIPELINE COMPLETION SUMMARY"

if [ $LLM_EXIT_CODE -eq 0 ]; then
    print_info "✅ LLM analysis completed successfully!"
    
    echo ""
    echo "📊 Analysis Summary:"
    echo "  - S2C2 analysis: ✅ Completed"
    echo "  - Output directory: $RUN_OUTPUT_DIR"
    echo "  - LR pairs analyzed: (Not applicable, S2C2 output is not directly used for LR pairs here)"
    echo "  - Significant pathways: $SIG_SIZE branches"
    echo "  - LLM hypothesis generation: ✅ Completed"
    echo "  - LLM Provider: $LLM_PROVIDER"
    echo "  - LLM Model: $LLM_MODEL"
    echo "  - Cell communication type: $CELL_TYPE"
    echo "  - Disease context: $DISEASE_CONTEXT"
    
    echo ""
    echo "📁 Key output files:"
    echo "  - Run output directory: $RUN_OUTPUT_DIR/"
    echo "  - S2C2 results: $EXPECTED_OUTPUT_DIR/"
    echo "  - Significant branches: $SIGNIFICANT_BRANCHES_FILE"
    echo "  - LLM report: (HTML file in $RUN_OUTPUT_DIR/)"
    echo "  - Analysis log: (No log file generated by S2C2_CLI.R)"
    
    print_info " Pipeline completed successfully!"
    
else
    print_error "❌ LLM analysis failed with exit code: $LLM_EXIT_CODE"
    echo ""
    echo "📊 Partial Analysis Summary:"
    echo "  - S2C2 analysis: ✅ Completed"
    echo "  - LLM hypothesis generation: ❌ Failed"
    echo "  - LLM Provider: $LLM_PROVIDER"
    echo "  - LLM Model: $LLM_MODEL"
    echo ""
    echo "The S2C2 analysis completed successfully, but the LLM analysis encountered issues."
    
    if [[ "$LLM_PROVIDER" == "ollama" ]]; then
        echo "You can manually run the Ollama analysis later using:"
        echo "  python3 $OLLAMA_SCRIPT --cell \"$CELL_TYPE\" --disease \"$DISEASE_CONTEXT\" --results-dir \"$RUN_OUTPUT_DIR\""
        echo "Make sure to update the file paths in the Python script to:"
        echo "  file2_path = \"$SIGNIFICANT_BRANCHES_FILE\""
    elif [[ "$LLM_PROVIDER" == "gemini" ]]; then
        echo "You can manually run the Gemini analysis later using:"
        echo "  python3 $GEMINI_SCRIPT --cell \"$CELL_TYPE\" --disease \"$DISEASE_CONTEXT\" --api-key \"$API_KEY\" --results-dir \"$RUN_OUTPUT_DIR\""
        echo "Make sure to update the file paths in the Python script to:"
        echo "  file2_path = \"$SIGNIFICANT_BRANCHES_FILE\""
    elif [[ "$LLM_PROVIDER" == "openrouter" ]]; then
        echo "You can manually run the OpenRouter analysis later using:"
        echo "  python3 $OPENROUTER_SCRIPT --cell \"$CELL_TYPE\" --disease \"$DISEASE_CONTEXT\" --api-key \"$API_KEY\" --results-dir \"$RUN_OUTPUT_DIR\""
        echo "Make sure to update the file paths in the Python script to:"
        echo "  file2_path = \"$SIGNIFICANT_BRANCHES_FILE\""
    fi
    
    exit 1
fi

echo ""
print_info "Pipeline execution completed at $(date)"