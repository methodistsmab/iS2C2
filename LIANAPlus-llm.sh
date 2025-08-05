#!/bin/bash

# Pipeline script for LIANA+ analysis followed by LLM-based hypothesis generation
# Supports Ollama (local), Gemini API (cloud), and OpenRouter API (cloud) for LLM analysis
# Usage: ./iLIANAPlus.sh [OPTIONS]

set -e  # Exit on any error

# ============================================================================
# DEFAULT VALUES
# ============================================================================

# Required parameters (no defaults)
LIANA_RESULT_FILE=""
CELL_TYPE=""

# LLM Parameters with defaults
DISEASE_CONTEXT=""
LLM_PROVIDER="ollama"  # "ollama", "gemini", or "openrouter"
LLM_MODEL="llama3.2"
TEMPERATURE="0.4"
MAX_TOKENS="100000"
CONTEXT_SIZE="131072"
SEED="512"
API_KEY=""  # Required for Gemini and OpenRouter API
ALGORITHM='lianaplus'  # Fixed to lianaplus, not user-customizable


# File paths
OLLAMA_SCRIPT="python-llm/local-ollama-api.py"  # Fixed path
GEMINI_SCRIPT="python-llm/gemini-api-call.py"  # Fixed path
OPENROUTER_SCRIPT="python-llm/openrouter-api-call.py"  # Fixed path

# Results directory
RESULTS_DIR="results"  # Fixed to "results", not user-customizable

# Create timestamp for this run
RUN_TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RUN_OUTPUT_DIR="${RESULTS_DIR}/run_${RUN_TIMESTAMP}"

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
Pipeline for LIANA+ Analysis + LLM Hypothesis Generation
Supports Ollama (local), Gemini API (cloud), and OpenRouter API (cloud) for LLM analysis

USAGE:
    $0 [OPTIONS]

REQUIRED PARAMETERS:
    --liana-result FILE             LIANA+ result file path (CSV format)
    --cell-type STRING              Cell communication type for LLM analysis

LLM CONFIGURATION:
    --llm-provider STRING           LLM provider: "ollama", "gemini", or "openrouter" (default: ollama)
    --model STRING                  Model name (default: llama3.2 for ollama, gemini-2.0-flash for gemini, openai/gpt-4o for openrouter)
    --api-key STRING                API key (required for Gemini and OpenRouter API)
    --disease-context STRING        Disease context for LLM analysis (default: "Alzheimer's disease")


OPTIONAL PARAMETERS:
    --temperature FLOAT             Model temperature for LLM (default: 0.4)
    --max-tokens INT                Maximum tokens for LLM generation (default: 100000)
    --context-size INT              Context window size for LLM (default: 131072)
    --seed INT                      Random seed for LLM (default: 512)

    --help, -h                      Show this help message

EXAMPLES:
    # Basic usage with Ollama (local)
    $0 --liana-result ./liana_result.csv \
       --cell-type "astrocyte-excitatory neuron" \
       --disease-context "Alzheimer's disease" \
       --llm-provider "ollama" \
       --model "llama3.2"

    # Usage with Gemini API (cloud)
    $0 --liana-result ./liana_result.csv \
       --cell-type "astrocyte-excitatory neuron" \
       --llm-provider "gemini" \
       --model "gemini-2.0-flash" \
       --api-key "your-api-key-here"

    # Usage with OpenRouter API (cloud)
    $0 --liana-result ./liana_result.csv \
       --cell-type "astrocyte-excitatory neuron" \
       --llm-provider "openrouter" \
       --model "openai/gpt-4o" \
       --api-key "your-openrouter-api-key-here"

    # Advanced usage with custom parameters
    $0 --liana-result ./liana_result.csv \
       --cell-type "astrocyte-excitatory neuron" \
       --disease-context "Alzheimer's disease" \
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
        --liana-result)
            LIANA_RESULT_FILE="$2"
            shift 2
            ;;
        --cell-type)
            CELL_TYPE="$2"
            shift 2
            ;;
        --disease-context)
            DISEASE_CONTEXT="$2"
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
if [ -z "$LIANA_RESULT_FILE" ]; then
    print_error "Missing required parameter: --liana-result"
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

# Validate LLM parameters
validate_numeric "$TEMPERATURE" "temperature" "0" "2"
validate_integer "$MAX_TOKENS" "max-tokens" "1"
validate_integer "$CONTEXT_SIZE" "context-size" "1024"
validate_integer "$SEED" "seed" "0"

# Check if required scripts exist
# Check LLM-specific scripts
if [[ "$LLM_PROVIDER" == "ollama" ]]; then
    check_file_exists "$OLLAMA_SCRIPT"
elif [[ "$LLM_PROVIDER" == "gemini" ]]; then
    check_file_exists "$GEMINI_SCRIPT"
elif [[ "$LLM_PROVIDER" == "openrouter" ]]; then
    check_file_exists "$OPENROUTER_SCRIPT"
fi

# Check if required input files exist
check_file_exists "$LIANA_RESULT_FILE"

print_info "Configuration validated successfully!"
print_info "LIANA+ result file: '$LIANA_RESULT_FILE'"
print_info "Cell communication type: '$CELL_TYPE'"
print_info "LLM Provider: '$LLM_PROVIDER'"
print_info "LLM Model: '$LLM_MODEL'"
print_info "Algorithm: '$ALGORITHM' (fixed)"

print_info "Run output directory: '$RUN_OUTPUT_DIR'"
print_info "Disease context: '$DISEASE_CONTEXT'"
print_info "LLM parameters - Temperature: $TEMPERATURE, Max tokens: $MAX_TOKENS, Seed: $SEED"

# ============================================================================
# FILE VERIFICATION SECTION
# ============================================================================

print_header "VERIFYING LIANA+ INPUT FILES"

# Check if LIANA+ result file exists and is readable
if [ ! -f "$LIANA_RESULT_FILE" ]; then
    print_error "LIANA+ result file not found: $LIANA_RESULT_FILE"
    exit 1
fi

print_info "✅ LIANA+ result file found: $LIANA_RESULT_FILE"

# Display file size and preview
LIANA_SIZE=$(wc -l < "$LIANA_RESULT_FILE")
print_info "LIANA+ result file has $LIANA_SIZE lines"

print_info "Preview of LIANA+ result file (first 5 lines):"
head -5 "$LIANA_RESULT_FILE" | sed 's/^/  /'

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
echo "  LIANA+ result file: $LIANA_RESULT_FILE"
echo ""

# Create output directory for this run
print_info "Creating output directory: $RUN_OUTPUT_DIR"
mkdir -p "$RUN_OUTPUT_DIR"
print_info "✅ Output directory created successfully"

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
    FULL_COMMAND="python3 \"$OLLAMA_SCRIPT\" --cell \"$CELL_TYPE\" --disease \"$DISEASE_CONTEXT\" --model \"$LLM_MODEL\" --liana-result \"$LIANA_RESULT_FILE\" --temperature \"$TEMPERATURE\" --max-tokens \"$MAX_TOKENS\" --seed \"$SEED\" --algorithm \"lianaplus\" --results-dir \"$RUN_OUTPUT_DIR\""
    
    print_info " DEBUG: Full Ollama command:"
    echo "    $FULL_COMMAND"
    echo ""

    python3 "$OLLAMA_SCRIPT" --cell "$CELL_TYPE" --disease "$DISEASE_CONTEXT" --model "$LLM_MODEL" --liana-result "$LIANA_RESULT_FILE" --temperature "$TEMPERATURE" --max-tokens "$MAX_TOKENS" --seed "$SEED" --algorithm "lianaplus" --results-dir "$RUN_OUTPUT_DIR"

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
    FULL_COMMAND="python3 \"$GEMINI_SCRIPT\" --cell \"$CELL_TYPE\" --disease \"$DISEASE_CONTEXT\" --model \"$LLM_MODEL\" --liana-result \"$LIANA_RESULT_FILE\" --api-key \"$API_KEY\" --temperature \"$TEMPERATURE\" --max-tokens \"$MAX_TOKENS\" --seed \"$SEED\" --algorithm \"lianaplus\" --results-dir \"$RUN_OUTPUT_DIR\""
    
    print_info " DEBUG: Full Gemini command:"
    echo "    $FULL_COMMAND"
    echo ""

    python3 "$GEMINI_SCRIPT" --cell "$CELL_TYPE" --disease "$DISEASE_CONTEXT" --model "$LLM_MODEL" --liana-result "$LIANA_RESULT_FILE" --api-key "$API_KEY" --temperature "$TEMPERATURE" --max-tokens "$MAX_TOKENS" --seed "$SEED" --algorithm "lianaplus" --results-dir "$RUN_OUTPUT_DIR"

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
    OPENROUTER_BASE_CMD="python3 \"$OPENROUTER_SCRIPT\" --cell \"$CELL_TYPE\" --disease \"$DISEASE_CONTEXT\" --model \"$LLM_MODEL\" --liana-result \"$LIANA_RESULT_FILE\" --api-key \"$API_KEY\" --temperature \"$TEMPERATURE\" --max-tokens \"$MAX_TOKENS\" --algorithm \"lianaplus\" --results-dir \"$RUN_OUTPUT_DIR\""
    

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
    echo "  - LIANA+ analysis: ✅ Input file verified"
    echo "  - Output directory: $RUN_OUTPUT_DIR"
    echo "  - LIANA+ result file: $LIANA_SIZE lines"
    echo "  - LLM hypothesis generation: ✅ Completed"
    echo "  - LLM Provider: $LLM_PROVIDER"
    echo "  - LLM Model: $LLM_MODEL"
    echo "  - Cell communication type: $CELL_TYPE"
    echo "  - Disease context: $DISEASE_CONTEXT"
    echo "  - Algorithm: $ALGORITHM"
    
    echo ""
    echo "📁 Key output files:"
    echo "  - Run output directory: $RUN_OUTPUT_DIR/"
    echo "  - LIANA+ input file: $LIANA_RESULT_FILE"
    echo "  - LLM report: (HTML file in $RUN_OUTPUT_DIR/)"
    
    print_info " Pipeline completed successfully!"
    
else
    print_error "❌ LLM analysis failed with exit code: $LLM_EXIT_CODE"
    echo ""
    echo "📊 Partial Analysis Summary:"
    echo "  - LIANA+ analysis: ✅ Input file verified"
    echo "  - LLM hypothesis generation: ❌ Failed"
    echo "  - LLM Provider: $LLM_PROVIDER"
    echo "  - LLM Model: $LLM_MODEL"
    echo "  - Algorithm: $ALGORITHM"
    echo ""
    echo "The LIANA+ input file was verified successfully, but the LLM analysis encountered issues."
    
    if [[ "$LLM_PROVIDER" == "ollama" ]]; then
        echo "You can manually run the Ollama analysis later using:"
        echo "  python3 $OLLAMA_SCRIPT --cell \"$CELL_TYPE\" --disease \"$DISEASE_CONTEXT\" --liana-result \"$LIANA_RESULT_FILE\" --algorithm \"lianaplus\" --results-dir \"$RUN_OUTPUT_DIR\""
    elif [[ "$LLM_PROVIDER" == "gemini" ]]; then
        echo "You can manually run the Gemini analysis later using:"
        echo "  python3 $GEMINI_SCRIPT --cell \"$CELL_TYPE\" --disease \"$DISEASE_CONTEXT\" --liana-result \"$LIANA_RESULT_FILE\" --api-key \"$API_KEY\" --algorithm \"lianaplus\" --results-dir \"$RUN_OUTPUT_DIR\""
    elif [[ "$LLM_PROVIDER" == "openrouter" ]]; then
        echo "You can manually run the OpenRouter analysis later using:"
        echo "  python3 $OPENROUTER_SCRIPT --cell \"$CELL_TYPE\" --disease \"$DISEASE_CONTEXT\" --liana-result \"$LIANA_RESULT_FILE\" --api-key \"$API_KEY\" --algorithm \"lianaplus\" --results-dir \"$RUN_OUTPUT_DIR\""
    fi
    
    exit 1
fi

echo ""
print_info "Pipeline execution completed at $(date)" 