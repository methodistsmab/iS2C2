## NicheNet With Gemini LLM tutorial

This demonstration uses the Gemini API, which supports the following models: gemini-2.0-flash, gemini-2.5-flash, and gemini-2.5-pro. For more information, please refer to: [Gemini API docs](https://ai.google.dev/gemini-api/docs?authuser=1)

Please put your API key in the `.env` file for security purposes.


### Prepare the API Key


```python
import os
from dotenv import load_dotenv
load_dotenv()
api_key = os.getenv('GEMINI_API_KEY')
os.environ['TEMP_API_KEY'] = api_key
```

### Running LLM Hypothesis Generation with S2C2


```bash
python ./gemini-api-call.py \
--cell "(The cell communication pair for LLM-based hypothesis generation and analysis)" \
--disease "(The disease context for LLM-based hypothesis generation to provide relevant biological context for the analysis.)" \
--model "gemini-2.5-pro" \
--lr-file "(The path of ligand-receptor interaction data file)" \
--lt-file "(The path of ligand-target interaction data file)" \
--algorithm "nichenet" \
--api-key "$TEMP_API_KEY"
```